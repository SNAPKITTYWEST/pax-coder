---
license: apache-2.0
base_model: deepseek-ai/deepseek-coder-7b-instruct-v1.5
tags:
  - code-generation
  - gpu-kernels
  - formal-verification
  - lean4
  - ptx
  - cuda
  - tensor-cores
  - ampere
pipeline_tag: text-generation
datasets:
  - Snapkitty/pax-training-data
---

# PAX-Coder

![Lean 4](https://img.shields.io/badge/Lean_4-zero_sorry-brightgreen?style=flat-square)
![PTX](https://img.shields.io/badge/PTX-sm__86-76b900?style=flat-square)
![License](https://img.shields.io/badge/license-Apache_2.0-orange?style=flat-square)

Fine-tuned DeepSeek-Coder-7B that generates formally verified CUDA kernels for NVIDIA Ampere (RTX 3080, sm_86).

Every output includes a **Lean 4 proof**, a **PTX implementation**, and a **Futhark functional spec** — not just code, but code with a correctness certificate attached.

---

## What it generates

Given a plain English prompt like:

> *"Write a verified 3-stage async GEMM kernel for RTX 3080 with Bias+GeLU fusion"*

PAX-Coder returns:

1. **Lean 4 theorem** — machine-checkable proof of correctness (zero sorry)
2. **PTX kernel** — `mma.sync`, `ldmatrix`, `cp.async` targeting sm_86
3. **Futhark spec** — compiler-verifiable functional reference
4. **PAX compliance** — which of the 8 proof obligations (PO1–PO8) the kernel satisfies

---

## Quickstart

### Ollama
```bash
ollama run Snapkitty/pax-coder "Write a verified FP16 GEMM kernel for RTX 3080"
```

### Python
```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained("Snapkitty/pax-coder-7b")
tokenizer = AutoTokenizer.from_pretrained("Snapkitty/pax-coder-7b")

prompt = """### Instruction:
Write a Lean 4 proof that IEEE-754 binary16 rounding error is bounded by 0.5 ulp.

### Context:
Arch: sm_86 | Category: fp16 | Constraints: [PO4 PO5]

### Response:
"""
inputs = tokenizer(prompt, return_tensors="pt")
out = model.generate(**inputs, max_new_tokens=512, temperature=0.1)
print(tokenizer.decode(out[0]))
```

---

## Training this yourself

### 1. Extract training data
```bash
python3 export_training_data.py
# → build/pax_train.jsonl
# → build/pax_val.jsonl
# → build/pax_test.jsonl
```

### 2. Fine-tune (RTX 3080 10GB)
```bash
pip install -r requirements.txt
./run_training.sh
# ~4-6 hours, uses ~8.1GB VRAM
```

### 3. Run locally
```bash
ollama create pax-coder -f Modelfile
ollama run pax-coder "Write a verified 3-stage pipeline GEMM for sm_86"
```

### 4. Push to HuggingFace
```bash
huggingface-cli login
huggingface-cli upload Snapkitty/pax-coder-7b pax-coder-7b-rtx3080/gguf/ --repo-type model
```

---

## Repository layout

```
PAX/                    Lean 4 formal proofs
  ConstraintDAG.lean    HyperKitty 7-node pipeline DAG, proven acyclic
  PipelineDAG.lean      3-stage cp.async throughput bound theorem
  Float16_Rounding.lean IEEE-754 binary16 RNE error bound
  WMMA.lean             mma.sync.aligned.m16n8k8 semantics
  IR_DAG.lean           PAX-IR SSA module DAG

src/                    GPU kernels
  rtx_gemm_ptx.cu       128×128 GEMM, double-buffer, sm_86
  rtx_gemm_pipeline.cu  3-stage cp.async GEMM
  rtx_gemm_epilogue.cu  Bias+GeLU, Residual+GeLU fusion
  pax_kernel.fut        Futhark functional spec

docs/
  PAX_ARCHITECTURE.md   5 axioms → 8 proof obligations

export_training_data.py Extracts Lean+PTX+Futhark → JSONL
train.py                QLoRA fine-tuning (RTX 3080, 4-bit)
run_training.sh         One-command launcher
Modelfile               Ollama model definition
```

---

## Proof obligations

| PO | What it guarantees |
|----|--------------------|
| PO1 | Index space partition: every element assigned once, no overlap |
| PO2 | Address space separation: shared ∩ global = ∅ |
| PO3 | SIMT reconvergence before every barrier |
| PO4 | Happens-before strict partial order across cp.async chain |
| PO5 | Permission sum ≤ 1 at every memory address |
| PO6 | Barrier permission conservation |
| PO7 | Data-race freedom |
| PO8 | Termination + correctness |

---

## Hardware target

RTX 3080 · Ampere sm_86 · 10GB GDDR6X · `mma.sync.aligned.m16n8k8` FP16→FP32

---

## Citation

```bibtex
@software{pax_coder_2026,
  title  = {PAX-Coder: Verified GPU Kernel Generation},
  author = {Parr, Ahmad Ali},
  year   = {2026},
  url    = {https://github.com/SNAPKITTYWEST/pax-coder}
}
```

Apache 2.0 — commercial use permitted.
