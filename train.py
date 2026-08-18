#!/usr/bin/env python3
# PAX-Coder Fine-tuning for RTX 3080 (10GB VRAM)
# Ahmad Ali Parr · PAX Architecture
# Optimized: 4-bit QLoRA + Unsloth + paged_adamw_8bit

import os
import torch
from datasets import load_dataset
from unsloth import FastLanguageModel
from trl import SFTTrainer
from transformers import TrainingArguments, EarlyStoppingCallback

CONFIG = {
    "model_name": "unsloth/deepseek-coder-7b-instruct-v1.5-bnb-4bit",
    "max_seq_length": 2048,   # 4096 OOMs on 10GB; 2048 fits with ~1.9GB headroom
    "dtype": torch.bfloat16,
    "load_in_4bit": True,

    # LoRA
    "lora_r": 32,             # rank 32 (not 64) saves ~200MB VRAM
    "lora_alpha": 32,
    "lora_dropout": 0.05,
    "target_modules": [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],

    # Training
    "batch_size": 1,
    "grad_accum": 16,         # effective batch = 16
    "learning_rate": 1.5e-4,
    "num_epochs": 3,
    "warmup_steps": 50,
    "weight_decay": 0.01,
    "max_grad_norm": 1.0,

    # Memory
    "optim": "paged_adamw_8bit",
    "dataloader_num_workers": 2,

    # Logging
    "logging_steps": 10,
    "eval_steps": 50,
    "save_steps": 100,

    # Output
    "output_dir": "pax-coder-7b",
    "run_name": "pax-coder-7b-sm86",
    "report_to": "none",      # set "wandb" if logged in
}

# VRAM budget (RTX 3080 10GB):
#   Base model (4-bit)  ~4.2 GB
#   LoRA adapters       ~0.1 GB
#   Gradients (8-bit)   ~1.5 GB
#   Activations (GC)    ~1.8 GB
#   Dataset buffer      ~0.5 GB
#   Total               ~8.1 GB  (1.9 GB headroom)


def format_pax_example(example):
    return (
        "### Instruction:\n"
        f"{example['instruction']}\n\n"
        "### Context:\n"
        f"{example['input']}\n\n"
        "### Response:\n"
        f"{example['output']}"
    )


def load_pax_dataset():
    dataset = load_dataset("json", data_files={
        "train":      "build/pax_train.jsonl",
        "validation": "build/pax_val.jsonl",
    })

    def format_fn(examples):
        texts = []
        for i in range(len(examples["instruction"])):
            ex = {k: examples[k][i] for k in examples}
            texts.append(format_pax_example(ex))
        return {"text": texts}

    return dataset.map(format_fn, batched=True, remove_columns=dataset["train"].column_names)


def merge_and_export_gguf(output_dir):
    gguf_dir = f"{output_dir}/gguf"
    os.makedirs(gguf_dir, exist_ok=True)

    merged_dir = f"{output_dir}/merged"
    # llama.cpp GGUF conversion (more reliable than Unsloth's built-in for q4_k_m)
    import subprocess
    import shlex

    llama_cpp_dir = "/tmp/llama_cpp_pax"

    # Clone llama.cpp if not present
    if not os.path.isdir(llama_cpp_dir):
        subprocess.run(
            ["git", "clone", "--depth", "1",
             "https://github.com/ggerganov/llama.cpp", llama_cpp_dir],
            check=True,
        )

    # Build
    subprocess.run(
        ["make", f"-j{os.cpu_count() or 4}"],
        cwd=llama_cpp_dir,
        check=True,
    )

    # Convert
    outfile = f"{gguf_dir}/pax-coder-7b-q4_k_m.gguf"
    subprocess.run(
        ["python3", "convert_hf_to_gguf.py", merged_dir,
         "--outfile", outfile, "--outtype", "q4_k_m"],
        cwd=llama_cpp_dir,
        check=True,
    )

    print(f"GGUF saved → {outfile}")
    print(f"Install: ollama create pax-coder -f {gguf_dir}/Modelfile")


def main():
    print(f"=== PAX-Coder RTX 3080 Fine-Tuning ===")
    print(f"GPU:  {torch.cuda.get_device_name(0)}")
    print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=CONFIG["model_name"],
        max_seq_length=CONFIG["max_seq_length"],
        dtype=CONFIG["dtype"],
        load_in_4bit=CONFIG["load_in_4bit"],
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=CONFIG["lora_r"],
        target_modules=CONFIG["target_modules"],
        lora_alpha=CONFIG["lora_alpha"],
        lora_dropout=CONFIG["lora_dropout"],
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=42,
        use_rslora=True,
    )

    dataset = load_pax_dataset()
    print(f"Train: {len(dataset['train'])}  Val: {len(dataset['validation'])}")

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset["train"],
        eval_dataset=dataset["validation"],
        dataset_text_field="text",
        max_seq_length=CONFIG["max_seq_length"],
        args=TrainingArguments(
            output_dir=CONFIG["output_dir"],
            per_device_train_batch_size=CONFIG["batch_size"],
            per_device_eval_batch_size=CONFIG["batch_size"],
            gradient_accumulation_steps=CONFIG["grad_accum"],
            num_train_epochs=CONFIG["num_epochs"],
            learning_rate=CONFIG["learning_rate"],
            warmup_steps=CONFIG["warmup_steps"],
            weight_decay=CONFIG["weight_decay"],
            max_grad_norm=CONFIG["max_grad_norm"],
            gradient_checkpointing=True,
            optim=CONFIG["optim"],
            dataloader_num_workers=CONFIG["dataloader_num_workers"],
            logging_steps=CONFIG["logging_steps"],
            eval_steps=CONFIG["eval_steps"],
            save_steps=CONFIG["save_steps"],
            eval_strategy="steps",
            save_strategy="steps",
            load_best_model_at_end=True,
            metric_for_best_model="eval_loss",
            greater_is_better=False,
            bf16=True,
            fp16=False,
            tf32=True,
            report_to=CONFIG["report_to"],
            run_name=CONFIG["run_name"],
            seed=42,
        ),
        callbacks=[EarlyStoppingCallback(early_stopping_patience=3)],
    )

    trainer.train()

    lora_path = f"{CONFIG['output_dir']}/lora_adapters"
    model.save_pretrained(lora_path)
    tokenizer.save_pretrained(lora_path)
    print(f"LoRA adapters → {lora_path}")

    # Merge and export
    merged_dir = f"{CONFIG['output_dir']}/merged"
    merged = model.merge_and_unload()
    merged.save_pretrained(merged_dir)
    tokenizer.save_pretrained(merged_dir)
    merge_and_export_gguf(CONFIG["output_dir"])


if __name__ == "__main__":
    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "max_split_size_mb:128,expandable_segments:True"
    os.environ["TOKENIZERS_PARALLELISM"] = "false"
    main()
