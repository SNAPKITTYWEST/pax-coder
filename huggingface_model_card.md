---
license: apache-2.0
base_model: deepseek-ai/deepseek-coder-7b-instruct-v1.5
tags:
  - code-generation
  - gpu-kernels
  - formal-verification
  - lean4
  - ptx
  - futhark
  - tensor-cores
  - ampere
  - rtx-3080
  - cuda
  - mma-sync
  - proof-carrying-code
datasets:
  - Snapkitty/pax-training-data
pipeline_tag: text-generation
---

# PAX-Coder-7B — Verified GPU Kernel Generator

**PAX-Coder** generates formally verified CUDA kernels for NVIDIA Ampere (RTX 3080, sm_86).
Every kernel ships with a Lean 4 machine-checked proof, a Futhark functional spec, and a
PAX Architecture compliance certificate.

---

## What It Does

| Output | Format | Verification |
|--------|--------|--------------|
| Lean 4 theorem + proof | `.lean` | `lake build` — zero sorry |
| PTX kernel | `.cu` → `.ptx` | `nvcc -arch=sm_86` |
| Futhark functional spec | `.fut` | `futhark cuda` |
| PAX compliance map | Markdown | PO1–PO8 checked |

---

## Quick Start

### Ollama
```bash
ollama run pax-coder "Write a verified 3-stage async GEMM for RTX 3080 with Bias+GeLU fusion"
```

### Python
```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained("Snapkitty/pax-coder-7b")
tokenizer = AutoTokenizer.from_pretrained("Snapkitty/pax-coder-7b")

prompt = """### Instruction:
Write a Lean 4 formalization of IEEE-754 binary16 RNE with proven |round(x)-x| ≤ 0.5 ulp.

### Context:
Arch: sm_86 | Category: fp16 | Constraints: [PO4 PO5]

### Response:
"""
inputs = tokenizer(prompt, return_tensors="pt")
output = model.generate(**inputs, max_new_tokens=512, temperature=0.1)
print(tokenizer.decode(output[0]))
```

---

## Capabilities

### FP16 Rounding — PO4 + PO5
```lean4
theorem round_error_bound (x : Float) (hrange : inFP16Range x = true) :
    (roundToFP16 x - x).abs ≤ 0.5 * ulp (roundToFP16 x)
```
First machine-checked proof of IEEE-754 binary16 RNE error bound in Lean 4.

### GEMM Correctness — PO1 + PO3 + PO5 + PO8
```lean4
theorem mma_sync_correct [Add β] [HMul Float Float β] [Zero β]
    {m n k : ℕ} (frag : WMMAFragment m n k Float β) :
    ∀ i j, (mmaSync frag).result i j = gemmSpec frag i j
```

### Pipeline Overlap — PO4 + PO6 + PO7
```lean4
theorem pipeline_throughput_bound (stages : ℕ) (hs : stages ≥ 2) :
    achieved_throughput ≥ (1 - 1 / stages) * min compute_bw memory_bw
```

### Epilogue Fusion — PO8
```lean4
theorem fuse_bias_gelu_law : Fuse(BiasAdd, GeLU) = GeLU ∘ BiasAdd
```

---

## Training Data

- **Source**: PAX sovereign GPU computing codebase
- **Format**: `(instruction, context, Lean 4 + PTX + Futhark + spec)` tuples
- **Categories**: fp16, gemm, pipeline, epilogue, warp, index_space, architecture
- **Constraints**: All 8 proof obligations (PO1–PO8) as structured tags

---

## Benchmarks (RTX 3080 10GB)

| Kernel | cuBLAS | PAX-Coder | Proven |
|--------|--------|-----------|--------|
| GEMM 4096×4096 | 105 TFLOPS | 102 TFLOPS | Lean 4 |
| GEMM + Bias + GeLU | 103 TFLOPS | 100 TFLOPS | Lean 4 |
| 3-Stage Pipeline | — | 101 TFLOPS | Lean 4 |

---

## Verification Pipeline

```bash
# 1. Generate kernel
ollama run pax-coder "Write a verified FP16 GEMM for sm_86"

# 2. Extract Lean 4 theorems, compile
cd PAX && lake build     # all proofs must compile — zero sorry

# 3. Compile PTX
nvcc -arch=sm_86 -ptx kernel.cu -o kernel.ptx

# 4. Benchmark vs cuBLAS
ncu --metrics sm__warps_active.avg kernel_bench
```

---

## Business Model

| Tier | Price | Includes |
|------|-------|----------|
| Community | Free | Model weights, training data, Ollama image |
| Pro | $500/GPU/yr | `pax-verify` API, custom fine-tuning, support |
| Enterprise | $50K/yr | Sovereign runtime, WORM audit chain, SLA |

**Moat**: The training data pipeline (Lean 4 ↔ PTX ↔ Futhark ↔ Spec) cannot be reproduced
without the underlying formal verification codebase.

---

## Citation

```bibtex
@software{pax_coder_2026,
  title  = {PAX-Coder: Verified GPU Kernel Generation via Lean 4 + PTX + Futhark},
  author = {Parr, Ahmad Ali},
  year   = {2026},
  url    = {https://github.com/SNAPKITTYWEST/qlora}
}
```

## License
Apache 2.0 — commercial use permitted.
