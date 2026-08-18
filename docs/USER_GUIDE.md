# PAX-Coder User Guide

---

## Table of Contents

1. [What PAX-Coder Actually Does](#1-what-pax-coder-actually-does)
2. [Getting a Sovereign Node Key](#2-getting-a-sovereign-node-key)
3. [Installation](#3-installation)
4. [Your First Kernel](#4-your-first-kernel)
5. [Prompt Format](#5-prompt-format)
6. [Output Format](#6-output-format)
7. [Kernel Categories](#7-kernel-categories)
8. [Reading the Lean 4 Proofs](#8-reading-the-lean-4-proofs)
9. [Verifying the PTX Yourself](#9-verifying-the-ptx-yourself)
10. [The 8 Proof Obligations](#10-the-8-proof-obligations)
11. [Running the Futhark Spec](#11-running-the-futhark-spec)
12. [The pax-verify API (Enterprise)](#12-the-pax-verify-api-enterprise)
13. [Troubleshooting](#13-troubleshooting)
14. [Glossary](#14-glossary)

---

## 1. What PAX-Coder Actually Does

Most LLMs that write CUDA code are pattern-matching against training data. They produce code that looks like the CUDA samples repository. Sometimes it is correct. Often it has subtle race conditions, unproven memory model assumptions, or numerical behavior that works on the test input but fails on edge cases.

PAX-Coder is trained on a different corpus entirely — the PAX sovereign GPU computing stack. PAX was built by deriving everything from first principles:

- **Five mathematical axioms** about parallel execution
- **Eight proof obligations** that every correct kernel must satisfy
- **Lean 4 proofs** that verify each obligation mechanically (zero sorry on the critical path)
- **PTX implementations** that correspond directly to the proved abstract machines
- **Futhark functional specs** that serve as compiler-verifiable ground truth

When you ask PAX-Coder for a kernel, it does not search for the nearest similar code. It reasons from the axioms and returns a kernel that it can back with a proof structure. The proof is the deliverable, not an afterthought.

---

## 2. Getting a Sovereign Node Key

Production-authorized use requires a provisioned Sovereign Node Key. See [SOVEREIGN_NODE_KEY.md](../SOVEREIGN_NODE_KEY.md) and [CONTACT.md](../CONTACT.md) for full instructions.

**Short version:**
1. **Contact:** Submit provisioning request at [CONTACT.md](../CONTACT.md)
2. **Select tier:**
   - Individual: $250-$500 per node (one-time, one workstation)
   - Commercial: $12,000-$25,000/year (unlimited internal nodes)
   - Enterprise: $50,000+/year (custom deployment)
3. **Approval:** PAX-Coder reviews (1–3 business days)
4. **Commercial Agreement & Payment:** Required before provisioning
5. **Receive:** Node credential + operator-signed authorization
6. **Use:** Protected operations now authorized

**All production use:** Requires contact, approval, and commercial terms. See [PRICING.md](../PRICING.md) and [CONTACT.md](../CONTACT.md).

---

## 3. Installation

### Via Ollama (recommended)

```bash
# Install Ollama if you haven't
curl -fsSL https://ollama.com/install.sh | sh

# Pull PAX-Coder
ollama pull Snapkitty/pax-coder

# Run
ollama run Snapkitty/pax-coder
```

### Via HuggingFace Transformers

```bash
pip install transformers accelerate bitsandbytes torch
```

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

model = AutoModelForCausalLM.from_pretrained(
    "Snapkitty/pax-coder-7b",
    torch_dtype=torch.bfloat16,
    load_in_4bit=True,
    device_map="auto"
)
tokenizer = AutoTokenizer.from_pretrained("Snapkitty/pax-coder-7b")
```

### Build from source

```bash
git clone https://github.com/SNAPKITTYWEST/pax-coder
cd pax-coder
pip install -r requirements.txt
python3 export_training_data.py
./run_training.sh
```

---

## 4. Your First Kernel

```bash
ollama run Snapkitty/pax-coder "Write a verified FP16 GEMM kernel for RTX 3080"
```

You will receive three code blocks and a certificate:

1. A Lean 4 theorem proving correctness
2. A PTX kernel using `mma.sync.aligned.m16n8k8`
3. A Futhark functional spec
4. A line listing which proof obligations are satisfied

If any of those are missing, the prompt needs more context. See section 5.

---

## 5. Prompt Format

PAX-Coder expects a structured prompt. The Ollama template handles this automatically,
but for direct API use:

```
### Instruction:
<plain English description of the kernel you want>

### Context:
Arch: <sm_86 or sm_90> | Category: <gemm|fp16|pipeline|epilogue|warp> | Constraints: [<PO list>]

### Response:
```

**Good prompts:**

```
Write a 3-stage async GEMM kernel for RTX 3080 sm_86 with cp.async double buffer.
Prove the throughput bound. Target: FP16 input, FP32 accumulation.
```

```
Formalize IEEE-754 binary16 round-to-nearest-even in Lean 4.
Prove the error bound |round(x) - x| ≤ 0.5 ulp. Match hardware __float2half_rn.
```

```
Write an in-register Bias+GeLU epilogue for Ampere sm_86.
Prove the GeLU approximation error is bounded by 0.001.
Proof obligations needed: PO8.
```

**What to include:**
- Hardware target (sm_86 vs sm_90 changes available instructions)
- What proof you want (error bound, correctness equivalence, throughput bound)
- Which POs matter to you (omit = model decides)

---

## 6. Output Format

Every PAX-Coder response follows this structure:

````
```lean4
theorem <name> ... := by
  ...
```

```cuda  (or ptx)
__global__ void pax_<name>(...) {
  ...
}
```

```futhark
def <name> [m] [n] ... = ...
```

**PAX Certificate:** [PO1] [PO3] [PO5] [PO8] ✓
````

The Lean 4 block is the **proof**. The CUDA/PTX block is the **implementation**.
The Futhark block is the **specification**. The certificate is the **compliance summary**.

All three are meant to be used together:
- Compile the Lean 4 with `lake build` to verify the proof
- Compile the PTX with `nvcc -arch=sm_86` to run the kernel
- Compile the Futhark with `futhark cuda` to get a reference implementation for testing

---

## 7. Kernel Categories

### fp16 — FP16 Rounding
Formalizes IEEE-754 binary16 arithmetic. Key theorem: `|round(x) - x| ≤ 0.5 ulp`.
Use when: writing accumulation loops, checking numerical stability, understanding hardware RNE.

```
"Write a Lean 4 proof that FP16 FMA error is bounded by 0.5 ulp."
```

### gemm — Matrix Multiplication
Full GEMM pipeline from functional spec to mma.sync PTX. Key theorem: `wmma_gemm = gemm_spec`.
Use when: need a verified GEMM baseline, replacing cuBLAS with auditable code.

```
"Write a 128×128 verified GEMM kernel for sm_86. Include index space partition proof."
```

### pipeline — Async Pipeline
3-stage cp.async overlap with proven throughput bound. Key theorem: `throughput ≥ (1 - 1/stages) × min(bw_compute, bw_memory)`.
Use when: memory-bandwidth-limited kernels, hiding latency, pipelining tile loads.

```
"Write a 3-stage cp.async GEMM pipeline. Prove the overlap bound for sm_86."
```

### epilogue — Fused Epilogues
In-register Bias+GeLU and Residual+GeLU fusion. Key theorem: `|GeLU_approx - GeLU_exact| ≤ 0.001`.
Use when: transformer inference, avoiding extra memory round-trips, fusing activations.

```
"Write a Bias+GeLU epilogue fused into the GEMM output. Prove the numerical bound."
```

### warp — Warp Primitives
shfl.sync.xor butterfly reductions. Key theorem: `warp_reduce_sum(vals) = Σ vals[i]`.
Use when: implementing softmax, dot products, layer norm, any warp-level reduction.

```
"Write a warp reduction for softmax using shfl.sync.xor. Prove correctness."
```

### architecture — PAX Axiom Mapping
Explains how the 5 PAX axioms map to proof obligations for a specific kernel design.
Use when: designing a new kernel category, auditing an existing kernel, teaching the framework.

```
"Map PAX Architecture axioms to proof obligations for a custom attention kernel."
```

---

## 8. Reading the Lean 4 Proofs

If you are new to Lean 4, here is what to look for:

**`theorem`** — a named claim that has been machine-checked.

**`sorry`** — a placeholder. On the critical path (correctness, error bounds), PAX-Coder aims for zero sorry. If you see one, it means that part of the proof is still open.

**`by nlinarith [...]`** — the proof was found by a numeric linear arithmetic decision procedure. It checked out.

**`by simp [...]`** — the proof was found by simplification. Also mechanical.

**`by exact_mod_cast`** — a numeric cast was verified automatically.

To verify a proof yourself:

```bash
# Install Lean 4 + Lake
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# In the PAX-Coder repo
cd PAX
lake update   # downloads Mathlib (~10 min first time)
lake build    # builds all proofs — must complete with 0 errors
```

If `lake build` succeeds with zero errors and zero sorries, the proofs are machine-verified.

---

## 9. Verifying the PTX Yourself

```bash
# Compile PTX
nvcc -arch=sm_86 -ptx src/rtx_gemm_ptx.cu -o build/pax_gemm.ptx

# Inspect mma.sync instruction
grep "mma.sync" build/pax_gemm.ptx

# Compile shared library for host testing
nvcc -arch=sm_86 --shared src/rtx_gemm_ptx.cu -o build/pax_gemm.so

# Profile with NCU (Nsight Compute)
ncu --metrics sm__warps_active.avg,l1tex__t_bytes_pipe_lsu_mem_global_op_ld.sum \
    --target-processes all ./your_test_binary

# Inspect SASS (compiled GPU assembly)
nvdisasm build/pax_gemm.so | grep -A3 "HMMA"
```

The `mma.sync.aligned.m16n8k8.row.col.f32.f16.f16.f32` instruction in PTX corresponds directly to the `wmma::mma_sync` call in the WMMA layer, which the Lean 4 proof shows equals `gemmSpec`. The proof chain is: PTX instruction → WMMA abstraction → functional spec.

---

## 10. The 8 Proof Obligations

When PAX-Coder annotates an output with `[PO1] [PO3]`, here is what that means in practice:

**PO1 — Index Space Partition**
Every thread accesses exactly one output element. No two threads write to the same location.
*Practical check:* the block/warp/lane indexing math is bijective.

**PO2 — Address Space Separation**
Shared memory and global memory do not overlap. Shared memory is always allocated at fixed offsets within `smem[]`.
*Practical check:* no raw pointer arithmetic that could alias shared into global.

**PO3 — SIMT Reconvergence**
All 32 threads in a warp reach `__syncwarp()` or the `mma.sync` instruction together.
*Practical check:* no `if (lane_id < N)` guards inside the mma.sync path.

**PO4 — Happens-Before Order**
Every `cp.async.wait_group N` correctly orders all prior `cp.async.commit_group` calls.
*Practical check:* every load from shared memory is preceded by a matching wait.

**PO5 — Permission Sum ≤ 1**
At most one thread holds write permission to any memory location at any time.
*Practical check:* output tiles are disjoint (follows from PO1).

**PO6 — Barrier Conservation**
`__syncthreads()` does not create or destroy memory permissions — it transfers them.
*Practical check:* every write before a barrier is visible after it.

**PO7 — Data-Race Freedom**
No two threads access the same address where at least one access is a write, without synchronization.
*Practical check:* shared memory access pattern is within-warp or guarded by barrier.

**PO8 — Termination + Correctness**
The kernel terminates (no infinite loops) and produces output matching the functional spec.
*Practical check:* K-loop bound is finite, final output equals `C += A × B` on the tile.

---

## 11. Running the Futhark Spec

The Futhark spec is the ground truth functional reference. Use it to test your PTX kernel:

```bash
# Install Futhark
brew install futhark  # macOS
# or: https://futhark-lang.org/install.html

# Compile Futhark CUDA backend
futhark cuda src/pax_kernel.fut -o build/pax_kernel

# Run reference GEMM
echo "[[1.0, 2.0], [3.0, 4.0]] [[5.0, 6.0], [7.0, 8.0]] [[0.0, 0.0], [0.0, 0.0]]" \
  | ./build/pax_kernel -e gemm_fp16_f32

# Compare against your PTX kernel output
# If they match, your PTX satisfies PO8 (correctness)
```

---

## 12. The pax-verify API (Enterprise)

Enterprise tier includes a hosted verification endpoint that checks a kernel against the full PAX proof chain without requiring a local Lean 4 install.

```bash
# Verify a kernel
curl -X POST https://api.collectivekitty.com/pax-verify \
  -H "Authorization: Bearer $PAX_ENTERPRISE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "lean_proof": "theorem round_error_bound ...",
    "ptx_kernel": "__global__ void pax_gemm ...",
    "target_arch": "sm_86",
    "obligations": ["PO1", "PO3", "PO5", "PO8"]
  }'
```

Response:
```json
{
  "verified": true,
  "obligations_satisfied": ["PO1", "PO3", "PO5", "PO8"],
  "obligations_open": [],
  "worm_seal": "blake3:a3f8c2...",
  "certificate": "ed25519:4f9a...",
  "lean_build": "success",
  "nvcc_compile": "success",
  "timestamp": "2026-08-17T21:00:00Z"
}
```

The WORM seal is a permanent, tamper-evident record that this kernel was verified at this timestamp.

---

## 13. Troubleshooting

**The model outputs a sorry in the Lean 4 proof**
Some proof obligations (especially on custom kernel requests) require domain-specific knowledge not fully in the training data. Add more context to your prompt: specify which POs you need, provide the abstract machine model you are using, or split the request into smaller theorems.

**nvcc fails to compile the PTX**
Check the `Arch:` field in your prompt. sm_90 instructions (TMA, cluster multicast) do not compile for sm_86. If you asked for an sm_86 kernel and got sm_90 PTX, add `Arch: sm_86` explicitly to the Context field.

**Futhark compilation fails**
The generated Futhark uses size-dependent types. Ensure you are on Futhark 0.25+. Run `futhark --version`.

**CUDA OOM during training**
Reduce `max_seq_length` to 1024 in `train.py` and increase `grad_accum` to 32. The RTX 3080 target is 2048 with ~1.9GB headroom — other apps running on the GPU will eat into that.

**lake build hangs**
First run downloads Mathlib (~2GB). This is expected. Let it complete. Subsequent builds use the cache.

---

## 14. Glossary

**PAX** — Parallel Accelerator eXecution. The sovereign GPU computing architecture that PAX-Coder is trained on.

**mma.sync.aligned.m16n8k8** — PTX instruction for Ampere tensor core matrix multiply-accumulate. Takes FP16 inputs, produces FP32 accumulator. 16×8 output tile, 8-wide K dimension.

**cp.async** — PTX instruction for asynchronous copy from global to shared memory. Does not block the thread until `cp.async.wait_group` is issued.

**Lean 4** — Proof assistant and functional programming language. Used to mechanically verify PAX theorems. `lake build` compiles and checks all proofs.

**sorry** — Lean 4 keyword that accepts a theorem without proof. On the critical path, zero sorry is the standard.

**Futhark** — Functional GPU programming language with size-dependent types. Serves as the functional specification layer in PAX.

**ULP** — Unit in the Last Place. The gap between two adjacent floating-point values. FP16 rounding error is bounded by 0.5 ulp.

**WORM** — Write Once Read Many. The append-only ledger used to record sealed outputs and contributions in the SnapKitty sovereign stack.

**Ed25519** — Elliptic curve signature scheme used for Sovereign Node Keys. 32-byte keypairs, fast, secure.

**Bifrost** — The WORM-sealing and verification layer in the SnapKitty stack. Signs every sealed output with Ed25519.

**HyperKitty DAG** — The 7-node constraint pipeline (Input → Memory → Retrieval → Transform → Constraint → Proof → Output) that every PAX-Coder kernel generation passes through.

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*
