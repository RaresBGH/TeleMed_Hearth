# Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
# You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
#
# TeleMed_K: Offline-first telemedicine app for seniors
# Script for fine-tuning Gemma 4 E2B on Romanian medical datasets using QLoRA via Unsloth.

import os

import torch
from datasets import concatenate_datasets, load_dataset
from transformers import TrainingArguments
from trl import SFTTrainer
from unsloth import FastLanguageModel

# Gemma 4 E2B can handle more context, but 2048 is safe for typical QA contexts
max_seq_length = 2048 
dtype = None # Auto-detection (Float16 or Bfloat16 dependent on active NPU/GPU architecture)
load_in_4bit = True # 4-bit quantization mandatory resolving LiteRT-LM extraction targets

# 1. Load Unsloth FastLanguageModel targeting native Gemma architecture bounds
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="google/gemma-4-e2b",
    max_seq_length=max_seq_length,
    dtype=dtype,
    load_in_4bit=load_in_4bit,
    token=os.environ.get("HF_TOKEN")
)

# 2. Configurable Trainable LoRA Adapter Layers mapping
model = FastLanguageModel.get_peft_model(
    model,
    r=16, # Matrix rank
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0, # 0 heavily optimizes native Unsloth bounds
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=3407,
)

# 3. Romanian Medical Datasets Mapping Strategy Structure 
print("Loading Romanian medical resources natively for training bindings...")
# Sourcing local or public HF Hub references directly
medqaro = load_dataset("medical_qaro_dataset", split="train") 
romedqa = load_dataset("romedqa_dataset", split="train")
dataset = concatenate_datasets([medqaro, romedqa])

# 4. Strict Formatting constraints targeting LiteRT-LM prompt mapping
prompt_template = """<bos><start_of_turn>user
{instruction}
<end_of_turn>
<start_of_turn>model
{response}<end_of_turn><eos>"""

def formatting_prompts_func(examples):
    instructions = examples["question"]
    outputs = examples["answer"]
    texts = []
    for instruction, output in zip(instructions, outputs):
        text = prompt_template.format(instruction=instruction, response=output)
        texts.append(text)
    return { "text" : texts, }

formatted_dataset = dataset.map(formatting_prompts_func, batched=True)

# 5. Supervised Fine-Tuning Execution Engine Configuration
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=formatted_dataset,
    dataset_text_field="text",
    max_seq_length=max_seq_length,
    dataset_num_proc=2,
    packing=False, # Keeping false preserving strict QA boundaries naturally
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        max_steps=60, # Extremely restricted targeting testing bounds 
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=1,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        output_dir="outputs",
    ),
)

# 6. Isolated Trigger Sequence 
if __name__ == "__main__":
    print("Initiating Unsloth QLoRA bindings toward Romanian FHIR contexts...")
    trainer_stats = trainer.train()
    
    # 7. Preserving Adapters Locally
    model.save_pretrained("gemma4_ro_medical_adapters")
    tokenizer.save_pretrained("gemma4_ro_medical_adapters")
    print("QLoRA Fine-tuning complete. Save successful.")
