# TeleMed Hearth Fine-Tune Pipeline

Dataset preparation and Unsloth fine-tune pipeline for Gemma 4 E4B (on-device inference via LiteRT-LM).

## Purpose

Adapt Gemma 4 E4B to Romanian medical triage dialogues so that on-device inference in the TeleMed Hearth app produces contextually accurate, Romanian-language patient interactions matching the Dr. Bogheanu clinic use case.

## Setup

```bash
cd tools/finetune
cp .env.example .env          # fill in HF_TOKEN and ANTHROPIC_API_KEY
uv sync                       # install deps into .venv
uv run python -c "from config import ALL_DATASETS; print(len(ALL_DATASETS), 'datasets registered')"
```

## Datasets

| HF ID | Role | Target samples | License | Revision |
|---|---|---|---|---|
| OpenLLM-Ro/ro_sft_ultrachat | train | 500 | CC-BY-NC-4.0 | 9aaa459 |
| OpenLLM-Ro/ro_sft_magpie_mt | train | 200 | CC-BY-NC-4.0 | beae7fe |
| ruslanmv/ai-medical-chatbot | train | 600 | Apache-2.0/MIT | 138c993 |
| openlifescienceai/medmcqa | eval | 200 | Apache-2.0 | 91c6572 |

License snapshots: `/home/corb_d/sovereign-factory/datasets/license_snapshots/`

**CC-BY-NC datasets:** research and hackathon use only. Not for commercial deployment.

## Pipeline Stages

| Stage | Script | Status |
|---|---|---|
| 0 | Scaffold (this directory) | Done |
| 1 | Dataset download + validation | Pending |
| 2 | Romanian filtering + dedup | Pending |
| 3 | English→Romanian translation (Claude API) | Pending |
| 4 | Synthetic triage generation (Claude API) | Pending |
| 5 | Unsloth SFT fine-tune | Pending |
| 6 | LiteRT-LM export + quantisation | Pending |

## Output

Processed datasets and checkpoints write to `OUTPUT_DIR` (default: `./output/`, gitignored).
