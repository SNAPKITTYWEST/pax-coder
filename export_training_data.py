#!/usr/bin/env python3
"""PAX Training Data Export Pipeline — Lean 4 + PTX + Futhark + Spec → JSONL"""

import json, re, hashlib, random, os
from pathlib import Path

ROOT = Path(__file__).parent

PROMPT_TEMPLATES = {
    "fp16": [
        "Write a Lean 4 formalization of IEEE-754 binary16 RNE with proven |round(x)-x| ≤ 0.5 ulp for FP16 GEMM on Ampere sm_86.",
        "Implement FP16 addition, multiplication, and FMA in Lean 4 with proven rounding error bounds matching __hadd, __hmul, __hfma.",
        "Formalize FP16→FP32 exact conversion for GEMM accumulation. Prove toRat(toFloat32(x)) = toRat(x) for all normal/subnormal FP16.",
    ],
    "gemm": [
        "Write a verified 128×128 GEMM kernel for RTX 3080 sm_86 using mma.sync.aligned.m16n8k8 FP16→FP32.",
        "Prove PTX mma.sync semantics match WMMA abstract machine. Register-level equivalence for FP16→FP32.",
        "Write a PAX-compliant GEMM with ldmatrix.x4, mma.sync, cp.async and Lean 4 PO1+PO3+PO5 proofs.",
    ],
    "pipeline": [
        "Define a 3-stage async cp.async pipeline in Lean 4 with proven throughput bound ≥ (1-1/stages)×min(bw_compute, bw_memory).",
        "Formalize cp.async.ca.shared.global with commit/wait_all. Prove pipeline preserves happens-before ordering across stages.",
        "Write a 3-stage async GEMM pipeline for RTX 3080 with proven overlap bound and Lean 4 PO4+PO6+PO7 certificates.",
    ],
    "epilogue": [
        "Define epilogue fusion algebra: Fuse(BiasAdd, GeLU) ≡ GeLU ∘ BiasAdd. Prove |GeLU_approx - GeLU_exact| ≤ 0.001.",
        "Formalize in-register Bias+GeLU and Residual+GeLU fusion. Prove register bound: regs(fuse) ≤ regs(f) + regs(g) + 8.",
        "Write an Ampere epilogue kernel fusing BiasAdd+GeLU in a single pass with Lean 4 PO8 correctness certificate.",
    ],
    "warp": [
        "Write warp-level reduction using shfl.sync.xor.b32. Prove correctness for dot product and softmax.",
        "Formalize SIMT divergence and reconvergence stack. Prove warp reconverges before barrier.",
    ],
    "architecture": [
        "Map PAX Architecture axioms to Lean 4 proof obligations: Axiom 1→PO1, Axiom 2→PO2, Axiom 3→PO3, Axiom 4→PO4, Axiom 5→PO5+PO8.",
        "Explain the HyperKitty Constraint DAG and its Lean 4 formalization in PAX/ConstraintDAG.lean.",
    ],
}

CONSTRAINTS = {
    "fp16":        ["PO4", "PO5"],
    "gemm":        ["PO1", "PO3", "PO5", "PO8"],
    "pipeline":    ["PO4", "PO6", "PO7"],
    "epilogue":    ["PO8"],
    "index_space": ["PO1", "PO2"],
    "warp":        ["PO3", "PO4"],
    "architecture":["PO8"],
}

SOURCE_FILES = [
    ("PAX/ConstraintDAG.lean",     "architecture", "all"),
    ("PAX/IR_DAG.lean",            "architecture", "all"),
    ("PAX/PipelineDAG.lean",       "pipeline",     "sm_86"),
    ("PAX/Float16_Rounding.lean",  "fp16",         "sm_86"),
    ("PAX/WMMA.lean",              "gemm",         "sm_86"),
    ("PAX/TrainingData.lean",      "architecture", "all"),
    ("src/rtx_gemm_ptx.cu",        "gemm",         "sm_86"),
    ("src/rtx_gemm_pipeline.cu",   "pipeline",     "sm_86"),
    ("src/rtx_gemm_epilogue.cu",   "epilogue",     "sm_86"),
    ("src/pax_kernel.fut",         "gemm",         "sm_86"),
    ("docs/PAX_ARCHITECTURE.md",   "architecture", "all"),
]

def extract_lean_theorems(content):
    pattern = r'(theorem|lemma)\s+(\w+)([^:=]*:[^:=]*):=\s*(by[^\n]*(?:\n  [^\n]*)*)'
    return re.findall(pattern, content, re.MULTILINE)

def extract_ptx_kernels(content):
    pattern = r'(__global__[^\{]*\{[^\}]*\})'
    return re.findall(pattern, content, re.DOTALL)

def make_id(s):
    return hashlib.md5(s.encode()).hexdigest()[:12]

def generate_examples():
    examples = []
    for rel_path, category, arch in SOURCE_FILES:
        path = ROOT / rel_path
        if not path.exists():
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        prompts = PROMPT_TEMPLATES.get(category, PROMPT_TEMPLATES["architecture"])

        if rel_path.endswith(".lean"):
            for kind, name, sig, proof in extract_lean_theorems(content):
                thm = f"{kind} {name}{sig}"
                for prompt in prompts[:2]:
                    examples.append({
                        "id": make_id(rel_path + name),
                        "instruction": prompt,
                        "input": f"Arch: {arch} | Category: {category} | Constraints: {' '.join(CONSTRAINTS.get(category, []))}",
                        "output": f"```lean4\n{thm} := {proof}\n```",
                        "metadata": {"file": rel_path, "arch": arch, "category": category,
                                     "constraints": CONSTRAINTS.get(category, [])},
                    })

        elif rel_path.endswith(".cu"):
            kernels = extract_ptx_kernels(content)
            for kernel in kernels:
                for prompt in prompts[:2]:
                    examples.append({
                        "id": make_id(rel_path + kernel[:40]),
                        "instruction": prompt,
                        "input": f"Arch: {arch} | Category: {category} | Constraints: {' '.join(CONSTRAINTS.get(category, []))}",
                        "output": f"```cuda\n{kernel[:2000]}\n```",
                        "metadata": {"file": rel_path, "arch": arch, "category": category,
                                     "constraints": CONSTRAINTS.get(category, [])},
                    })

        elif rel_path.endswith(".fut"):
            for prompt in prompts[:2]:
                examples.append({
                    "id": make_id(rel_path),
                    "instruction": prompt,
                    "input": f"Arch: {arch} | Category: {category} | Constraints: {' '.join(CONSTRAINTS.get(category, []))}",
                    "output": f"```futhark\n{content[:2000]}\n```",
                    "metadata": {"file": rel_path, "arch": arch, "category": category,
                                 "constraints": CONSTRAINTS.get(category, [])},
                })

        elif rel_path.endswith(".md"):
            sections = re.split(r'\n## ', content)
            for section in sections[:5]:
                title = section.split('\n')[0].strip("# ")
                for prompt in prompts[:1]:
                    examples.append({
                        "id": make_id(rel_path + title),
                        "instruction": prompt,
                        "input": f"Arch: {arch} | Category: {category}",
                        "output": f"```markdown\n{section[:1500]}\n```",
                        "metadata": {"file": rel_path, "arch": arch, "category": category,
                                     "constraints": []},
                    })

    # Dedup
    seen = set()
    unique = []
    for ex in examples:
        key = ex["id"]
        if key not in seen:
            seen.add(key)
            unique.append(ex)

    return unique

def split_and_write(examples):
    os.makedirs(ROOT / "build", exist_ok=True)
    random.seed(42)
    random.shuffle(examples)
    n = len(examples)
    splits = {
        "train": examples[:int(0.90 * n)],
        "val":   examples[int(0.90 * n):int(0.95 * n)],
        "test":  examples[int(0.95 * n):],
    }
    for name, data in splits.items():
        out = ROOT / "build" / f"pax_{name}.jsonl"
        with open(out, "w", encoding="utf-8") as f:
            for ex in data:
                f.write(json.dumps(ex) + "\n")
        print(f"  {name}: {len(data)} examples -> {out}")

if __name__ == "__main__":
    print("=== PAX Training Data Extraction ===")
    examples = generate_examples()
    print(f"Total unique examples: {len(examples)}")
    split_and_write(examples)
    print("Done. Run: python3 finetune_pax_coder.py")
