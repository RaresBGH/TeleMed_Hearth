"""
Seed examples for synthetic dialogue generation.
First 5 rows from medical_patient_turns_ro.jsonl — used for tone reference only,
not direct copying into generated dialogues.
"""

from pathlib import Path
import json

_SEEDS_PATH = Path("/home/corb_d/sovereign-factory/datasets/medical/processed/medical_patient_turns_ro.jsonl")

INSPIRATION_SEEDS: list[dict] = []
if _SEEDS_PATH.exists():
    with _SEEDS_PATH.open(encoding="utf-8") as _f:
        for _line in _f:
            _line = _line.strip()
            if _line:
                INSPIRATION_SEEDS.append(json.loads(_line))
            if len(INSPIRATION_SEEDS) >= 5:
                break
