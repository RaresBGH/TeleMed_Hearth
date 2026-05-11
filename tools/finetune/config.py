"""
Dataset registry for TeleMed_K fine-tune.
All datasets pinned to specific revisions captured 2026-05-11.
License snapshots: /home/corb_d/sovereign-factory/datasets/license_snapshots/
"""

from dataclasses import dataclass
from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()

# Base path on the GX10 where raw + processed datasets live
DATASETS_DIR = Path(os.getenv("DATASETS_DIR", "/home/corb_d/sovereign-factory/datasets"))
OUTPUT_DIR = Path(os.getenv("OUTPUT_DIR", "./output"))


@dataclass(frozen=True)
class DatasetSpec:
    hf_id: str               # HuggingFace dataset identifier
    revision: str            # Specific commit SHA for reproducibility
    role: str                # "train" or "eval"
    target_samples: int      # How many examples to keep after filtering
    license: str             # License string for documentation
    notes: str               # Free-text notes for the dataset card


# Romanian training datasets
RO_ULTRACHAT = DatasetSpec(
    hf_id="OpenLLM-Ro/ro_sft_ultrachat",
    revision="9aaa459",
    role="train",
    target_samples=500,
    license="CC-BY-NC-4.0",
    notes="Conversational Romanian, multi-turn. Primary linguistic register source.",
)

RO_MAGPIE_MT = DatasetSpec(
    hf_id="OpenLLM-Ro/ro_sft_magpie_mt",
    revision="beae7fe",
    role="train",
    target_samples=200,
    license="CC-BY-NC-4.0",
    notes="High-quality multi-turn Romanian. Filter to non-code/non-math examples.",
)

# Medical training dataset
MEDICAL_CHATBOT = DatasetSpec(
    hf_id="ruslanmv/ai-medical-chatbot",
    revision="138c993",
    role="train",
    target_samples=600,
    license="Apache-2.0 / MIT (per upstream GitHub repo: github.com/ruslanmv/ai-medical-chatbot)",
    notes="English patient-doctor dialogues. To be translated to Romanian in Stage 3.",
)

# Evaluation-only dataset
MEDMCQA = DatasetSpec(
    hf_id="openlifescienceai/medmcqa",
    revision="91c6572",
    role="eval",
    target_samples=200,  # Held-out for post-training knowledge retention check
    license="Apache-2.0",
    notes="Medical MCQ benchmark. NOT used for training. Post-training eval only.",
)

ALL_DATASETS = [RO_ULTRACHAT, RO_MAGPIE_MT, MEDICAL_CHATBOT, MEDMCQA]
TRAIN_DATASETS = [d for d in ALL_DATASETS if d.role == "train"]
EVAL_DATASETS = [d for d in ALL_DATASETS if d.role == "eval"]
