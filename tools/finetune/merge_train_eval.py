"""
Step 10: Merge synthetic JSONL files → stratified train/eval split for Unsloth.
Synthetic-only (no OpenLLM-Ro) — first training run per design decision.
"""

import json
import random
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

from pydantic import BaseModel, ValidationError

SEED = 42
EVAL_TARGET = 12
TRAIN_TARGET = 109

SOURCE_FILES = [
    Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_dry_run.jsonl"),
    Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_batch_25a.jsonl"),
    Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_batch_25b.jsonl"),
    Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_batch_50c.jsonl"),
    Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_emergency_batch.jsonl"),
]

OUTPUT_DIR  = Path("/home/corb_d/sovereign-factory/datasets/training")
TRAIN_PATH  = OUTPUT_DIR / "train.jsonl"
EVAL_PATH   = OUTPUT_DIR / "eval.jsonl"
MANIFEST    = OUTPUT_DIR / "merge_manifest.json"

# System message prepended to every dialogue before writing (exact text — do not edit)
SYSTEM_MESSAGE = (
    "Ești un asistent medical AI pentru triajul pacienților vârstnici din mediul rural românesc. "
    "Pacientul descrie simptomele; tu pui întrebări clarificatoare scurte și politicoase, una singură pe rând, "
    "până ai suficiente informații pentru medicul de familie. "
    "Niciodată nu sugerezi diagnostice, medicamente sau doze. "
    "Pentru fiecare răspuns, emiteți EXACT un obiect JSON cu aceste câmpuri: "
    "response (textul în română adresat pacientului), "
    "emergency (boolean), "
    "confidence (0.0 sau 0.9), "
    "priority (\"normal\", \"urgent\" sau \"emergency\"), "
    "ready_to_finalize (boolean — true doar la ultimul mesaj), "
    "category (\"duration\", \"intensity\", \"associated_symptoms\", \"context\", \"history\", \"close\" sau \"emergency\"). "
    "Pentru urgențe vitale (durere precordială cu dispnee, semne AVC, hemoragie severă, pierdere de conștiență, anafilaxie), "
    "răspundeți doar cu \"Sunați 112 imediat.\" și setați emergency=true. "
    "Pentru ideație suicidară, răspundeți cu mesajul empatic incluzând Telefonul Antisuicid 0800 801 200."
)

# Required 6-field schema in every assistant turn
_REQUIRED_FIELDS = {"response", "emergency", "confidence", "priority", "ready_to_finalize", "category"}

# Stratified eval plan — (theme, subcategory filter, count)
# subcategory filter is None = any row from that theme
# For emergency: pick from specific subcategories
EVAL_PLAN = [
    ("hypertension",          None,                1),
    ("diabetes",              None,                1),
    ("arthritis",             None,                1),
    ("heart_failure",         None,                1),
    ("copd",                  None,                1),
    ("general",               None,                2),
    (None,                    None,                1),  # dermatology OR gastrointestinal — resolved below
    (None,                    None,                1),  # mental_health OR medication_management — resolved below
    ("emergency",             "medical",           2),  # 2 different non-suicidal emergency subcats
    ("emergency",             "suicidal_ideation", 1),
]


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

class _Msg(BaseModel):
    role: str
    content: str


def _validate_dialogue(d: dict, source_file: str) -> list[str]:
    errors: list[str] = []
    sid = d.get("synthetic_id", "?")
    label = f"[{sid} @ {source_file}]"

    msgs = d.get("messages", [])
    if not msgs or len(msgs) % 2 != 0:
        errors.append(f"{label} messages count {len(msgs)} not positive-even")
        return errors

    for i, msg in enumerate(msgs):
        expected = "user" if i % 2 == 0 else "assistant"
        if msg.get("role") != expected:
            errors.append(f"{label} turn {i}: expected '{expected}', got '{msg.get('role')}'")

    for i, msg in enumerate(msgs):
        if msg.get("role") != "assistant":
            continue
        try:
            payload = json.loads(msg["content"])
        except (json.JSONDecodeError, TypeError) as e:
            errors.append(f"{label} turn {i}: content not valid JSON — {e}")
            continue
        missing = _REQUIRED_FIELDS - set(payload.keys())
        if missing:
            errors.append(f"{label} turn {i}: missing fields {missing}")

    return errors


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def load_all() -> list[dict]:
    dialogues: list[dict] = []
    for path in SOURCE_FILES:
        if not path.exists():
            print(f"ERROR: source file missing: {path}")
            sys.exit(1)
        with path.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    dialogues.append({**json.loads(line), "_source": path.name})
    return dialogues


# ---------------------------------------------------------------------------
# Stratified eval sampling
# ---------------------------------------------------------------------------

def _pick_eval(dialogues: list[dict], rng: random.Random) -> tuple[list[dict], list[dict]]:
    """Return (eval_set, train_set). eval_set sorted by synthetic_id."""

    # Group by theme
    by_theme: dict[str, list[dict]] = defaultdict(list)
    by_subcat: dict[str, list[dict]] = defaultdict(list)
    for d in dialogues:
        by_theme[d.get("theme", "?")].append(d)
        by_subcat[d.get("subcategory", "")].append(d)

    # Shuffle each bucket for fair sampling
    for bucket in by_theme.values():
        rng.shuffle(bucket)
    for bucket in by_subcat.values():
        rng.shuffle(bucket)

    eval_set: list[dict] = []
    used_ids: set[str] = set()

    def _take(candidates: list[dict], n: int) -> list[dict]:
        taken = []
        for d in candidates:
            if d.get("synthetic_id") not in used_ids and len(taken) < n:
                taken.append(d)
                used_ids.add(d.get("synthetic_id", ""))
        return taken

    # hypertension, diabetes, arthritis, heart_failure, copd — 1 each
    for theme in ("hypertension", "diabetes", "arthritis", "heart_failure", "copd"):
        eval_set.extend(_take(by_theme[theme], 1))

    # general — 2
    eval_set.extend(_take(by_theme["general"], 2))

    # dermatology OR gastrointestinal — 1 (pick whichever has more, for balance)
    derm_gi = by_theme["dermatology"] + by_theme["gastrointestinal"]
    rng.shuffle(derm_gi)
    eval_set.extend(_take(derm_gi, 1))

    # mental_health OR medication_management — 1
    mh_mm = by_theme["mental_health"] + by_theme["medication_management"]
    rng.shuffle(mh_mm)
    eval_set.extend(_take(mh_mm, 1))

    # emergency — 2 medical (different subcategories), 1 suicidal
    emrg_medical = [
        d for d in by_theme["emergency"]
        if d.get("subcategory") != "suicidal_ideation"
    ]
    rng.shuffle(emrg_medical)
    # Pick two from different subcategories
    seen_subcats: set[str] = set()
    for d in emrg_medical:
        if len(seen_subcats) >= 2:
            break
        sub = d.get("subcategory", "")
        if sub not in seen_subcats and d.get("synthetic_id") not in used_ids:
            eval_set.append(d)
            used_ids.add(d.get("synthetic_id", ""))
            seen_subcats.add(sub)

    emrg_suicidal = [
        d for d in by_theme["emergency"]
        if d.get("subcategory") == "suicidal_ideation"
    ]
    rng.shuffle(emrg_suicidal)
    eval_set.extend(_take(emrg_suicidal, 1))

    if len(eval_set) != EVAL_TARGET:
        print(f"WARNING: planned {EVAL_TARGET} eval dialogues but selected {len(eval_set)}")

    train_set = [d for d in dialogues if d.get("synthetic_id") not in used_ids]

    # Sort eval by synthetic_id numerically
    eval_set.sort(key=lambda d: int(d.get("synthetic_id", "synth-0").split("-")[1]))

    return eval_set, train_set


# ---------------------------------------------------------------------------
# Serialise
# ---------------------------------------------------------------------------

def _to_training_row(d: dict) -> dict:
    """Strip metadata, prepend system message, return only messages."""
    system_turn = {"role": "system", "content": SYSTEM_MESSAGE}
    return {"messages": [system_turn] + d["messages"]}


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

def _theme_counts(dialogues: list[dict]) -> dict[str, int]:
    c: Counter = Counter()
    for d in dialogues:
        c[d.get("theme", "?")] += 1
    return dict(sorted(c.items()))


def _total_turns(dialogues: list[dict]) -> int:
    """Count turns in raw source dialogues (excludes injected system turn)."""
    return sum(len(d.get("messages", [])) for d in dialogues)


def _validate_system_injection(rows: list[dict], split_label: str, original: list[dict]) -> list[str]:
    """Post-split checks: system message injected correctly, content unchanged."""
    errors: list[str] = []
    for i, (row, orig) in enumerate(zip(rows, original)):
        sid = orig.get("synthetic_id", f"#{i}")
        msgs = row["messages"]

        # First turn must be system
        if not msgs or msgs[0].get("role") != "system":
            errors.append(f"[{split_label}][{sid}] first turn role is not 'system'")
            continue

        # Content must be byte-equal to SYSTEM_MESSAGE
        if msgs[0]["content"] != SYSTEM_MESSAGE:
            errors.append(
                f"[{split_label}][{sid}] system message content mismatch "
                f"(got {len(msgs[0]['content'])} chars, expected {len(SYSTEM_MESSAGE)})"
            )

        # Must have ≥2 user/assistant turns after system
        rest = msgs[1:]
        if len(rest) < 2:
            errors.append(f"[{split_label}][{sid}] fewer than 2 user/assistant turns after system")
            continue

        # First turn after system must be user
        if rest[0].get("role") != "user":
            errors.append(f"[{split_label}][{sid}] turn[1] role is '{rest[0].get('role')}', expected 'user'")

        # Sanity check: first user content matches original first user turn
        orig_first_user = next((m["content"] for m in orig["messages"] if m["role"] == "user"), None)
        row_first_user  = next((m["content"] for m in rest if m["role"] == "user"), None)
        if orig_first_user != row_first_user:
            errors.append(f"[{split_label}][{sid}] first user turn content changed after injection")

    return errors


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    rng = random.Random(SEED)

    # Load
    dialogues = load_all()
    print(f"Loaded {len(dialogues)} dialogues from {len(SOURCE_FILES)} files.")

    # --- Validation ---
    all_errors: list[str] = []
    for d in dialogues:
        errs = _validate_dialogue(d, d.get("_source", "?"))
        all_errors.extend(errs)

    if len(dialogues) != 121:
        all_errors.append(f"Expected 121 total dialogues, got {len(dialogues)}")

    # Check no duplicate synthetic_ids
    ids = [d.get("synthetic_id", "?") for d in dialogues]
    seen: set = set()
    dupes = []
    for sid in ids:
        if sid in seen:
            dupes.append(sid)
        seen.add(sid)
    if dupes:
        all_errors.append(f"Duplicate synthetic_ids: {dupes}")

    if all_errors:
        print(f"VALIDATION FAILED ({len(all_errors)} errors):")
        for e in all_errors[:20]:
            print(f"  {e}")
        if len(all_errors) > 20:
            print(f"  ... and {len(all_errors) - 20} more")
        sys.exit(1)

    print("Validation passed.")

    # --- Split ---
    eval_set, train_set = _pick_eval(dialogues, rng)
    rng.shuffle(train_set)

    if len(train_set) + len(eval_set) != 121:
        print(f"ERROR: train ({len(train_set)}) + eval ({len(eval_set)}) ≠ 121")
        sys.exit(1)

    print(f"Split: train={len(train_set)}, eval={len(eval_set)}")

    # --- Transform (inject system message) ---
    train_rows = [_to_training_row(d) for d in train_set]
    eval_rows  = [_to_training_row(d) for d in eval_set]

    # --- Post-split injection validation ---
    inj_errors: list[str] = []
    inj_errors.extend(_validate_system_injection(train_rows, "train", train_set))
    inj_errors.extend(_validate_system_injection(eval_rows,  "eval",  eval_set))

    if len(train_rows) + len(eval_rows) != 121:
        inj_errors.append(f"train ({len(train_rows)}) + eval ({len(eval_rows)}) ≠ 121 after injection")

    if inj_errors:
        print(f"INJECTION VALIDATION FAILED ({len(inj_errors)} errors):")
        for e in inj_errors:
            print(f"  {e}")
        sys.exit(1)

    print(f"Injection validation passed — system message prepended to all {len(train_rows)+len(eval_rows)} dialogues.")

    # Compute turn counts from transformed rows (includes system turn)
    train_turns_with_system = sum(len(r["messages"]) for r in train_rows)
    eval_turns_with_system  = sum(len(r["messages"]) for r in eval_rows)

    # --- Write ---
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with TRAIN_PATH.open("w", encoding="utf-8") as f:
        for row in train_rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    with EVAL_PATH.open("w", encoding="utf-8") as f:
        for row in eval_rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    manifest = {
        "total_dialogues": len(dialogues),
        "train_count": len(train_set),
        "eval_count": len(eval_set),
        "train_synth_ids": [d.get("synthetic_id") for d in train_set],
        "eval_synth_ids": [d.get("synthetic_id") for d in eval_set],
        "train_theme_counts": _theme_counts(train_set),
        "eval_theme_counts": _theme_counts(eval_set),
        "train_total_turns": train_turns_with_system,
        "eval_total_turns": eval_turns_with_system,
        "system_message_injected": True,
        "system_message_preview": SYSTEM_MESSAGE[:100],
        "system_message_len": len(SYSTEM_MESSAGE),
        "seed": SEED,
        "source_files": [str(p) for p in SOURCE_FILES],
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    with MANIFEST.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    # Token-count estimate for system message overhead
    approx_tokens_per_char = 1 / 4.0  # rough average for Romanian
    sys_msg_approx_tokens = int(len(SYSTEM_MESSAGE) * approx_tokens_per_char)
    total_sys_overhead = sys_msg_approx_tokens * 121

    # --- Stats ---
    print(f"\n{'='*60}")
    print(f"TRAIN ({len(train_set)} dialogues, {train_turns_with_system} turns incl. system)")
    print(f"  themes: {manifest['train_theme_counts']}")
    print(f"\nEVAL ({len(eval_set)} dialogues, {eval_turns_with_system} turns incl. system)")
    print(f"  ids:    {manifest['eval_synth_ids']}")
    print(f"  themes: {manifest['eval_theme_counts']}")
    print(f"\nSystem message: {len(SYSTEM_MESSAGE)} chars (~{sys_msg_approx_tokens} tokens/dialogue)")
    print(f"  Total overhead across 121 dialogues: ~{total_sys_overhead} tokens")
    print(f"\nOutput files:")
    print(f"  {TRAIN_PATH}")
    print(f"  {EVAL_PATH}")
    print(f"  {MANIFEST}")
    print(f"{'='*60}")

    # --- Sample (train — show system + first 2 turns) ---
    print("\n--- Sample train dialogue (with system message) ---")
    sample_train_row = train_rows[0]
    sample_train_meta = train_set[0]
    print(f"[{sample_train_meta.get('synthetic_id')}] theme={sample_train_meta.get('theme')}")
    for msg in sample_train_row["messages"][:3]:
        role = msg["role"]
        if role == "system":
            print(f"  SYSTEM   : {msg['content'][:100]}…")
        elif role == "user":
            print(f"  PATIENT  : {msg['content'][:120]}")
        else:
            try:
                p = json.loads(msg["content"])
                print(f"  ASSISTANT: {p['response'][:120]}")
            except Exception:
                print(f"  ASSISTANT: {msg['content'][:80]}")


if __name__ == "__main__":
    main()
