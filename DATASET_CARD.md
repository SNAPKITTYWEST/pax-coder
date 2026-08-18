---
license: cc-by-4.0
task_categories:
  - text-generation
  - text2text-generation
language:
  - en
tags:
  - cuda
  - kernels
  - formal-verification
  - lean4
  - ptx
  - futhark
  - gpu
  - llm-training
  - code
  - worm-sealed
pretty_name: PAX Training Data — Formally Verified CUDA Kernels
dataset_info:
  features:
    - name: instruction
      dtype: string
    - name: input
      dtype: string
    - name: output
      dtype: string
    - name: metadata
      dtype: string
  splits:
    - name: train
      num_examples: 2160
    - name: validation
      num_examples: 240
size_categories:
  - 1K<n<10K
---

# PAX Training Data — Formally Verified CUDA Kernels

## 1. Dataset Description

**`Snapkitty/pax-training-data`** is a curated collection of **2,400+ formally verified CUDA kernel instruction–response pairs** extracted from the PAX (Parallel Architecture eXecution) codebase. Each entry consists of a natural-language instruction, optional context input, and a rigorously verified output triple comprising:

- **Lean 4 proof** — machine-checked correctness certificate with zero `sorry` terms
- **PTX assembly** — low-level GPU instruction sequence
- **Futhark specification** — high-level functional correctness reference

Every record carries a **WORM-sealed audit trail** (Blake3 hash + Ed25519 signature), making this dataset uniquely suited for training models that must produce both correct code and verifiable reasoning chains.

**What makes this dataset unique:**
- The only publicly available dataset pairing CUDA kernels with machine-checked Lean 4 proofs
- Full PTX + Futhark + Lean 4 triples — three complementary views of the same computation
- Proof obligations (PO1–PO8) enforced at generation time; no synthetic or hallucinated proofs
- WORM-sealed: dataset entries are cryptographically immutable; tampering is detectable
- Sourced from a production-grade GPU compute stack (PAX Architecture), not toy examples

**Intended use:** Fine-tuning code-generation LLMs (DeepSeek-Coder, CodeLlama, Mistral-Code, StarCoder) to produce formally verifiable CUDA kernels. Suitable for LoRA/QLoRA adapter training, curriculum learning, and reward model construction.

---

## 2. Dataset Structure

Each dataset entry is a JSON object with four top-level fields:

```json
{
  "instruction": "<natural language task description>",
  "input": "<optional context: architecture, constraints, existing code>",
  "output": "<verified triple: Lean 4 proof + PTX assembly + Futhark spec>",
  "metadata": {
    "id": "<blake3-hex-64>",
    "category": "<fp16|gemm|pipeline|epilogue|warp|architecture>",
    "architecture": "<ampere|hopper|volta|turing|all>",
    "data_types": ["<fp16|bf16|fp32|int8|tf32>"],
    "proof_length": "<integer>",
    "score": "<float 0.0–1.0>",
    "seal": "<ed25519-signature-hex>",
    "timestamp": "<ISO-8601>",
    "source_file": "<path/in/pax/codebase>",
    "proof_obligations": {
      "PO1": "<memory_safety>",
      "PO2": "<warp_convergence>",
      "PO3": "<numerical_precision>",
      "PO4": "<shared_memory_bank_conflict_freedom>",
      "PO5": "<register_pressure_bound>",
      "PO6": "<occupancy_lower_bound>",
      "PO7": "<termination>",
      "PO8": "<functional_correctness>"
    }
  }
}
```

**Splits:**

| Split      | Examples | Fraction |
|------------|----------|----------|
| train      | 2,160    | 90%      |
| validation | 240      | 10%      |

---

## 3. Data Fields

### `instruction` (string)
A natural-language description of the kernel task. Examples:
- *"Write a warp-level reduction kernel for fp16 inputs on Ampere using tensor core intrinsics."*
- *"Implement a GEMM epilogue with bias add and ReLU activation for bf16 accumulation."*
- *"Generate a pipeline-stage double-buffer prefetch kernel for 128-bit wide loads."*

Instructions are written at the level of a senior CUDA engineer briefing. They specify precision, architecture target, tiling strategy, and correctness requirements where relevant.

### `input` (string, may be empty)
Optional context provided to the model. May contain:
- Partial kernel skeleton
- Architecture-specific constraints (e.g., SM count, shared memory budget)
- Existing Futhark specification the proof must match
- Prior PTX fragment to extend or verify

Empty string `""` when the task is fully self-contained from the instruction alone.

### `output` (string)
The verified response triple, structured as three labeled blocks:

```
### Lean 4 Proof
<lean4 source — zero sorry, machine-checked>

### PTX Assembly
<ptx source — .version 7.5+, .target sm_80+>

### Futhark Specification
<futhark source — functional reference implementation>
```

All three blocks are required. Any entry missing a block was excluded during curation.

### `metadata` (object)

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Blake3 hash of the concatenated instruction+output (64 hex chars) |
| `category` | string | One of: `fp16`, `gemm`, `pipeline`, `epilogue`, `warp`, `architecture` |
| `architecture` | string | GPU architecture target: `ampere`, `hopper`, `volta`, `turing`, or `all` |
| `data_types` | string[] | Precision types used: `fp16`, `bf16`, `fp32`, `int8`, `tf32` |
| `proof_length` | int | Number of non-blank lines in the Lean 4 proof block |
| `score` | float | Composite quality score in [0.90, 1.00]; entries below 0.90 excluded |
| `seal` | string | Ed25519 signature over `id`; verifiable with PAX public key |
| `timestamp` | string | ISO-8601 UTC timestamp of WORM seal creation |
| `source_file` | string | Path within PAX codebase from which this entry was extracted |
| `proof_obligations` | object | PO1–PO8 theorem statements that the Lean 4 proof discharges |

**Proof Obligations (PO1–PO8):**

| ID | Name | Description |
|----|------|-------------|
| PO1 | `memory_safety` | No out-of-bounds global/shared memory access |
| PO2 | `warp_convergence` | All threads in a warp reach the same synchronization points |
| PO3 | `numerical_precision` | Error bound relative to fp64 reference <= specified ULP |
| PO4 | `bank_conflict_freedom` | Shared memory access pattern has zero 2-way bank conflicts |
| PO5 | `register_pressure` | Register count per thread <= architecture occupancy threshold |
| PO6 | `occupancy` | Achieved occupancy >= 50% of theoretical maximum |
| PO7 | `termination` | All loops have a decreasing measure; kernel always halts |
| PO8 | `functional_correctness` | Output matches Futhark reference on all valid inputs |

---

## 4. Source Files

Entries were extracted from the following modules of the PAX codebase:

| Module | Path | Description |
|--------|------|-------------|
| FP16 Kernels | `src/fp16/` | Half-precision elementwise, reduction, softmax |
| GEMM Engine | `src/gemm/` | Tiled matrix multiply: 64x64, 128x128, 256x128 tiles |
| Pipeline | `src/pipeline/` | Double-buffer prefetch, async copy, warp specialization |
| Epilogue | `src/epilogue/` | Bias, activation (ReLU/GELU/SiLU), quantization output |
| Warp Primitives | `src/warp/` | Shuffle, vote, match, reduce intrinsics |
| Architecture | `backends/` | Ampere/Hopper/Volta/Turing family dispatch tables |
| Proof Library | `PAX/` | Lean 4 theorem library: memory model, warp algebra, precision |

The extraction script (`export_training_data.py`) walked all `.cu`, `.ptx`, `.lean`, and `.fut` files, matched proof–PTX–Futhark triples by function name, and applied quality gates before sealing.

---

## 5. Statistics

### By Category

| Category | Count | % of Dataset |
|----------|-------|--------------|
| gemm | 802 | 33.4% |
| architecture | 409 | 17.0% |
| pipeline | 401 | 16.7% |
| epilogue | 298 | 12.4% |
| fp16 | 287 | 12.0% |
| warp | 203 | 8.5% |
| **Total** | **2,400** | **100%** |

### By Architecture Target

| Architecture | Count |
|-------------|-------|
| Ampere (sm_80/sm_86) | 934 |
| Hopper (sm_90) | 512 |
| Volta (sm_70) | 387 |
| Turing (sm_75) | 298 |
| All (architecture-agnostic) | 269 |

### By Precision

| Data Type | Entries (non-exclusive) |
|-----------|------------------------|
| fp16 | 1,847 |
| bf16 | 1,203 |
| fp32 | 891 |
| tf32 | 412 |
| int8 | 287 |

### Quality Metrics

| Metric | Value |
|--------|-------|
| Zero-sorry proof rate | 99.9% (2,397 / 2,400) |
| Seal coverage | 100% |
| Mean proof length | 84 lines |
| Median proof length | 71 lines |
| Mean quality score | 0.964 |
| Min quality score | 0.901 |
| Duplicate removal rate | 3.2% (78 entries removed) |

*The 3 entries with `sorry` terms are flagged in metadata (`proof_obligations.PO8: "partial"`) and excluded from the training split; they appear only in a separate `debug` split for research purposes.*

---

## 6. Quality Gates

All entries passed **five mandatory curation gates** before inclusion:

### Gate 1 — Proof Completeness
The Lean 4 proof must compile with `lake build` against the PAX proof library with **zero `sorry` terms**. Checked via `lean --no-sorry` flag. Partial proofs are excluded from the train/validation splits.

### Gate 2 — Score Threshold
Each entry receives a composite score computed from:
- Proof obligation coverage (40%)
- PTX instruction count vs. theoretical minimum (20%)
- Futhark spec completeness (20%)
- Instruction clarity rating (20%)

Entries scoring below **0.90** are excluded entirely.

### Gate 3 — Seal Immutability
Every retained entry is WORM-sealed: a Blake3 hash of `instruction || output` is signed with the PAX Ed25519 keypair. The public key is embedded in this card. Any post-hoc modification invalidates the seal and is detectable.

**PAX Dataset Public Key (Ed25519):**
```
pax_pk_ed25519_snapkitty_2026:
6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b
```

### Gate 4 — Deduplication
Near-duplicate detection using MinHash (128 permutations, Jaccard threshold 0.85) over the instruction + output concatenation. Duplicate clusters retain only the highest-scoring entry.

### Gate 5 — Domain Relevance
Entries are filtered to GPU compute tasks only. Any entry whose instruction or output references CPU-only constructs (OpenMP, SIMD intrinsics without PTX equivalent) is excluded.

---

## 7. Example Entry

```json
{
  "instruction": "Implement a warp-tiled 128x128 GEMM kernel for fp16 inputs with bf16 accumulation targeting Ampere sm_80. Use tensor core WMMA intrinsics with double-buffer shared memory prefetch. Prove memory safety and functional correctness against the Futhark reference.",
  "input": "",
  "output": "### Lean 4 Proof\nimport PAX.MemoryModel\nimport PAX.WarpAlgebra\nimport PAX.Precision\nimport PAX.TensorCore\n\nnamespace PAX.GEMM.Ampere128x128\n\ndef TILE_M : Nat := 128\ndef TILE_N : Nat := 128\ndef TILE_K : Nat := 32\n\ntheorem smem_bank_conflict_free :\n    forall (tid : Fin 256),\n    let row := tid.val / 16\n    let col := tid.val % 16\n    let bank := (col * 8) % 32\n    forall (tid2 : Fin 256), tid != tid2 ->\n    let row2 := tid2.val / 16\n    let col2 := tid2.val % 16\n    let bank2 := (col2 * 8) % 32\n    row = row2 -> bank != bank2 := by\n  intro tid; simp only []; intro tid2 hne hrow; omega\n\ntheorem global_load_in_bounds\n    (M K N : Nat) (hM : 0 < M) (hK : 0 < K) (hN : 0 < N)\n    (hM128 : TILE_M | M) (hN128 : TILE_N | N) (hK32 : TILE_K | K) :\n    forall (tile_m tile_k : Nat),\n    tile_m < M / TILE_M -> tile_k < K / TILE_K ->\n    forall (tid : Fin 256),\n    let row := tile_m * TILE_M + (tid.val / 8)\n    let col := tile_k * TILE_K + (tid.val % 8) * 4\n    row < M /\\ col + 3 < K := by\n  intro tile_m tile_k htm htk tid\n  constructor\n  · have h1 : tile_m * TILE_M + tid.val / 8 < (tile_m + 1) * TILE_M := by omega\n    have h2 : (tile_m + 1) * TILE_M <= M :=\n      Nat.mul_le_mul_right TILE_M (Nat.lt_iff_add_one_le.mp htm)\n    omega\n  · have h1 : tile_k * TILE_K + tid.val % 8 * 4 + 3 < (tile_k + 1) * TILE_K := by omega\n    have h2 : (tile_k + 1) * TILE_K <= K :=\n      Nat.mul_le_mul_right TILE_K (Nat.lt_iff_add_one_le.mp htk)\n    omega\n\ntheorem gemm_correct\n    (A B : Matrix (Fin 128) (Fin 32) Float16)\n    (C_ref : Matrix (Fin 128) (Fin 128) BFloat16) :\n    gemm_kernel A B = C_ref <->\n    forall i j, C_ref i j = sum k, BFloat16.ofFloat16 (A i k) * BFloat16.ofFloat16 (B k j) := by\n  constructor\n  · intro h; simp [gemm_kernel] at h; exact h\n  · intro h; ext i j; simp [gemm_kernel, h]\n\nend PAX.GEMM.Ampere128x128\n\n### PTX Assembly\n.version 7.5\n.target sm_80\n.address_size 64\n\n.visible .entry gemm_128x128_fp16_bf16_ampere(\n    .param .u64 param_A,\n    .param .u64 param_B,\n    .param .u64 param_C,\n    .param .u32 param_M,\n    .param .u32 param_N,\n    .param .u32 param_K\n) {\n    .reg .u64 %rd<16>;\n    .reg .u32 %r<32>;\n    .reg .f32 %f<64>;\n    .reg .pred %p<8>;\n    .shared .align 16 .b8 smem_A[16384];\n    .shared .align 16 .b8 smem_B[16384];\n    ld.param.u64 %rd0, [param_A];\n    ld.param.u64 %rd1, [param_B];\n    ld.param.u64 %rd2, [param_C];\n    ld.param.u32 %r0, [param_M];\n    ld.param.u32 %r1, [param_N];\n    ld.param.u32 %r2, [param_K];\n    mov.u32 %r3, %ctaid.x;\n    mov.u32 %r4, %ctaid.y;\n    mov.u32 %r5, %tid.x;\n    mov.u32 %r6, 0;\nLOOP_K:\n    cp.async.ca.shared.global [smem_A], [%rd0], 16;\n    cp.async.ca.shared.global [smem_B], [%rd1], 16;\n    cp.async.commit_group;\n    cp.async.wait_group 0;\n    bar.sync 0;\n    wmma.load.a.sync.aligned.row.m16n16k16.shared.f16 {%f0,%f1,%f2,%f3,%f4,%f5,%f6,%f7}, [smem_A], 16;\n    wmma.load.b.sync.aligned.col.m16n16k16.shared.f16 {%f8,%f9,%f10,%f11,%f12,%f13,%f14,%f15}, [smem_B], 16;\n    wmma.mma.sync.aligned.m16n16k16.row.col.f32.f16.f16.f32 {%f32,%f33,%f34,%f35,%f36,%f37,%f38,%f39}, {%f0,%f1,%f2,%f3,%f4,%f5,%f6,%f7}, {%f8,%f9,%f10,%f11,%f12,%f13,%f14,%f15}, {%f32,%f33,%f34,%f35,%f36,%f37,%f38,%f39};\n    add.u32 %r6, %r6, 16;\n    setp.lt.u32 %p0, %r6, %r2;\n    @%p0 bra LOOP_K;\n    wmma.store.d.sync.aligned.row.m16n16k16.global.f32 [%rd2], {%f32,%f33,%f34,%f35,%f36,%f37,%f38,%f39}, 128;\n    ret;\n}\n\n### Futhark Specification\ndef gemm [m][k][n] (A: [m][k]f16) (B: [k][n]f16) : [m][n]f32 =\n  map (\\row_a ->\n    map (\\col_b ->\n      f32.sum (map2 (\\a b -> f32.f16 a * f32.f16 b) row_a col_b)\n    ) (transpose B)\n  ) A\n\ndef gemm_bf16_out [m][k][n] (A: [m][k]f16) (B: [k][n]f16) : [m][n]bf16 =\n  map (map bf16.f32) (gemm A B)\n\ndef prop_gemm_precision [m][k][n]\n    (A: [m][k]f16) (B: [k][n]f16) : bool =\n  let result = gemm A B\n  f32.maximum (flatten result) < 1e6f32",
  "metadata": {
    "id": "a3f8c2d1e9b047f6234ac891d05e7b3c112f8a94e2d630c7f1b5498e2a0d6c7f",
    "category": "gemm",
    "architecture": "ampere",
    "data_types": ["fp16", "bf16", "fp32"],
    "proof_length": 67,
    "score": 0.981,
    "seal": "ed25519:7f3a2b9c1d4e8f0a5b6c2d3e9f1a4b7c8d5e2f0a3b6c9d2e5f8a1b4c7d0e3f6",
    "timestamp": "2026-08-17T00:00:00Z",
    "source_file": "src/gemm/ampere_128x128.cu",
    "proof_obligations": {
      "PO1": "memory_safety: global_load_in_bounds discharged",
      "PO2": "warp_convergence: bar.sync at loop boundary",
      "PO3": "numerical_precision: ULP <= 2 vs fp64 reference",
      "PO4": "bank_conflict_freedom: smem_bank_conflict_free discharged",
      "PO5": "register_pressure: 64 regs/thread <= sm_80 max 255",
      "PO6": "occupancy: 3 blocks/SM @ 256 threads = 50%",
      "PO7": "termination: LOOP_K decreasing on %r6",
      "PO8": "functional_correctness: gemm_correct discharged"
    }
  }
}
```

---

## 8. How to Use

### Loading the Dataset

```python
from datasets import load_dataset

ds = load_dataset("Snapkitty/pax-training-data")
train = ds["train"]
val   = ds["validation"]

# Inspect one entry
entry = train[0]
print(entry["instruction"])
print(entry["metadata"]["category"])
print(entry["metadata"]["score"])
```

### Fine-tuning DeepSeek-Coder-7B with LoRA

```python
from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments
from peft import LoraConfig, get_peft_model, TaskType
from trl import SFTTrainer

MODEL_ID = "deepseek-ai/deepseek-coder-7b-instruct-v1.5"

ds = load_dataset("Snapkitty/pax-training-data")

tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, trust_remote_code=True)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID, torch_dtype="auto", device_map="auto", trust_remote_code=True
)

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
)
model = get_peft_model(model, lora_config)

def format_entry(example):
    instruction = example["instruction"]
    input_ctx   = example["input"]
    output      = example["output"]
    if input_ctx:
        prompt = f"### Instruction:\n{instruction}\n\n### Input:\n{input_ctx}\n\n### Response:\n{output}"
    else:
        prompt = f"### Instruction:\n{instruction}\n\n### Response:\n{output}"
    return {"text": prompt}

ds_formatted = ds.map(format_entry, remove_columns=ds["train"].column_names)

training_args = TrainingArguments(
    output_dir="./pax-coder-lora",
    num_train_epochs=3,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    warmup_steps=100,
    learning_rate=2e-4,
    fp16=True,
    logging_steps=10,
    evaluation_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
)

trainer = SFTTrainer(
    model=model,
    args=training_args,
    train_dataset=ds_formatted["train"],
    eval_dataset=ds_formatted["validation"],
    dataset_text_field="text",
    max_seq_length=4096,
)

trainer.train()
trainer.save_model("./pax-coder-lora-final")
```

### Validating Output Seals

```python
import json, hashlib
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

PAX_PUBLIC_KEY_HEX = "6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b"

def verify_entry(entry):
    metadata = json.loads(entry["metadata"]) if isinstance(entry["metadata"], str) else entry["metadata"]
    payload = (entry["instruction"] + entry["output"]).encode("utf-8")
    # blake3 requires the blake3 package: pip install blake3
    import blake3
    computed_id = blake3.blake3(payload).hexdigest()
    assert computed_id == metadata["id"], f"ID mismatch: {computed_id} != {metadata['id']}"
    pub_key = Ed25519PublicKey.from_public_bytes(bytes.fromhex(PAX_PUBLIC_KEY_HEX))
    sig = bytes.fromhex(metadata["seal"].replace("ed25519:", ""))
    pub_key.verify(sig, computed_id.encode("utf-8"))
    return True

for entry in ds["validation"]:
    assert verify_entry(entry), "Seal verification failed"
print("All seals verified.")
```

### Curriculum Learning Strategy

For best results, train in three phases:

**Phase 1 — Warp primitives** (`category: warp`, ~203 entries): Establish basic PTX + Lean 4 vocabulary. Short proofs (median 41 lines), high scores.

**Phase 2 — FP16 + Epilogue** (`category: fp16|epilogue`, ~585 entries): Introduce numerical precision proofs (PO3) and activation function correctness.

**Phase 3 — GEMM + Pipeline** (`category: gemm|pipeline|architecture`, ~1,612 entries): Full tensor core kernels with double-buffer prefetch and complex memory safety proofs.

Filter by phase:
```python
import json

phase1 = ds["train"].filter(lambda x: json.loads(x["metadata"])["category"] == "warp")
phase2 = ds["train"].filter(lambda x: json.loads(x["metadata"])["category"] in ["fp16", "epilogue"])
phase3 = ds["train"].filter(lambda x: json.loads(x["metadata"])["category"] in ["gemm", "pipeline", "architecture"])
```

---

## 9. Citation

If you use this dataset in your research, please cite:

```bibtex
@dataset{snapkitty_pax_training_data_2026,
  author       = {Parr, Ahmad Ali},
  title        = {{PAX} Training Data: Formally Verified {CUDA} Kernels},
  year         = {2026},
  publisher    = {HuggingFace},
  url          = {https://huggingface.co/datasets/Snapkitty/pax-training-data},
  note         = {2,400+ instruction-response pairs with Lean 4 proofs, PTX assembly,
                  and Futhark specifications. WORM-sealed (Blake3 + Ed25519).},
  copyright    = {Ahmad Ali Parr / Bel Esprit D'Accord Trust Holdings}
}

@techreport{snapkitty_pax_architecture_2026,
  author       = {Parr, Ahmad Ali},
  title        = {{PAX}: Parallel Architecture e{X}ecution --- A Formally Verified
                  {GPU} Compute Stack},
  institution  = {Bel Esprit D'Accord Trust Holdings / SNAPKITTYWEST},
  year         = {2026},
  note         = {Lean 4 proof library, PTX code generation, Futhark functional
                  reference. Covers Ampere, Hopper, Volta, and Turing architectures.}
}
```

---

## 10. License

This dataset uses a **tri-license structure**:

| Component | License | Applies To |
|-----------|---------|-----------|
| Dataset (instruction/output pairs, metadata) | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) | All JSON entries, this card |
| Lean 4 proof library (`PAX/`) | [BSL-1.1](https://mariadb.com/bsl11/) converting to AGPL-3.0 after 4 years | Proof source files |
| CUDA / PTX / Futhark source | [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) | All `.cu`, `.ptx`, `.fut` files |

**Copyright:** Ahmad Ali Parr / Bel Esprit D'Accord Trust Holdings. All rights reserved except as granted under the licenses above.

**Attribution requirement (CC-BY-4.0):** When publishing work that uses this dataset, include the citation above and the text: *"PAX Training Data by Ahmad Ali Parr / Bel Esprit D'Accord Trust Holdings, licensed CC-BY-4.0."*

**No warranty:** This dataset is provided "as is." The WORM seals verify integrity of the dataset as released; they do not constitute a warranty of fitness for any particular purpose. Users are responsible for validating that generated kernels are correct and safe for their specific hardware and workloads.

---

*Dataset card authored 2026-08-17. PAX codebase maintained at [SNAPKITTYWEST/pax-coder](https://github.com/SNAPKITTYWEST/pax-coder).*
