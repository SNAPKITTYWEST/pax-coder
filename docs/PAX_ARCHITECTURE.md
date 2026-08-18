# PAX Architecture

**Verified GPU Computing via Lean 4 + PTX + Futhark**
Ahmad Ali Parr · 2026

---

## Overview

PAX (Proof-Carrying Architecture for eXecution) is a sovereign GPU computing framework that
generates formally verified CUDA kernels for NVIDIA Ampere (sm_86) and Hopper (sm_90).

Every kernel PAX produces ships with:
1. **Lean 4 theorems** — machine-checked correctness proofs (zero sorry)
2. **PTX implementation** — hand-rolled mma.sync / cp.async code
3. **Futhark functional spec** — compiler-verifiable reference
4. **WORM audit receipt** — Blake3+Ed25519 sealed output

---

## Axioms

### Axiom 1 — Index Space Primacy
Every thread accesses exactly one element of a formally defined, non-overlapping index space.
The partition must be proven: coverage (every element assigned) and disjointness (no element shared).

### Axiom 2 — Permission Necessity
Every memory access requires a fractional permission. Sum of permissions at any address ≤ 1.
Reads require shared permission; writes require exclusive permission.

### Axiom 3 — Synchronization as State Transition
Every barrier (`__syncthreads`, `cp.async.wait_group`) is a state transition in the
happens-before partial order. No memory access is valid without a prior HB edge.

### Axiom 4 — Warp Distinctness
Each warp executes SIMT without divergence on the critical mma.sync path.
Divergence is permitted only on boundary checks (row/col bounds).

### Axiom 5 — Verification Non-Negotiability
No kernel ships without a machine-checked proof of its critical path.
sorries in proof files = blocked deployment.

---

## Proof Obligations (PO1–PO8)

| PO | Name | Axiom | Lean 4 Theorem |
|----|------|-------|----------------|
| PO1 | Index space partition | 1 | `partition_coverage`, `partition_disjoint` |
| PO2 | Address space separation | 2 | `shared_global_disjoint` |
| PO3 | SIMT reconvergence | 4 | `warp_reconverges_before_barrier` |
| PO4 | Happens-before SPO | 3 | `hb_strict_partial_order` |
| PO5 | Permission sum ≤ 1 | 2 | `permission_sum_bound` |
| PO6 | Barrier permission conservation | 3 | `barrier_conserves_permissions` |
| PO7 | Data-race freedom | 2,3 | `no_data_race` |
| PO8 | Termination + correctness | 5 | `kernel_terminates`, `kernel_correct` |

---

## HyperKitty Constraint DAG

```xml
<DAG>
  <Node id="🧠Input"/>
  <Node id="📚Memory"/>
  <Node id="🔍Retrieval"/>
  <Node id="⚙Transform"/>
  <Node id="⚖Constraint"/>
  <Node id="🔐Proof"/>
  <Node id="🌐Output"/>
  <Edge from="🧠Input"      to="📚Memory"/>
  <Edge from="📚Memory"     to="🔍Retrieval"/>
  <Edge from="🔍Retrieval"  to="⚙Transform"/>
  <Edge from="⚙Transform"  to="⚖Constraint"/>
  <Edge from="⚖Constraint" to="🔐Proof"/>
  <Edge from="🔐Proof"      to="🌐Output"/>
</DAG>
```

Formalized in `PAX/ConstraintDAG.lean` as a verified Lean 4 inductive type.
Proven acyclic, single-source (Input), single-sink (Output).

---

## Kernel Categories

### FP16 Rounding (fp16)
IEEE-754 binary16 round-to-nearest-even. Proven: `|round(x) - x| ≤ 0.5 ulp`.
Matches hardware `__float2half_rn` and PTX `cvt.rn.f16.f32`.

### GEMM (gemm)
`mma.sync.aligned.m16n8k8` FP16→FP32. Tile: 128×128 work-group, 32×64 warp, 16×8 MMA.
Proven: `wmma_gemm = gemm_spec` for all FP16 inputs in normal range.

### Pipeline (pipeline)
3-stage `cp.async` double buffer. Proven: achieved throughput ≥ (1-1/3) × min(compute_bw, memory_bw).
HB edges: `HB(copy[s], compute[s])` and `HB(compute[s], copy[s+1])`.

### Epilogue (epilogue)
`Bias + GeLU` and `Residual + GeLU` in-register fusion.
Proven: `|GeLU_approx(x) - GeLU_exact(x)| ≤ 0.001` for `x ∈ [-8, 8]`.

### Warp (warp)
`shfl.sync.xor.b32` butterfly reduction. Proven correct for dot product and softmax max.

---

## Hardware Target

| Property | Value |
|----------|-------|
| GPU | NVIDIA RTX 3080 |
| Architecture | Ampere sm_86 |
| VRAM | 10 GB GDDR6X |
| Tensor Cores | 3rd gen (m16n8k8 FP16→FP32) |
| Async Copy | `cp.async.ca.shared.global` |
| Max Shared Mem | 48 KB/block (or 100 KB with dynamic) |

Secondary target: H100 sm_90 (TMA cluster multicast, `cp.async.bulk`).

---

## Build

```bash
# Lean 4 proofs
cd PAX && lake build

# PTX kernels
nvcc -arch=sm_86 -ptx src/rtx_gemm_ptx.cu -o build/pax_gemm.ptx
nvcc -arch=sm_86 src/rtx_gemm_ptx.cu -o build/pax_gemm.so --shared

# Futhark spec
futhark cuda src/pax_kernel.fut -o build/pax_kernel

# Fine-tune PAX-Coder
python3 export_training_data.py
python3 finetune_pax_coder.py
```
