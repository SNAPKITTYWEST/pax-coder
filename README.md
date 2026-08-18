# PAX-Coder

![Lean 4](https://img.shields.io/badge/Lean_4-zero_sorry-brightgreen?style=flat-square)
![PTX](https://img.shields.io/badge/PTX-sm__86-76b900?style=flat-square)
![Futhark](https://img.shields.io/badge/Futhark-verified-blue?style=flat-square)
![License](https://img.shields.io/badge/license-Apache_2.0-orange?style=flat-square)
![Status](https://img.shields.io/badge/status-v1.0-brightgreen?style=flat-square)

**Verified GPU Kernel Generation via Lean 4 · PTX · Futhark**

PAX-Coder fine-tunes DeepSeek-Coder-7B on a dataset of formally verified CUDA kernels
for NVIDIA Ampere (RTX 3080, sm_86). Every generated kernel ships with:

- **Lean 4 proof** — machine-checked correctness (zero sorry)
- **PTX implementation** — `mma.sync`, `ldmatrix`, `cp.async` for sm_86
- **Futhark spec** — compiler-verifiable functional reference
- **PAX compliance certificate** — 8 proof obligations, each tagged

---

## Architecture: HyperKitty Constraint DAG

```
🧠Input → 📚Memory → 🔍Retrieval → ⚙Transform → ⚖Constraint → 🔐Proof → 🌐Output
```

Formalized as a verified Lean 4 inductive type in `PAX/ConstraintDAG.lean`.
Proven acyclic, single-source, single-sink.

---

## Lean 4 Modules

| Module | Purpose | POs |
|--------|---------|-----|
| `PAX/ConstraintDAG.lean` | HyperKitty 7-node DAG formalization | PO8 |
| `PAX/PipelineDAG.lean` | 3-stage cp.async DAG + throughput bound | PO4 PO6 PO7 |
| `PAX/Float16_Rounding.lean` | IEEE-754 binary16 RNE error bound | PO4 PO5 |
| `PAX/WMMA.lean` | mma.sync.aligned.m16n8k8 semantics | PO1 PO3 PO5 PO8 |
| `PAX/IR_DAG.lean` | PAX-IR module DAG (SSA, no recursion) | — |
| `PAX/TrainingData.lean` | Dataset extractor structure | — |

```bash
cd PAX && lake build    # all proofs compile — zero sorry required
```

---

## PTX Kernels (src/)

| File | Kernel | Proof |
|------|--------|-------|
| `rtx_gemm_ptx.cu` | 128×128 GEMM, double-buffer | Lean 4 PO1+PO3+PO5 |
| `rtx_gemm_pipeline.cu` | 3-stage cp.async GEMM | Lean 4 PO4+PO6+PO7 |
| `rtx_gemm_epilogue.cu` | Bias+GeLU, Residual+GeLU fusion | PO8: ≤0.001 bound |
| `pax_kernel.fut` | Futhark GEMM + epilogue spec | functional correctness |

```bash
nvcc -arch=sm_86 -ptx src/rtx_gemm_ptx.cu -o build/pax_gemm.ptx
futhark cuda src/pax_kernel.fut -o build/pax_kernel
```

---

## PAX-Coder Model Pipeline

```
PAX codebase (Lean 4 + PTX + Futhark + Spec)
         ↓
export_training_data.py   →  build/pax_{train,val,test}.jsonl
         ↓
finetune_pax_coder.py     →  pax-coder-7b-lora/  +  pax-coder-7b-gguf/
         ↓
ollama create pax-coder -f Modelfile
         ↓
ollama run pax-coder "Write a verified GEMM kernel for RTX 3080"
```

### Step 1 — Extract training data
```bash
python3 export_training_data.py
# → build/pax_train.jsonl  (90%)
# → build/pax_val.jsonl    (5%)
# → build/pax_test.jsonl   (5%)
```

### Step 2 — Fine-tune (RTX 3080 or cloud A100)
```bash
pip install unsloth trl transformers datasets torch
python3 finetune_pax_coder.py
```

### Step 3 — Run locally
```bash
ollama create pax-coder -f Modelfile
ollama run pax-coder "Write a verified 3-stage async GEMM for sm_86 with Bias+GeLU fusion"
```

### Step 4 — Push to HuggingFace
```bash
huggingface-cli login
huggingface-cli upload pax-coder/pax-coder-7b pax-coder-7b-gguf/ --repo-type model
cp huggingface_model_card.md pax-coder-7b-gguf/README.md
```

---

## Proof Obligations

| PO | Invariant | Lean 4 |
|----|-----------|--------|
| PO1 | Index space partition (coverage + disjointness) | `partition_coverage` |
| PO2 | Address space separation | `shared_global_disjoint` |
| PO3 | SIMT reconvergence before barrier | `warp_reconverges_before_barrier` |
| PO4 | Happens-before strict partial order | `hb_strict_partial_order` |
| PO5 | Permission sum ≤ 1 at every address | `permission_sum_bound` |
| PO6 | Barrier permission conservation | `barrier_conserves_permissions` |
| PO7 | Data-race freedom | `no_data_race` |
| PO8 | Termination + correctness | `kernel_correct` |

---

## Business Model

| Tier | Price | What You Get |
|------|-------|-------------|
| Community | Free | Weights on HF (`Snapkitty/pax-coder-7b`), Ollama image, training data |
| Pro | $500/GPU/yr | `pax-verify` REST API, custom fine-tuning, support |
| Enterprise | $50K/yr | Sovereign runtime, WORM audit chain, SLA |

**The moat is the training data pipeline** — Lean 4 ↔ PTX ↔ Futhark ↔ Spec triples
cannot be reproduced without the underlying formal verification codebase.

---

## Prior Art & IP

All training data derived from:
- Original PAX codebase (authored by Ahmad Ali Parr)
- Public PTX ISA documentation (NVIDIA)
- Mathlib4 theorem patterns (Apache 2.0)
- Futhark stdlib (BSD-3)
- DeepSeek-Coder-7B base model (Apache 2.0)

No CUTLASS or vendor kernel code in training data.

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
Apache 2.0 — see [LICENSE](LICENSE).
