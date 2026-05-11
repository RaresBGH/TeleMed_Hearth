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
    """Strip metadata, keep only messages."""
    return {"messages": d["messages"]}


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

def _theme_counts(dialogues: list[dict]) -> dict[str, int]:
    c: Counter = Counter()
    for d in dialogues:
        c[d.get("theme", "?")] += 1
    return dict(sorted(c.items()))


def _total_turns(dialogues: list[dict]) -> int:
    return sum(len(d.get("messages", [])) for d in dialogues)


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

    # --- Write ---
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with TRAIN_PATH.open("w", encoding="utf-8") as f:
        for d in train_set:
            f.write(json.dumps(_to_training_row(d), ensure_ascii=False) + "\n")

    with EVAL_PATH.open("w", encoding="utf-8") as f:
        for d in eval_set:
            f.write(json.dumps(_to_training_row(d), ensure_ascii=False) + "\n")

    manifest = {
        "total_dialogues": len(dialogues),
        "train_count": len(train_set),
        "eval_count": len(eval_set),
        "train_synth_ids": [d.get("synthetic_id") for d in train_set],
        "eval_synth_ids": [d.get("synthetic_id") for d in eval_set],
        "train_theme_counts": _theme_counts(train_set),
        "eval_theme_counts": _theme_counts(eval_set),
        "train_total_turns": _total_turns(train_set),
        "eval_total_turns": _total_turns(eval_set),
        "seed": SEED,
        "source_files": [str(p) for p in SOURCE_FILES],
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    with MANIFEST.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    # --- Stats ---
    print(f"\n{'='*60}")
    print(f"TRAIN ({len(train_set)} dialogues, {manifest['train_total_turns']} turns)")
    print(f"  themes: {manifest['train_theme_counts']}")
    print(f"\nEVAL ({len(eval_set)} dialogues, {manifest['eval_total_turns']} turns)")
    print(f"  ids:    {manifest['eval_synth_ids']}")
    print(f"  themes: {manifest['eval_theme_counts']}")
    print(f"\nOutput files:")
    print(f"  {TRAIN_PATH}")
    print(f"  {EVAL_PATH}")
    print(f"  {MANIFEST}")
    print(f"{'='*60}")

    # --- Sample ---
    print("\n--- Sample train dialogue ---")
    sample_train = train_set[0]
    print(f"[{sample_train.get('synthetic_id')}] theme={sample_train.get('theme')}")
    for msg in sample_train["messages"][:4]:
        if msg["role"] == "user":
            print(f"  PATIENT  : {msg['content'][:120]}")
        else:
            try:
                p = json.loads(msg["content"])
                print(f"  ASSISTANT: {p['response'][:120]}")
            except Exception:
                print(f"  ASSISTANT: {msg['content'][:80]}")

    print("\n--- Sample eval dialogue ---")
    sample_eval = eval_set[0]
    print(f"[{sample_eval.get('synthetic_id')}] theme={sample_eval.get('theme')}")
    for msg in sample_eval["messages"][:4]:
        if msg["role"] == "user":
            print(f"  PATIENT  : {msg['content'][:120]}")
        else:
            try:
                p = json.loads(msg["content"])
                print(f"  ASSISTANT: {p['response'][:120]}")
            except Exception:
                print(f"  ASSISTANT: {msg['content'][:80]}")


if __name__ == "__main__":
    main()
