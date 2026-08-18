#!/bin/bash
# Launch PAX-Coder training on Megatron + Snapkitty Nemotron 70B
# Ahmad Ali Parr · Bel Esprit D'Accord Irrevocable Trust

set -e

export CUDA_HOME=/usr/local/cuda-12.3
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Deterministic environment
export CUBLAS_WORKSPACE_CONFIG=:4096:8
export PYTHONHASHSEED=3735928559
export TORCH_DETERMINISTIC=1
export CUDNN_DETERMINISTIC=1

MEGATRON_PATH=/opt/Megatron-LM
export PYTHONPATH=$MEGATRON_PATH:$PYTHONPATH

MODEL_PATH="Snapkitty/snapkitty-nemotron"
DATA_PATH="build/pax_train.jsonl"

NNODES=1
GPUS_PER_NODE=4       # adjust for your RTX count
MASTER_ADDR=localhost
MASTER_PORT=29500
NODE_RANK=0

mkdir -p logs

echo "=== PAX-Coder Megatron Training ==="
echo "Model:  $MODEL_PATH"
echo "Data:   $DATA_PATH"
echo "GPUs:   $GPUS_PER_NODE"
echo "Seed:   0xDEADBEEF (deterministic)"
echo ""

torchrun \
    --nproc_per_node=$GPUS_PER_NODE \
    --nnodes=$NNODES \
    --node_rank=$NODE_RANK \
    --master_addr=$MASTER_ADDR \
    --master_port=$MASTER_PORT \
    $MEGATRON_PATH/pretrain_gpt.py \
    --config-file megatron_pax_config.yaml \
    --load $MODEL_PATH \
    --save pax-coder-snapkitty-nemotron \
    --data-path $DATA_PATH \
    --tokenizer-type NemotronTokenizer \
    --tokenizer-model $MODEL_PATH \
    --deterministic \
    --seed 3735928559 \
    2>&1 | tee logs/pax_coder_megatron_$(date +%Y%m%d_%H%M%S).log

echo ""
echo "=== Training Complete ==="
echo "Adapters saved → pax-coder-snapkitty-nemotron/"
echo "Next: python3 verify_integration.py"
