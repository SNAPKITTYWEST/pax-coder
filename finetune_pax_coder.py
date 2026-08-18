#!/usr/bin/env python3
"""
PAX-Coder Fine-Tuning — DeepSeek-Coder-7B + Unsloth + LoRA
Trains on PAX verified kernel dataset (Lean 4 + PTX + Futhark + Spec)

Hardware target: RTX 3080 10GB (4-bit quantized, gradient checkpointing)
Alternative: A100 40GB (bf16, batch_size=4)

Run after: python3 export_training_data.py
"""

import torch
from pathlib import Path

ROOT = Path(__file__).parent
TRAIN_FILE = ROOT / "build" / "pax_train.jsonl"
VAL_FILE   = ROOT / "build" / "pax_val.jsonl"

def format_prompt(example):
    return (
        "### Instruction:\n"
        f"{example['instruction']}\n\n"
        "### Context:\n"
        f"{example['input']}\n\n"
        "### Response:\n"
        f"{example['output']}"
    )

def main():
    from unsloth import FastLanguageModel
    from datasets import load_dataset
    from trl import SFTTrainer
    from transformers import TrainingArguments

    # RTX 3080: 4-bit quant keeps it under 10GB
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name="deepseek-ai/deepseek-coder-7b-instruct-v1.5",
        max_seq_length=4096,
        dtype=torch.bfloat16,
        load_in_4bit=True,
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=64,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                        "gate_proj", "up_proj", "down_proj"],
        lora_alpha=16,
        lora_dropout=0,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=42,
    )

    dataset = load_dataset("json", data_files={
        "train": str(TRAIN_FILE),
        "validation": str(VAL_FILE),
    })
    dataset = dataset.map(lambda x: {"text": format_prompt(x)})

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset["train"],
        eval_dataset=dataset["validation"],
        dataset_text_field="text",
        max_seq_length=4096,
        args=TrainingArguments(
            output_dir=str(ROOT / "pax-coder-7b"),
            per_device_train_batch_size=1,       # RTX 3080 safe
            gradient_accumulation_steps=8,
            num_train_epochs=3,
            learning_rate=2e-4,
            bf16=True,
            fp16=False,
            logging_steps=10,
            eval_steps=50,
            save_steps=100,
            evaluation_strategy="steps",
            save_strategy="steps",
            load_best_model_at_end=True,
            metric_for_best_model="eval_loss",
            report_to="none",
            run_name="pax-coder-7b-sm86",
            warmup_ratio=0.05,
            lr_scheduler_type="cosine",
        ),
    )

    print("=== Starting PAX-Coder Fine-Tuning ===")
    trainer.train()

    # Save LoRA adapters
    lora_path = ROOT / "pax-coder-7b-lora"
    model.save_pretrained(str(lora_path))
    tokenizer.save_pretrained(str(lora_path))
    print(f"LoRA adapters saved → {lora_path}")

    # Export to GGUF q4_k_m for Ollama on RTX 3080
    gguf_path = ROOT / "pax-coder-7b-gguf"
    FastLanguageModel.for_inference(model)
    model.save_pretrained_gguf(str(gguf_path), tokenizer, quantization_method="q4_k_m")
    print(f"GGUF (q4_k_m) saved → {gguf_path}")
    print("Next: ollama create pax-coder -f Modelfile")

if __name__ == "__main__":
    if not TRAIN_FILE.exists():
        print("Run export_training_data.py first.")
    else:
        main()
