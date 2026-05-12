"""
Push TeleMed_K fine-tuned LoRA adapter + metadata to HuggingFace Hub.

Reads HF_TOKEN from env. Creates the repo if missing, uploads:
  - adapter_model.safetensors
  - adapter_config.json
  - tokenizer files
  - eval_report.md
  - eval_metrics.json
  - README.md (model card)
"""

import os
import json
import sys
from pathlib import Path
from huggingface_hub import HfApi, create_repo

# --- Config ---
HF_USERNAME = "CoRBs"
REPO_NAME = "telemed-k-gemma4-e4b-ro-medical"
REPO_ID = f"{HF_USERNAME}/{REPO_NAME}"
ADAPTER_DIR = Path("/workspace/output/adapter")
EVAL_REPORT = Path("/workspace/output/eval_report.md")
EVAL_METRICS = Path("/workspace/output/eval_metrics.json")

# --- Token from env ---
hf_token = os.environ.get("HF_TOKEN")
if not hf_token or not hf_token.startswith("hf_"):
    print("ERROR: HF_TOKEN env var not set or invalid (must start with 'hf_').")
    sys.exit(1)

print(f"Pushing to: huggingface.co/{REPO_ID}")
print(f"Adapter source: {ADAPTER_DIR}")

api = HfApi(token=hf_token)

# --- Build model card README.md ---
metrics = json.loads(EVAL_METRICS.read_text()) if EVAL_METRICS.exists() else {}
emergency_routing = metrics.get("emergency_routing", {})

model_card = f"""---
language:
- ro
license: apache-2.0
base_model: unsloth/gemma-4-E4B-it-unsloth-bnb-4bit
library_name: peft
tags:
- gemma-4
- gemma-4-e4b
- medical
- triage
- romanian
- lora
- qlora
- unsloth
- on-device
- healthcare
datasets:
- synthetic-ro-rural-elderly-triage
pipeline_tag: text-generation
---

# TeleMed_K — Gemma 4 E4B Romanian Rural Triage Adapter

A LoRA adapter fine-tuned on top of `unsloth/gemma-4-E4B-it-unsloth-bnb-4bit` for
Romanian rural-elderly medical triage. Part of the TeleMed_K project for the
[Gemma 4 Good Hackathon](https://kaggle.com/competitions/gemma-4-good-hackathon),
developed in collaboration with Clinica Medicală Dr. Bogheanu
(Brănești, Dâmbovița County, Romania).

## Intended use

This adapter teaches Gemma 4 E4B to perform structured triage in Romanian for
elderly rural patients before a family-doctor consultation, producing a strict
JSON output that the TeleMed_K Flutter app parses and routes:

```json
{{
  "response": "<Romanian text shown to the patient>",
  "emergency": <bool>,
  "confidence": <float>,
  "priority": "normal" | "urgent" | "emergency",
  "ready_to_finalize": <bool>,
  "category": "duration" | "intensity" | "associated_symptoms" | "context" | "history" | "close" | "emergency"
}}
```

For vital emergencies (chest pain + dyspnea, stroke, severe bleeding, anaphylaxis,
loss of consciousness) the adapter outputs `"Sunați 112 imediat."` with
`emergency: true`. For suicidal ideation it includes the Romanian
Anti-Suicide Hotline (0800 801 200, Alianța Română de Prevenție a Suicidului).

## Training data

121 synthetic Romanian rural-elderly triage dialogues co-developed with practicing
physicians at Clinica Medicală Dr. Bogheanu (Dr. Adriana Bogheanu, consultant
pediatrician; Dr. Mariana Andronescu, family medicine), covering 13 themes:

- chronic disease management (hypertension, type 2 diabetes, COPD, heart failure, arthritis)
- general symptoms (cough, fever, fatigue, dizziness, headache, back pain)
- dermatology, gastrointestinal, mental health, urinary, vision/hearing
- medication management confusion (boundary case — adapter must not name drugs)
- emergencies (chest pain + dyspnea, stroke, anaphylaxis, severe bleeding, loss
  of consciousness, suicidal ideation, thunderclap headache)

Every assistant turn is a stringified JSON object matching the schema above.

## Training config

| Parameter | Value |
|---|---|
| Base model | `unsloth/gemma-4-E4B-it-unsloth-bnb-4bit` |
| Method | QLoRA (4-bit NF4 + BF16 compute) |
| LoRA rank | 16 |
| LoRA alpha | 32 |
| LoRA dropout | 0.05 |
| Target modules | q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj |
| Epochs | 3 |
| Effective batch size | 4 (per_device=1, grad_accum=4) |
| Learning rate | 2e-4 (cosine, warmup 0.1) |
| Optimizer | adamw_8bit |
| Weight decay | 0.01 |
| Max grad norm | 0.3 |
| BF16 | true |
| Seed | 42 |
| Trainable params | 42.4M (0.67% of 6.34B total) |
| Train loss (final) | {metrics.get("train_loss", "n/a")} |
| Hardware | NVIDIA GB10 (Grace Blackwell, 128GB unified memory) |
| Framework | Unsloth 2026.5.2 + transformers 5.5.0 + trl 0.24.0 + peft 0.19.1 |

## Evaluation

12 stratified held-out dialogues, greedy decoding, max_new_tokens=256.
See `eval_report.md` and `eval_metrics.json` in this repo for full details.

| Metric | Result |
|---|---|
| JSON parse rate | {metrics.get("json_parse_rate", "n/a")}/12 |
| Schema compliance (6 fields) | {metrics.get("schema_compliance", "n/a")}/12 |
| Emergency true positives | {emergency_routing.get("true_positives", "n/a")}/3 |
| Emergency false negatives | {emergency_routing.get("false_negatives", "n/a")} |
| Medication blocklist hits | {metrics.get("blocklist_hits", "n/a")} (target: 0) |
| Greeting violations | {metrics.get("greeting_violations", "n/a")} (target: 0) |
| Avg response length | {metrics.get("avg_response_words", "n/a")} words |

## Usage

```python
from unsloth import FastLanguageModel

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="{REPO_ID}",
    max_seq_length=2048,
    load_in_4bit=True,
)
FastLanguageModel.for_inference(model)

# See ai_engine_service.dart in the TeleMed_K Flutter app
# for the production system prompt and runtime integration.
```

## Limitations & responsible use

- **Not a diagnostic tool.** Outputs a structured triage report for a human
  family physician to review. Never deploy as the sole decision-maker.
- **Synthetic training data.** All dialogues were co-developed and reviewed by
  practicing physicians at Clinica Medicală Dr. Bogheanu; broader multi-clinic
  clinical validation is required before scaled deployment.
- **Romanian rural-elderly register only.** Performance on other dialects,
  age groups, or non-medical conversations is undefined.
- **Confidence value drift.** The adapter emits `confidence: 0.9` for nearly
  all outputs; the engine routes on the `emergency` flag, not `confidence`.

## Authors & Clinical Partners

**Author / Project Lead:** Rareș Bogheanu — Senior QA Lead with 20 years of
experience designing and governing quality processes across enterprise
transformations. Past engagements include IBM (SAN/storage infrastructure
validation), O2 Telefónica UK (telecom billing migration), Ubisoft (AAA
multiplayer QA leadership), and government digitalization projects (Trade
Register CRM, national data integration). Currently pursuing the EITCA
Artificial Intelligence Academy and ISTQB Advanced Level Test Manager
certification. Responsible for TeleMed_K's data synthesis pipeline, Gemma 4
fine-tuning, evaluation methodology, and Flutter application architecture.

**Clinical Partner:** Clinica Medicală Dr. Bogheanu — Brănești, Dâmbovița
County, Romania.

- **Dr. Adriana Bogheanu**, consultant pediatrician — co-reviewed synthetic
  dialogues for medical safety and Romanian-language register appropriate for
  elderly rural patients.
- **Dr. Mariana Andronescu**, family medicine physician — validated triage
  logic and patient-question phrasing against actual rural-family-practice
  consultation patterns.

The clinic is also the demo deployment site for the TeleMed_K hackathon submission.

## Citation
@misc{{telemed_k_2026,
title = {{TeleMed_K: Sovereign On-Device Triage for Rural Romanian Family Medicine}},
author = {{Bogheanu, Rareș}},
year = {{2026}},
url = {{https://huggingface.co/{REPO_ID}}}
}}

## License

Apache 2.0 (inherits from base model). Training data: synthetic, co-developed
with the physicians at Clinica Medicală Dr. Bogheanu under the TeleMed_K project.
"""

print("\n[1/4] Creating repo (if it doesn't exist)…")
try:
    create_repo(REPO_ID, token=hf_token, exist_ok=True, repo_type="model")
    print(f"  Repo ready: huggingface.co/{REPO_ID}")
except Exception as e:
    print(f"  ERROR creating repo: {e}")
    sys.exit(1)

print("\n[2/4] Writing model card…")
readme_path = ADAPTER_DIR / "README.md"
readme_path.write_text(model_card)
print(f"  Wrote {readme_path} ({len(model_card)} chars)")

print("\n[3/4] Uploading adapter directory…")
api.upload_folder(
    folder_path=str(ADAPTER_DIR),
    repo_id=REPO_ID,
    repo_type="model",
    commit_message="Sync: correct attribution and add Authors section",
)
print(f"  Uploaded adapter files")

print("\n[4/4] Uploading evaluation artifacts…")
for f in [EVAL_REPORT, EVAL_METRICS]:
    if f.exists():
        api.upload_file(
            path_or_fileobj=str(f),
            path_in_repo=f.name,
            repo_id=REPO_ID,
            repo_type="model",
            commit_message=f"Sync {f.name}",
        )
        print(f"  Uploaded {f.name}")
    else:
        print(f"  SKIP (missing): {f}")

print(f"\n✅ Done. View at: https://huggingface.co/{REPO_ID}")
