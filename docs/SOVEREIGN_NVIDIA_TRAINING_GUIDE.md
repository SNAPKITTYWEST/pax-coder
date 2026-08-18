# Sovereign NVIDIA Training Guide

**How SnapKitty trains NVIDIA's own model on NVIDIA's own hardware to produce verified NVIDIA kernels.**

---

## Why Nemotron + NVIDIA Megatron

Most AI code generators are trained on GitHub scrapes and hope for the best. We took a different approach:

| Decision | Why |
|----------|-----|
| **NVIDIA Nemotron** as base model | Nemotron was built by NVIDIA. Its internal weights already encode CUDA semantics, PTX instruction behavior, tensor core data paths, and memory hierarchy. We don't teach it NVIDIA — it already *is* NVIDIA. |
| **NVIDIA Megatron** as training framework | Megatron-LM is NVIDIA's own distributed training framework. Tensor parallelism, pipeline parallelism, sequence parallelism — all designed for NVIDIA hardware by NVIDIA engineers. |
| **RTX 3080 / RTX 4090** as target hardware | We generate kernels for the same GPUs we train on. The model writes PTX for the machine it runs on. |
| **PAX formal verification** as training signal | Every training example is a proven-correct kernel. The model learns what correct GPU code looks like because it only ever sees correct GPU code. |

The result: a model that writes NVIDIA GPU kernels with mathematical correctness proofs attached, trained by NVIDIA's framework on NVIDIA's hardware using NVIDIA's model.

**No external dependencies. No cloud APIs. Sovereign compute.**

---

## The Stack (All NVIDIA, All the Way Down)

```
┌────────────────────────────────────────────────────────────────────┐
│                    SNAPKITTY SOVEREIGN COMPUTE                      │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│   Model:      NVIDIA Nemotron 70B                                  │
│   Framework:  NVIDIA Megatron-LM (tensor + pipeline parallelism)   │
│   Hardware:   NVIDIA RTX 3080 (sm_86) / RTX 4090 (sm_89)          │
│   ISA:        NVIDIA PTX (mma.sync, cp.async, ldmatrix, TMA)       │
│   Proofs:     Lean 4 (verified against NVIDIA hardware model)      │
│   Inference:  Deterministic (temperature=0.0, top_k=1)             │
│                                                                    │
│   Every layer is NVIDIA.                                           │
│   Every kernel is proven.                                          │
│   Every output is deterministic.                                   │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Hardware Targets

SnapKitty maintains verified kernel libraries for multiple NVIDIA architectures:

### RTX 3080 — Ampere (sm_86)

```
Architecture:  Ampere
Compute:       sm_86
VRAM:          10 GB GDDR6X (760 GB/s)
Tensor Cores:  3rd gen
Key PTX:       mma.sync.aligned.m16n8k8.row.col.f32.f16.f16.f32
Async Copy:    cp.async.ca.shared.global + commit/wait groups
Pipeline:      3-stage (proven overlap bound: 1 - 1/3 = 66.7% utilization floor)
```

**Verified kernels:**
- `rtx_gemm_wmma.cu` — WMMA reference (128x128x32 CTA tiles)
- `rtx_gemm_ptx.cu` — Raw PTX mma.sync with ldmatrix
- `rtx_gemm_pipeline.cu` — 3-stage async pipeline with proven throughput
- `rtx_gemm_epilogue.cu` — Fused Bias+GeLU / Residual+GeLU epilogues

### RTX 4090 — Ada Lovelace (sm_89)

```
Architecture:  Ada Lovelace
Compute:       sm_89
VRAM:          24 GB GDDR6X (1008 GB/s)
Tensor Cores:  4th gen
Key PTX:       cp.async.bulk.tensor (TMA — Tensor Memory Accelerator)
Cluster:       __cluster_dims__ + barrier.cluster.* + multicast TMA
Pipeline:      4+ stage (TMA enables deeper overlap)
```

**Verified kernels:**
- `rtx_gemm_tma.cu` — TMA cluster algebra with multicast
- Cluster coherence invariant: `forall c in cluster. TMA_load(c) -> visible(c') within 1 cycle`
- Multicast law: `TMA_multicast(mask, T) = XOR_{c in mask} TMA_unicast(c, T)`

### What This Means for You

You tell PAX-Coder which GPU you have. It generates a kernel targeting exactly that architecture — not a generic CUDA kernel that might work, but a PTX-level implementation proven correct for your specific hardware.

```bash
# RTX 3080 (sm_86) — cp.async pipeline, no TMA
ollama run pax-coder "Write a verified GEMM for sm_86 with 3-stage pipeline"

# RTX 4090 (sm_89) — TMA cluster, deep pipeline
ollama run pax-coder "Write a verified GEMM for sm_89 with TMA multicast"
```

---

## Training Nemotron with Megatron-LM

### Why This Combination Works

Nemotron 70B already understands:
- CUDA memory hierarchy (global → L2 → shared → registers)
- PTX instruction semantics (what `mma.sync` actually computes)
- Tensor core data layouts (row-major A, column-major B, m16n8k8 fragments)
- Warp-level primitives (`shfl.sync`, `vote.sync`, `match.sync`)

We're not teaching a generic language model what CUDA is. We're taking NVIDIA's own model — which already has CUDA baked into its weights — and fine-tuning it to produce **formally verified** NVIDIA code.

The fine-tuning signal is the PAX corpus: ~2,400 verified triples of `(Lean 4 proof, PTX kernel, Futhark spec)`. After training, the model doesn't just write CUDA — it writes proven-correct CUDA.

### Training Configuration

```yaml
# Megatron-LM config for Nemotron PAX fine-tuning
model:
  name: nvidia/nemotron-70b-instruct
  tensor_parallel_size: 4
  pipeline_parallel_size: 2
  sequence_length: 4096
  
training:
  micro_batch_size: 1
  global_batch_size: 64
  learning_rate: 1.5e-5
  min_learning_rate: 1.0e-6
  lr_warmup_steps: 100
  lr_decay_style: cosine
  weight_decay: 0.01
  clip_grad: 1.0
  bf16: true
  
data:
  dataset: pax-verified-corpus
  format: nemotron_chat_template
  categories:
    - fp16_rounding      # IEEE-754 binary16 proofs
    - gemm_kernels       # mma.sync implementations
    - pipeline_overlap   # cp.async throughput bounds
    - epilogue_fusion    # Bias+GeLU algebraic laws
    - warp_primitives    # shfl.sync reductions
    - architecture       # PAX axiom mappings

loss:
  type: po_weighted_cross_entropy
  weights:
    lean4_proof: 2.0     # Proof correctness is highest priority
    ptx_kernel: 1.5      # Implementation correctness
    futhark_spec: 1.0    # Spec adherence
    certificate: 0.5     # PO tagging

inference:
  temperature: 0.0       # Deterministic — proofs don't have "creative" answers
  top_k: 1
  repetition_penalty: 1.0
```

### The PO-Weighted Loss Function

Standard cross-entropy treats every token equally. We weight proof tokens higher than comment tokens:

```
L = -sum_i w(category_i) * log P(token_i | context)

Where:
  w(lean4_proof)  = 2.0  — getting a theorem wrong is unacceptable
  w(ptx_kernel)   = 1.5  — implementation must match the proof
  w(futhark_spec) = 1.0  — spec is the reference
  w(certificate)  = 0.5  — tagging is secondary
```

This produces a model that prioritizes correctness over style.

### Deterministic Generation

PAX-Coder runs at temperature 0.0 with top_k=1. There is no sampling, no creativity, no stochastic variation.

Why: A proof is either correct or it isn't. `2 + 2 = 4` every time. A model generating formal proofs must be deterministic.

```python
# Inference — zero entropy
output = model.generate(
    input_ids,
    temperature=0.0,
    top_k=1,
    top_p=1.0,
    repetition_penalty=1.0,
    do_sample=False,
    max_new_tokens=2048
)
```

Same input → same kernel → same proof. Every time.

---

## Training on RTX 3080 (Single GPU)

For the public PAX-Coder (7B, based on DeepSeek-Coder), single-GPU training fits on the RTX 3080:

```bash
# VRAM budget — RTX 3080 10GB:
#   Base model (4-bit QLoRA)  ~4.2 GB
#   LoRA adapters (r=32)     ~0.1 GB
#   Gradients (8-bit paged)  ~1.5 GB
#   Activations (GC)         ~1.8 GB
#   Dataset buffer           ~0.5 GB
#   Total                    ~8.1 GB (1.9 GB headroom)

# One command:
./run_training.sh

# What it does:
#   1. Checks free VRAM (needs ~8GB)
#   2. Extracts training data from PAX corpus → JSONL
#   3. Fine-tunes DeepSeek-Coder-7B with QLoRA
#   4. Exports to GGUF for Ollama
#   5. ~4-6 hours on RTX 3080
```

### Full Nemotron 70B (Multi-GPU)

The full sovereign Nemotron model requires distributed training via Megatron-LM:

```bash
# Multi-node launch (4× A100 80GB or 8× RTX 4090 24GB)
torchrun \
  --nproc_per_node=4 \
  --nnodes=1 \
  --master_port=29500 \
  pretrain_gpt.py \
  --tensor-model-parallel-size 4 \
  --pipeline-model-parallel-size 1 \
  --num-layers 80 \
  --hidden-size 8192 \
  --num-attention-heads 64 \
  --seq-length 4096 \
  --micro-batch-size 1 \
  --global-batch-size 64 \
  --lr 1.5e-5 \
  --train-iters 2000 \
  --bf16 \
  --data-path pax-verified-corpus \
  --save checkpoints/nemotron-pax \
  --load nvidia/nemotron-70b-instruct
```

---

## What Makes This Sovereign

| Property | What it means |
|----------|--------------|
| **No cloud dependency** | Runs on local NVIDIA hardware. No API keys, no rate limits, no vendor lock-in. |
| **No trust dependency** | Every output is machine-checked. You don't trust the model — you verify its proofs. |
| **No data dependency** | Training corpus is self-generated from the PAX codebase. Not GitHub scrapes. |
| **Deterministic** | Same prompt → same output. Auditable, reproducible, provable. |
| **Hardware-native** | Model writes for the GPU it runs on. No abstraction layers. Raw PTX. |

This is what sovereign compute means: you own the hardware, you own the model, you own the training data, and you can verify every output.

---

## Custom NVIDIA Builds

SnapKitty offers custom kernel builds targeting your specific NVIDIA hardware:

### What You Get

```
┌──────────────────────────────────────────────────────┐
│  YOUR GPU → PAX-Coder generates:                     │
│                                                      │
│  1. Lean 4 correctness proof (zero sorry)            │
│  2. PTX kernel targeting YOUR sm_XX arch             │
│  3. Futhark functional spec (ground truth)           │
│  4. PAX certificate (which POs are satisfied)        │
│  5. NCU-ready binary (compile + profile)             │
│                                                      │
│  Not generic CUDA. YOUR hardware. PROVEN correct.    │
└──────────────────────────────────────────────────────┘
```

### Supported Architectures

| GPU | Architecture | Compute | Key Feature | Status |
|-----|-------------|---------|-------------|--------|
| RTX 3080 | Ampere | sm_86 | cp.async 3-stage pipeline | **Verified** |
| RTX 3090 | Ampere | sm_86 | Same as 3080 + 24GB VRAM | **Verified** |
| RTX 4090 | Ada Lovelace | sm_89 | TMA + cluster multicast | **Verified** |
| A100 | Ampere | sm_80 | Async copy + large shared | **Verified** |
| H100 | Hopper | sm_90 | TMA + warp specialization | **Spec complete** |

### How to Order

```bash
# 1. Tell us your GPU
echo "RTX 4090" | pax-coder --target sm_89

# 2. Tell us your computation
echo "128x128 GEMM with Residual+GeLU epilogue, FP16 in, FP32 accum"

# 3. Get back:
#    - verified_gemm_sm89.ptx    (your kernel)
#    - verified_gemm_sm89.lean   (your proof)
#    - verified_gemm_sm89.fut    (your spec)
#    - CERTIFICATE.json          (PO1-PO8 status)
```

---

## The Competitive Advantage

| | Generic Code Models | cuBLAS | PAX-Coder |
|--|---|---|---|
| **Correctness** | Hope-based | Tested, not proven | Machine-checked proof |
| **Hardware targeting** | Generic CUDA | Black box | Architecture-specific PTX |
| **Reproducibility** | Temperature sampling | Deterministic | Deterministic + auditable |
| **Verification** | None | Benchmarks | Lean 4 formal proof |
| **Customization** | Prompt engineering | Library calls | Fine-tuned for YOUR arch |
| **Sovereignty** | Cloud API | Proprietary | Runs on YOUR GPU |

---

## Repo Structure (PAX-Coder)

```
pax-coder/
├── PAX/                        Lean 4 formal proofs (training source)
├── src/
│   ├── rtx_gemm_ptx.cu        sm_86 GEMM — raw mma.sync
│   ├── rtx_gemm_pipeline.cu   sm_86 3-stage async — proven overlap
│   ├── rtx_gemm_epilogue.cu   sm_86 Bias+GeLU fusion — proven bounds
│   └── pax_kernel.fut         Futhark functional spec
├── demo/
│   ├── demo.py                Live inference demo
│   └── showcase_examples.jsonl Example prompts + outputs
├── docs/
│   ├── PAX_ARCHITECTURE.md    5 axioms → 8 proof obligations
│   └── SOVEREIGN_NVIDIA_TRAINING_GUIDE.md   (this file)
├── train.py                   QLoRA fine-tuning (RTX 3080 single-GPU)
├── export_training_data.py    PAX corpus → JSONL extraction
├── run_training.sh            One-command training launcher
├── Modelfile                  Ollama deployment
├── LICENSE.tri                BSL-1.1 / AGPL-3.0 / MPL-2.0
└── SOVEREIGN_NODE_KEY.md      Production access
```

---

## Getting Started

### Option 1: Use PAX-Coder directly (pre-trained, public)

```bash
ollama pull Snapkitty/pax-coder
ollama run pax-coder "Write a verified GEMM for my RTX 3080"
```

### Option 2: Train your own PAX model on your NVIDIA GPU

```bash
git clone https://github.com/SNAPKITTYWEST/pax-coder
cd pax-coder
./run_training.sh  # ~4-6h on RTX 3080
```

### Option 3: Custom sovereign build (enterprise)

Contact `licensing@snapkittywest.dev` for:
- Architecture-specific kernel libraries
- On-premises Nemotron deployment
- Formal verification consulting
- Custom PO audits

---

## License

Tri-licensed: BSL-1.1 / AGPL-3.0 / MPL-2.0

Copyright (C) 2026 Bel Esprit D'Accord Irrevocable Trust
SnapKitty Collective Limited

Authors: Ahmad Ali Parr — Jessica Westerhoff
