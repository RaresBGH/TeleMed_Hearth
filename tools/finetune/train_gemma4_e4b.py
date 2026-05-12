"""
Step 11 — Unsloth QLoRA fine-tune of Gemma 4 E4B on TeleMed_K synthetic triage data.
Runs inside unsloth/unsloth:dgxspark-latest Docker container with bind mounts:
  /workspace/data/   ← /home/corb_d/sovereign-factory/datasets/training/
  /workspace/output/ ← /home/corb_d/sovereign-factory/models/telemed-k-gemma4-e4b-adapter/
"""

import os

os.environ.setdefault("TORCH_CUDA_ARCH_LIST", "12.1")      # Blackwell SM 12.1
os.environ.setdefault("HF_HUB_DISABLE_XET", "1")           # ARM64 xet transfer fails
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")    # suppress fork warnings

import json
import sys
import traceback
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

TRAIN_PATH  = Path("/workspace/data/train.jsonl")
EVAL_PATH   = Path("/workspace/data/eval.jsonl")
OUTPUT_DIR  = Path("/workspace/output")
ADAPTER_DIR = OUTPUT_DIR / "adapter"
CKPT_DIR    = OUTPUT_DIR / "checkpoints"

# ---------------------------------------------------------------------------
# Hyperparameters (from Gemma 4 starter guide — do not modify)
# ---------------------------------------------------------------------------

BASE_MODEL   = "unsloth/gemma-4-E4B-it-unsloth-bnb-4bit"
MAX_SEQ_LENGTH = 2048

LORA_R       = 16
LORA_ALPHA   = 32
LORA_DROPOUT = 0.05
TARGET_MODULES = [
    "q_proj", "k_proj", "v_proj", "o_proj",
    "gate_proj", "up_proj", "down_proj",
]

EPOCHS        = 3
BATCH_SIZE    = 1
GRAD_ACCUM    = 4
LR            = 2e-4
WEIGHT_DECAY  = 0.01
WARMUP_RATIO  = 0.1
MAX_GRAD_NORM = 0.3
LR_SCHEDULER  = "cosine"
OPTIM         = "adamw_8bit"
SEED          = 42


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ADAPTER_DIR.mkdir(parents=True, exist_ok=True)
    CKPT_DIR.mkdir(parents=True, exist_ok=True)

    for path, label in [(TRAIN_PATH, "train"), (EVAL_PATH, "eval")]:
        if not path.exists():
            raise FileNotFoundError(f"{label} file not found: {path}")

    # --- Imports (deferred so env vars are set first) ---
    from unsloth import FastLanguageModel
    from trl import SFTTrainer, SFTConfig
    from datasets import load_dataset

    # --- Model + tokenizer ---
    print(f"\n[1/6] Loading base model: {BASE_MODEL}")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=BASE_MODEL,
        max_seq_length=MAX_SEQ_LENGTH,
        load_in_4bit=True,
        dtype=None,                 # Unsloth auto-selects BF16 on Blackwell
    )

    print("[2/6] Attaching LoRA adapter …")
    model = FastLanguageModel.get_peft_model(
        model,
        r=LORA_R,
        lora_alpha=LORA_ALPHA,
        lora_dropout=LORA_DROPOUT,
        target_modules=TARGET_MODULES,
        bias="none",
        use_gradient_checkpointing="unsloth",   # Unsloth optimised checkpointing
        random_state=SEED,
    )

    # Trainable param count
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total_params     = sum(p.numel() for p in model.parameters())

    # --- Dataset ---
    print("[3/6] Loading and formatting datasets …")
    train_ds = load_dataset("json", data_files=str(TRAIN_PATH), split="train")
    eval_ds  = load_dataset("json", data_files=str(EVAL_PATH),  split="train")

    def formatting_func(example):
        text = tokenizer.apply_chat_template(
            example["messages"],
            tokenize=False,
            add_generation_prompt=False,
        )
        return {"text": text}

    train_ds = train_ds.map(formatting_func, remove_columns=train_ds.column_names)
    eval_ds  = eval_ds.map(formatting_func,  remove_columns=eval_ds.column_names)

    # Max sequence length seen in training set
    enc = tokenizer(train_ds["text"], truncation=False, padding=False)
    max_len_seen = max(len(ids) for ids in enc["input_ids"])

    # --- Pre-training summary ---
    print("\n" + "=" * 60)
    print("PRE-TRAINING SUMMARY")
    print("=" * 60)
    print(f"  Base model        : {BASE_MODEL}")
    print(f"  Train rows        : {len(train_ds)}")
    print(f"  Eval rows         : {len(eval_ds)}")
    print(f"  Max seq length    : {MAX_SEQ_LENGTH}")
    print(f"  Max len in train  : {max_len_seen} tokens")
    print(f"  Trainable params  : {trainable_params:,} ({100*trainable_params/total_params:.2f}%)")
    print(f"  Total params      : {total_params:,}")
    print(f"  LoRA r/alpha      : {LORA_R}/{LORA_ALPHA}")
    print(f"  Epochs            : {EPOCHS}")
    print(f"  Effective batch   : {BATCH_SIZE * GRAD_ACCUM}")
    print(f"  Learning rate     : {LR}")
    print(f"  LR scheduler      : {LR_SCHEDULER}")
    print(f"  Optimiser         : {OPTIM}")
    print("=" * 60 + "\n")

    # --- Trainer ---
    print("[4/6] Setting up SFTTrainer …")
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        args=SFTConfig(
            output_dir=str(CKPT_DIR),
            num_train_epochs=EPOCHS,
            per_device_train_batch_size=BATCH_SIZE,
            per_device_eval_batch_size=BATCH_SIZE,
            gradient_accumulation_steps=GRAD_ACCUM,
            learning_rate=LR,
            weight_decay=WEIGHT_DECAY,
            warmup_ratio=WARMUP_RATIO,
            max_grad_norm=MAX_GRAD_NORM,
            lr_scheduler_type=LR_SCHEDULER,
            optim=OPTIM,
            bf16=True,
            fp16=False,
            logging_steps=1,
            save_strategy="epoch",
            eval_strategy="epoch",
            seed=SEED,
            report_to="none",
            dataset_text_field="text",
            max_seq_length=MAX_SEQ_LENGTH,
            packing=False,
        ),
    )

    # --- Train ---
    print("[5/6] Starting training …")
    train_result = trainer.train()

    # --- Save adapter ---
    print("[6/6] Saving adapter + tokenizer …")
    model.save_pretrained(str(ADAPTER_DIR))
    tokenizer.save_pretrained(str(ADAPTER_DIR))

    # --- Final eval ---
    final_metrics = trainer.evaluate()

    # --- Write metrics.json ---
    metrics_output = {
        "base_model": BASE_MODEL,
        "epochs": EPOCHS,
        "train_runtime_seconds": train_result.metrics["train_runtime"],
        "train_loss": train_result.metrics["train_loss"],
        "final_eval_loss": final_metrics["eval_loss"],
        "trainable_params": trainable_params,
        "total_params": total_params,
        "max_train_seq_len_tokens": max_len_seen,
        "completed_at": datetime.utcnow().isoformat() + "Z",
        "hyperparameters": {
            "lora_r": LORA_R,
            "lora_alpha": LORA_ALPHA,
            "lora_dropout": LORA_DROPOUT,
            "target_modules": TARGET_MODULES,
            "batch_size": BATCH_SIZE,
            "grad_accum": GRAD_ACCUM,
            "learning_rate": LR,
            "lr_scheduler": LR_SCHEDULER,
            "optim": OPTIM,
            "weight_decay": WEIGHT_DECAY,
            "warmup_ratio": WARMUP_RATIO,
            "max_grad_norm": MAX_GRAD_NORM,
            "seed": SEED,
        },
    }
    with open(OUTPUT_DIR / "metrics.json", "w") as f:
        json.dump(metrics_output, f, indent=2)

    # --- Final stdout summary ---
    runtime_min = train_result.metrics["train_runtime"] / 60
    print("\n" + "=" * 60)
    print("TRAINING COMPLETE")
    print("=" * 60)
    print(f"  Train loss        : {train_result.metrics['train_loss']:.4f}")
    print(f"  Final eval loss   : {final_metrics['eval_loss']:.4f}")
    print(f"  Total runtime     : {runtime_min:.1f} min")
    print(f"  Adapter saved to  : {ADAPTER_DIR}")
    print(f"  Metrics saved to  : {OUTPUT_DIR / 'metrics.json'}")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
        sys.exit(0)
    except Exception as exc:
        traceback.print_exc()
        failure = {
            "error_type": type(exc).__name__,
            "error_message": str(exc),
            "failed_at": datetime.utcnow().isoformat() + "Z",
        }
        Path("/workspace/output").mkdir(parents=True, exist_ok=True)
        with open("/workspace/output/failure.json", "w") as f:
            json.dump(failure, f, indent=2)
        sys.exit(1)
