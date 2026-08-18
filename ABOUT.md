# About PAX-Coder

## What PAX-Coder Does

PAX-Coder is a fine-tuned AI model (based on DeepSeek-Coder-7B) that generates GPU kernels paired with formal proofs. You ask it to write a kernel, and it gives you:

1. **Lean 4 proof** — A mathematical proof that your kernel is correct
2. **PTX assembly** — The actual GPU code that runs on NVIDIA sm_86 hardware (RTX 3080, RTX 4090)
3. **Futhark reference** — A high-level functional specification to verify against
4. **PAX certificate** — Which safety guarantees this kernel provides

## For Whom

- **GPU engineers** who want to ship kernels with formal guarantees
- **CUDA developers** who want to skip manual proof-writing
- **Research labs** building verified AI infrastructure
- **Companies** shipping safety-critical ML models where "trust me bro" is not acceptable

## What Makes It Different

Most GPU kernel generators output code you hope is correct. PAX-Coder outputs code + a machine-checked proof that it IS correct. The proof can be read by any Lean 4 compiler and verified independently—no human judgment required.

## Key Topics

### 🎯 Getting Started
- **No prerequisites needed** — Read [User Guide](#user-guide) in the README
- **30 seconds**: Run via Ollama (pre-installed model)
- **3 minutes**: Run via Python (HuggingFace transformers)
- **30 minutes**: Train your own version locally

### 🔧 What You Can Ask For
- IEEE-754 floating-point proofs (rounding error bounds)
- GEMM kernels (matrix multiply)
- Async copy pipelines (3-stage, double-buffer)
- Epilogue fusion (Bias+GeLU, Residual+GeLU)
- Warp reductions (shfl.sync)
- Architecture mappings (axioms → proof obligations)

### 📋 What You Get
Every output includes:
- **Lean 4**: Machine-checked theorem (zero `sorry` placeholders)
- **PTX**: sm_86 assembly for RTX 3080 / RTX 4090
- **Futhark**: Functional spec (compiler-verified semantics)
- **Certificate**: Which of 8 proof obligations this satisfies

### 🏗️ The Five Axioms (Math Foundation)
1. **Index Space Primacy** — Each thread owns one element; proven partition
2. **Permission Necessity** — Every memory access has a fractional permission; sum ≤ 1
3. **Synchronization as State** — Barriers are happens-before edges
4. **Warp Distinctness** — SIMT reconvergence proven before barriers
5. **Verification Non-Negotiability** — No kernel ships without proof

These map to 8 proof obligations (PO1–PO8) that codify GPU safety.

### 🎓 Training
You can train your own version:
```bash
python3 export_training_data.py   # Extract proofs + code
./run_training.sh                  # QLoRA fine-tune (4-6h on RTX 3080)
ollama create pax-coder -f Modelfile
```

### 📜 License
Tri-licensed (BSL-1.1, AGPL-3.0, MPL-2.0). Use the Prolog reasoner to determine which license applies to your use case.

### 🔑 Sovereign Node Key
Production use requires a Sovereign Node Key — proof you've contributed to the stack. Not DRM; community membership. See [`SOVEREIGN_NODE_KEY.md`](SOVEREIGN_NODE_KEY.md).

## The Repository

| Folder | Purpose |
|--------|---------|
| `PAX/` | Lean 4 formal proofs (ConstraintDAG, PipelineDAG, Float16_Rounding, WMMA, IR_DAG) |
| `src/` | GPU kernel templates (PTX + Futhark specs) |
| `backends/` | License policy reasoner (Prolog) |
| `docs/` | Documentation (architecture, user guide, GTM) |
| `demo/` | Interactive examples |

## Key Files

- **[README.md](README.md)** — This document + quickstart + user guide
- **[USER_GUIDE.md](docs/USER_GUIDE.md)** — Step-by-step usage examples
- **[PAX_ARCHITECTURE.md](docs/PAX_ARCHITECTURE.md)** — 5 axioms → 8 proof obligations
- **[PAX_CODER_README.md](PAX_CODER_README.md)** — Commercial integration (GGUF, CUDA, PTX, GEMM bridge)
- **[SOVEREIGN_NODE_KEY.md](SOVEREIGN_NODE_KEY.md)** — How to get a node key
- **[LICENSE.tri](LICENSE.tri)** — Full tri-license text

## Hardware Support

| GPU | Architecture | Status |
|-----|--------------|--------|
| RTX 3080 | Ampere (sm_86) | Primary target ✅ |
| RTX 4090 | Ada (sm_90) | Secondary (TMA support planned) |

## Quick Links

- **Use it now**: [User Guide](#user-guide) in README
- **Examples**: `demo/` folder
- **Architecture details**: [PAX_ARCHITECTURE.md](docs/PAX_ARCHITECTURE.md)
- **Commercial integration**: [PAX_CODER_README.md](PAX_CODER_README.md)
- **Contribute**: [CONTRIBUTING.md](CONTRIBUTING.md)

---

**TL;DR**: Write English prose asking for a GPU kernel. PAX-Coder generates proof + code. Ship with confidence.
