#!/bin/bash
# PAX-Coder Training Launcher — RTX 3080 10GB
# Ahmad Ali Parr · PAX Architecture

set -e

echo "=== PAX-Coder RTX 3080 Training ==="
echo "GPU:  $(nvidia-smi --query-gpu=name --format=csv,noheader)"
echo "VRAM: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -1)"

# VRAM check — need ~8GB free
FREE_VRAM=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1)
if [ "$FREE_VRAM" -lt 8000 ]; then
    echo "⚠ Warning: Only ${FREE_VRAM}MB free. Close other GPU apps."
    read -p "Continue? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Install deps
pip install -q -r requirements.txt 2>/dev/null | tail -3

# Extract data if needed
if [ ! -f "build/pax_train.jsonl" ]; then
    echo "Extracting training data..."
    python3 export_training_data.py
fi

echo "Starting training (~4-6h on RTX 3080)..."

export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:128,expandable_segments:True"
export CUDA_LAUNCH_BLOCKING=0
export TOKENIZERS_PARALLELISM=false

python3 train.py

echo ""
echo "=== Done ==="
echo "Install: ollama create pax-coder -f pax-coder-7b/gguf/Modelfile"
echo "Run:     ollama run pax-coder 'Write a verified GEMM kernel for RTX 3080'"
echo "Push:    huggingface-cli upload Snapkitty/pax-coder-7b pax-coder-7b/gguf/ --repo-type model"
