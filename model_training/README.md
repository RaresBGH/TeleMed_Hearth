<!-- Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0) -->
# TeleMed_K: Gemma 4 E2B Medical Fine-Tuning

This directory contains the QLoRA supervised fine-tuning pipeline required to adapt the underlying `google/gemma-4-e2b` parameters securely against Romanian medical contexts (`MedQARo` and `RoMedQA`), formatting structural outputs ensuring 112 emergency routing constraints map appropriately inside local Android targets.

## CC-BY 4.0 License Notice 
All implementation bounds within this local directory adhere to the Creative Commons Attribution 4.0 International License (CC-BY 4.0).

## Colab Execution Instructions 

Because the LiteRT-LM framework requires specifically formatted 4-bit weights natively mapping towards mobile NPU/TPUs without excessive VRAM constraints, we implement **Unsloth** for significantly faster, memory-efficient LoRA adapters natively. 

1. Create a Google Colab notebook binding an active **T4 GPU** node or higher.
2. Boot execution dependencies seamlessly formatting environment bounds:
```bash
!pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
!pip install --no-deps "xformers<0.0.27" "trl<0.9.0" peft accelerate bitsandbytes
```
3. Authenticate against Hugging Face prior to triggering execution mapping limits explicitly retrieving Romanian Medical Datasets:
```bash
!huggingface-cli login
```
4. Transfer and execute the target extraction bindings explicitly securely:
```bash
!python gemma4_medical_qlora.py
```
5. Extract the compiled parameters merging adapters specifically bridging towards standard `.gguf` bindings exclusively compatible mapping against Google's LiteRT-LM application frameworks offline.
