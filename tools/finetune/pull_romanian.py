"""
Stage 1: Pull and filter Romanian instruction datasets from HuggingFace.
Outputs clean JSONL files for downstream merging.
"""

import argparse
import json
import os
import random
import re
import time
import uuid
from pathlib import Path
from typing import Optional

import huggingface_hub
from datasets import load_dataset
from dotenv import load_dotenv
from pydantic import BaseModel, ValidationError
from tqdm import tqdm

from config import DATASETS_DIR, RO_MAGPIE_MT, RO_ULTRACHAT

load_dotenv()

# ---------- Pydantic schema ----------

class Message(BaseModel):
    role: str
    content: str


class Example(BaseModel):
    messages: list[Message]
    source: str
    source_id: str


# ---------- Compiled regex patterns (magpie code/math filter) ----------

_CODE_MATH_PATTERNS = re.compile(
    r"```"
    r"|\\frac|\\cdot|\\sum|\\int|\\\(|\\\)"
    r"|\$[A-Za-z0-9]"
    r"|\\def |\\class "
    r"|\bdef |\bclass |\bfunction\b|\bimport |\bfrom \w+ import"
    r"|<html>|<\?php"
    r"|\bSELECT\b|\bFROM\b|\bWHERE\b"
    r"|^Scrie un cod|^Write code|^Implement|^Implementează"
    r"|@\w+",
    re.IGNORECASE | re.MULTILINE,
)


def _is_code_or_math(first_user_msg: str) -> bool:
    return bool(_CODE_MATH_PATTERNS.search(first_user_msg))


# ---------- Length / turn filters (shared) ----------

MIN_CHARS = 100
MAX_CHARS = 8000
MIN_TURNS = 2
MAX_TURNS = 16


def _passes_length_filter(messages: list[dict]) -> bool:
    total = sum(len(m["content"]) for m in messages)
    return MIN_CHARS <= total <= MAX_CHARS


def _passes_turn_filter(messages: list[dict]) -> bool:
    return MIN_TURNS <= len(messages) <= MAX_TURNS


# ---------- Schema normalisation ----------

def _normalise_ultrachat(row: dict) -> Optional[dict]:
    data = row.get("data")
    if not isinstance(data, list) or len(data) < 2:
        return None
    # Drop incomplete final pair
    if len(data) % 2 != 0:
        data = data[:-1]
    messages = [
        {"role": "user" if i % 2 == 0 else "assistant", "content": str(text)}
        for i, text in enumerate(data)
    ]
    source_id = str(row.get("id", uuid.uuid4()))
    return {"messages": messages, "source": "ro_ultrachat", "source_id": source_id}


def _normalise_magpie(row: dict) -> Optional[dict]:
    conversations = row.get("conversations")
    if not isinstance(conversations, list) or len(conversations) == 0:
        return None
    role_map = {"human": "user", "gpt": "assistant"}
    messages = []
    for turn in conversations:
        if not isinstance(turn, dict):
            return None
        if "from" not in turn or "value" not in turn:
            return None
        if turn["from"] not in role_map:
            continue
        messages.append({"role": role_map[turn["from"]], "content": str(turn["value"])})
    if not messages:
        return None
    source_id = str(row.get("uuid", uuid.uuid4()))
    return {"messages": messages, "source": "ro_magpie_mt", "source_id": source_id}


# ---------- Validation ----------

def _validate(raw: dict) -> Optional[Example]:
    try:
        return Example(**raw)
    except ValidationError:
        return None


# ---------- Pull ultrachat ----------

def _pull_ultrachat(rng: random.Random, force: bool) -> tuple[list[dict], dict]:
    spec = RO_ULTRACHAT
    out_dir = DATASETS_DIR / "romanian" / "processed"
    out_path = out_dir / "ro_ultrachat_filtered.jsonl"

    if out_path.exists() and not force:
        print(f"Skipping ro_ultrachat — output exists. Pass --force to overwrite.")
        return [], {}

    out_dir.mkdir(parents=True, exist_ok=True)

    RAW_CAP = 5000
    stats = {
        "raw_streamed": 0,
        "after_schema": 0,
        "after_length": 0,
        "dropped_length": 0,
        "after_turns": 0,
        "dropped_turns": 0,
        "final": 0,
        "avg_chars": 0.0,
        "avg_turns": 0.0,
        "out_path": str(out_path),
    }

    raw_pool: list[dict] = []
    ds = load_dataset(
        spec.hf_id,
        split="train",
        revision=spec.revision,
        streaming=True,
        trust_remote_code=False,
    )

    for row in tqdm(ds, total=RAW_CAP, desc="ultrachat stream", unit="row"):
        if stats["raw_streamed"] >= RAW_CAP:
            break
        stats["raw_streamed"] += 1
        norm = _normalise_ultrachat(row)
        if norm is None:
            continue
        example = _validate(norm)
        if example is None:
            continue
        stats["after_schema"] += 1

        msgs = [m.model_dump() for m in example.messages]

        if not _passes_length_filter(msgs):
            stats["dropped_length"] += 1
            continue
        stats["after_length"] += 1

        if not _passes_turn_filter(msgs):
            stats["dropped_turns"] += 1
            continue
        stats["after_turns"] += 1

        raw_pool.append(norm)

    rng.shuffle(raw_pool)
    selected = raw_pool[: spec.target_samples]

    if len(selected) < spec.target_samples:
        print(
            f"WARNING: ro_ultrachat — only {len(selected)} rows available after filters "
            f"(target {spec.target_samples}). Writing all available."
        )

    total_chars = sum(sum(len(m["content"]) for m in r["messages"]) for r in selected)
    total_turns = sum(len(r["messages"]) for r in selected)
    n = max(len(selected), 1)
    stats["final"] = len(selected)
    stats["avg_chars"] = total_chars / n
    stats["avg_turns"] = total_turns / n

    with out_path.open("w", encoding="utf-8") as f:
        for row in selected:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    # Preview first row
    first = selected[0] if selected else {}
    print("\n--- ro_ultrachat first row ---")
    print(json.dumps(first, ensure_ascii=False, indent=2))

    return selected, stats


# ---------- Pull magpie ----------

def _pull_magpie(rng: random.Random, force: bool) -> tuple[list[dict], dict]:
    spec = RO_MAGPIE_MT
    out_dir = DATASETS_DIR / "romanian" / "processed"
    out_path = out_dir / "ro_magpie_mt_filtered.jsonl"

    if out_path.exists() and not force:
        print(f"Skipping ro_magpie_mt — output exists. Pass --force to overwrite.")
        return [], {}

    out_dir.mkdir(parents=True, exist_ok=True)

    RAW_CAP = 3000
    stats = {
        "raw_streamed": 0,
        "after_schema": 0,
        "after_length": 0,
        "dropped_length": 0,
        "after_turns": 0,
        "dropped_turns": 0,
        "after_code_filter": 0,
        "dropped_code": 0,
        "final": 0,
        "avg_chars": 0.0,
        "avg_turns": 0.0,
        "out_path": str(out_path),
    }

    # Buckets for difficulty/quality tiering
    preferred: list[dict] = []  # easy/medium + good/excellent
    fallback: list[dict] = []   # hard or poor quality

    ds = load_dataset(
        spec.hf_id,
        split="train",
        revision=spec.revision,
        streaming=True,
        trust_remote_code=False,
    )

    for row in tqdm(ds, total=RAW_CAP, desc="magpie stream", unit="row"):
        if stats["raw_streamed"] >= RAW_CAP:
            break
        stats["raw_streamed"] += 1

        norm = _normalise_magpie(row)
        if norm is None:
            continue
        example = _validate(norm)
        if example is None:
            continue
        stats["after_schema"] += 1

        msgs = [m.model_dump() for m in example.messages]

        if not _passes_length_filter(msgs):
            stats["dropped_length"] += 1
            continue
        stats["after_length"] += 1

        if not _passes_turn_filter(msgs):
            stats["dropped_turns"] += 1
            continue
        stats["after_turns"] += 1

        # Code/math filter on first user message
        first_user = next((m["content"] for m in msgs if m["role"] == "user"), "")
        if _is_code_or_math(first_user):
            stats["dropped_code"] += 1
            continue
        stats["after_code_filter"] += 1

        # Difficulty + quality tiering
        difficulty = str(row.get("difficulty", "")).lower()
        quality = str(row.get("input_quality", "")).lower()
        is_preferred = difficulty in ("easy", "medium") and quality in ("good", "excellent")

        if is_preferred:
            preferred.append(norm)
        else:
            fallback.append(norm)

    rng.shuffle(preferred)
    rng.shuffle(fallback)

    if len(preferred) >= spec.target_samples:
        selected = preferred[: spec.target_samples]
    else:
        needed = spec.target_samples - len(preferred)
        selected = preferred + fallback[:needed]

    if len(selected) < spec.target_samples:
        print(
            f"WARNING: ro_magpie_mt — only {len(selected)} rows available after filters "
            f"(target {spec.target_samples}). Writing all available."
        )

    total_chars = sum(sum(len(m["content"]) for m in r["messages"]) for r in selected)
    total_turns = sum(len(r["messages"]) for r in selected)
    n = max(len(selected), 1)
    stats["final"] = len(selected)
    stats["avg_chars"] = total_chars / n
    stats["avg_turns"] = total_turns / n

    with out_path.open("w", encoding="utf-8") as f:
        for row in selected:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    first = selected[0] if selected else {}
    print("\n--- ro_magpie_mt first row ---")
    print(json.dumps(first, ensure_ascii=False, indent=2))

    return selected, stats


# ---------- Summary table ----------

def _print_summary(ultrachat_stats: dict, magpie_stats: dict) -> None:
    print("\n" + "=" * 60)
    print("PULL_ROMANIAN SUMMARY")
    print("=" * 60)

    for name, s in [("ro_ultrachat", ultrachat_stats), ("ro_magpie_mt", magpie_stats)]:
        if not s:
            print(f"\n{name}: skipped (output existed)")
            continue
        print(f"\n{name}")
        print(f"  Raw rows streamed:         {s['raw_streamed']}")
        print(f"  After schema validation:   {s['after_schema']}")
        print(f"  After length filter:       {s['after_length']}  (dropped {s['dropped_length']})")
        print(f"  After turn filter:         {s['after_turns']}  (dropped {s['dropped_turns']})")
        if "after_code_filter" in s:
            print(f"  After code/math filter:    {s['after_code_filter']}  (dropped {s['dropped_code']})")
        print(f"  Final sampled:             {s['final']}")
        print(f"  Avg content length (chars): {s['avg_chars']:.0f}")
        print(f"  Avg turn count:            {s['avg_turns']:.1f}")
        print(f"  Output:                    {s['out_path']}")

    print("=" * 60)


# ---------- Entry point ----------

def main() -> None:
    parser = argparse.ArgumentParser(description="Pull and filter Romanian SFT datasets.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output files.")
    args = parser.parse_args()

    hf_token = os.getenv("HF_TOKEN")
    if not hf_token:
        raise SystemExit("ERROR: HF_TOKEN is not set. Copy .env.example to .env and fill in your token.")
    huggingface_hub.login(token=hf_token, add_to_git_credential=False)

    rng = random.Random(42)

    t0 = time.time()
    _, uc_stats = _pull_ultrachat(rng, args.force)
    _, mg_stats = _pull_magpie(rng, args.force)
    elapsed = time.time() - t0

    _print_summary(uc_stats, mg_stats)
    print(f"\nTotal runtime: {elapsed:.1f}s")


if __name__ == "__main__":
    main()
