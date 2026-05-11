"""
Stage 2: Pull and filter English medical patient-doctor dialogues from HuggingFace.
Output is English JSONL for later translation to Romanian (Stage 3).
"""

import argparse
import json
import os
import random
import re
import time
from pathlib import Path
from typing import Optional

import huggingface_hub
from datasets import load_dataset
from dotenv import load_dotenv
from pydantic import BaseModel, ValidationError
from tqdm import tqdm

from config import DATASETS_DIR, MEDICAL_CHATBOT

load_dotenv()

# ---------- Drug blocklist (expand as needed) ----------

PRESCRIPTION_BLOCKLIST: list[str] = [
    "clindamycin", "doxycycline", "isotretinoin", "tretinoin", "metformin",
    "lisinopril", "amoxicillin", "prednisone", "azithromycin", "ibuprofen",
    "acetaminophen", "paracetamol", "aspirin", "omeprazole", "simvastatin",
    "atorvastatin", "levothyroxine", "warfarin", "gabapentin", "tramadol",
]

_DRUG_RE = re.compile(
    r"\b(" + "|".join(re.escape(d) for d in PRESCRIPTION_BLOCKLIST) + r")\b",
    re.IGNORECASE,
)

# ---------- PHI patterns ----------

_PHI_EMAIL = re.compile(r"\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b")
_PHI_PHONE_LONG = re.compile(r"\d{10,}")
_PHI_PHONE_US = re.compile(r"\(\d{3}\)\s*\d{3}-?\d{4}")
_PHI_DOB_DATE = re.compile(r"\b\d{1,2}/\d{1,2}/\d{2,4}\b")
_PHI_DOB_CONTEXT = re.compile(r"(?i)(DOB|born|birthday)")
_PHI_NAME_CAPS = re.compile(r"\b[A-Z][a-z]+\s+[A-Z][a-z]+\b")
_PHI_NAME_CONTEXT = re.compile(r"(?i)(my name is|I am|patient name)")
_PHI_SSN = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")

# ---------- Quality / disclaimer patterns ----------

_ARROW_ARTIFACT = re.compile(r"-->")
_CONSULT_ARTIFACT = re.compile(r"(?i)consult a \w+ online.*-->")
_DISCLAIMER_PHRASES = ["i would suggest", "consult", "however"]

# ---------- Pydantic schema ----------

class Message(BaseModel):
    role: str
    content: str


class Example(BaseModel):
    messages: list[Message]
    source: str
    source_id: str


# ---------- PHI detection (returns which pattern matched) ----------

def _phi_hit(text: str) -> Optional[str]:
    if _PHI_EMAIL.search(text):
        return "email"
    if _PHI_PHONE_LONG.search(text) or _PHI_PHONE_US.search(text):
        return "phone"
    # DOB: date pattern + context word within 30 chars
    for m in _PHI_DOB_DATE.finditer(text):
        start = max(0, m.start() - 30)
        end = min(len(text), m.end() + 30)
        if _PHI_DOB_CONTEXT.search(text[start:end]):
            return "dob"
    # Full name: caps pattern + context word within 50 chars
    for m in _PHI_NAME_CAPS.finditer(text):
        start = max(0, m.start() - 50)
        end = min(len(text), m.end() + 50)
        if _PHI_NAME_CONTEXT.search(text[start:end]):
            return "name"
    if _PHI_SSN.search(text):
        return "ssn"
    return None


# ---------- Core filter logic ----------

def _passes_patient_length(patient: str) -> bool:
    return 80 <= len(patient) <= 1500


def _passes_doctor_length(doctor: str) -> bool:
    return 40 <= len(doctor) <= 1200


def _passes_phi(patient: str, doctor: str) -> Optional[str]:
    combined = patient + " " + doctor
    return _phi_hit(combined)  # returns hit label or None


def _prescription_match(doctor: str) -> Optional[str]:
    m = _DRUG_RE.search(doctor)
    return m.group(1).lower() if m else None


def _passes_quality(doctor: str) -> bool:
    stripped = doctor.rstrip()
    if stripped.endswith("-->"):
        return False
    if _CONSULT_ARTIFACT.search(doctor):
        return False
    return True


def _passes_disclaimer(doctor: str) -> bool:
    lower = doctor.lower()
    hits = sum(1 for phrase in _DISCLAIMER_PHRASES if phrase in lower)
    if hits < 3:
        return True
    disclaimer_chars = sum(len(phrase) for phrase in _DISCLAIMER_PHRASES if phrase in lower)
    ratio = disclaimer_chars / max(len(doctor), 1)
    return ratio <= 0.80


def _normalise(row: dict, index: int) -> Optional[dict]:
    patient = (row.get("Patient") or "").strip()
    doctor = (row.get("Doctor") or "").strip()
    if not patient or not doctor:
        return None
    return {
        "messages": [
            {"role": "user", "content": patient},
            {"role": "assistant", "content": doctor},
        ],
        "source": "medical_chatbot_en",
        "source_id": f"ruslanmv-{index}",
    }


def _validate(raw: dict) -> Optional[Example]:
    try:
        return Example(**raw)
    except ValidationError:
        return None


# ---------- Streaming pull with retry ----------

def _stream_and_filter(raw_cap: int, rng: random.Random) -> tuple[list[dict], dict]:
    stats: dict = {
        "raw_streamed": 0,
        "after_schema": 0,
        "after_patient_len": 0, "dropped_patient_len": 0,
        "after_doctor_len": 0,  "dropped_doctor_len": 0,
        "after_phi": 0,         "dropped_phi": 0,
        "phi_by_pattern": {"email": 0, "phone": 0, "dob": 0, "name": 0, "ssn": 0},
        "after_prescription": 0, "dropped_prescription": 0,
        "drug_hits": {},
        "after_quality": 0,     "dropped_quality": 0,
        "after_disclaimer": 0,  "dropped_disclaimer": 0,
    }

    pool: list[dict] = []
    spec = MEDICAL_CHATBOT

    ds = load_dataset(
        spec.hf_id,
        split="train",
        revision=spec.revision,
        streaming=True,
        trust_remote_code=False,
    )

    row_index = 0
    for row in tqdm(ds, total=raw_cap, desc="medical stream", unit="row"):
        if stats["raw_streamed"] >= raw_cap:
            break
        stats["raw_streamed"] += 1

        norm = _normalise(row, row_index)
        row_index += 1
        if norm is None:
            continue
        if _validate(norm) is None:
            continue
        stats["after_schema"] += 1

        patient = norm["messages"][0]["content"]
        doctor = norm["messages"][1]["content"]

        if not _passes_patient_length(patient):
            stats["dropped_patient_len"] += 1
            continue
        stats["after_patient_len"] += 1

        if not _passes_doctor_length(doctor):
            stats["dropped_doctor_len"] += 1
            continue
        stats["after_doctor_len"] += 1

        phi_label = _passes_phi(patient, doctor)
        if phi_label is not None:
            stats["dropped_phi"] += 1
            stats["phi_by_pattern"][phi_label] += 1
            continue
        stats["after_phi"] += 1

        drug = _prescription_match(doctor)
        if drug is not None:
            stats["dropped_prescription"] += 1
            stats["drug_hits"][drug] = stats["drug_hits"].get(drug, 0) + 1
            continue
        stats["after_prescription"] += 1

        if not _passes_quality(doctor):
            stats["dropped_quality"] += 1
            continue
        stats["after_quality"] += 1

        if not _passes_disclaimer(doctor):
            stats["dropped_disclaimer"] += 1
            continue
        stats["after_disclaimer"] += 1

        pool.append(norm)

    rng.shuffle(pool)
    return pool, stats


# ---------- Main pull ----------

def _pull_medical(rng: random.Random, force: bool) -> tuple[list[dict], dict]:
    spec = MEDICAL_CHATBOT
    out_dir = DATASETS_DIR / "medical" / "processed"
    out_path = out_dir / "medical_chatbot_en.jsonl"

    if out_path.exists() and not force:
        print("Skipping medical_chatbot — output exists. Pass --force to overwrite.")
        return [], {}

    out_dir.mkdir(parents=True, exist_ok=True)

    pool, stats = _stream_and_filter(raw_cap=5000, rng=rng)

    if len(pool) < spec.target_samples:
        print(
            f"NOTE: Only {len(pool)} rows after filtering 5000 raw rows. "
            f"Retrying with cap=10000 …"
        )
        rng2 = random.Random(42)
        pool, stats = _stream_and_filter(raw_cap=10000, rng=rng2)

    selected = pool[: spec.target_samples]

    if len(selected) < spec.target_samples:
        print(
            f"WARNING: medical_chatbot — only {len(selected)} rows available after filters "
            f"(target {spec.target_samples}). Writing all available."
        )

    with out_path.open("w", encoding="utf-8") as f:
        for row in selected:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    stats["final"] = len(selected)
    stats["out_path"] = str(out_path)

    patients = [r["messages"][0]["content"] for r in selected]
    doctors  = [r["messages"][1]["content"] for r in selected]
    n = max(len(selected), 1)
    stats["avg_patient_len"] = sum(len(p) for p in patients) / n
    stats["avg_doctor_len"]  = sum(len(d) for d in doctors)  / n

    first = selected[0] if selected else {}
    print("\n--- medical_chatbot_en first row ---")
    print(json.dumps(first, ensure_ascii=False, indent=2))

    return selected, stats


# ---------- Summary table ----------

def _print_summary(stats: dict) -> None:
    if not stats:
        print("\nmedical_chatbot: skipped (output existed)")
        return

    top_drugs = sorted(stats["drug_hits"].items(), key=lambda x: -x[1])[:5]

    print("\n" + "=" * 60)
    print("PULL_MEDICAL SUMMARY")
    print("=" * 60)
    print(f"  Raw rows streamed:          {stats['raw_streamed']}")
    print(f"  After schema validation:    {stats['after_schema']}")
    print(f"  After patient length (80–1500): {stats['after_patient_len']}  (dropped {stats['dropped_patient_len']})")
    print(f"  After doctor length (40–1200):  {stats['after_doctor_len']}  (dropped {stats['dropped_doctor_len']})")
    print(f"  After PHI filter:           {stats['after_phi']}  (dropped {stats['dropped_phi']})")
    for pat, cnt in stats["phi_by_pattern"].items():
        if cnt:
            print(f"    [{pat}]: {cnt}")
    print(f"  After prescription filter:  {stats['after_prescription']}  (dropped {stats['dropped_prescription']})")
    if top_drugs:
        print(f"    Top drugs matched: {', '.join(f'{d}({c})' for d,c in top_drugs)}")
    print(f"  After quality filter:       {stats['after_quality']}  (dropped {stats['dropped_quality']})")
    print(f"  After disclaimer filter:    {stats['after_disclaimer']}  (dropped {stats['dropped_disclaimer']})")
    print(f"  Final sampled:              {stats['final']}")
    print(f"  Avg patient length (chars): {stats['avg_patient_len']:.0f}")
    print(f"  Avg doctor length (chars):  {stats['avg_doctor_len']:.0f}")
    print(f"  Output:                     {stats['out_path']}")
    print("=" * 60)


# ---------- Entry point ----------

def main() -> None:
    parser = argparse.ArgumentParser(description="Pull and filter English medical chatbot dataset.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output files.")
    args = parser.parse_args()

    hf_token = os.getenv("HF_TOKEN")
    if not hf_token:
        raise SystemExit("ERROR: HF_TOKEN is not set. Copy .env.example to .env and fill in your token.")
    huggingface_hub.login(token=hf_token, add_to_git_credential=False)

    rng = random.Random(42)

    t0 = time.time()
    _, stats = _pull_medical(rng, args.force)
    elapsed = time.time() - t0

    _print_summary(stats)
    print(f"\nTotal runtime: {elapsed:.1f}s")


if __name__ == "__main__":
    main()
