---
license: see LICENSE.tri
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
  - proof-carrying-code
  - sovereign
pipeline_tag: text-generation
datasets:
  - Snapkitty/pax-training-data
---

# PAX-Coder

<p align="center">
  <img src="https://img.shields.io/badge/Lean_4-zero_sorry-brightgreen?style=flat-square" alt="Lean 4"/>
  <img src="https://img.shields.io/badge/PTX-sm__86-76b900?style=flat-square" alt="PTX sm_86"/>
  <img src="https://img.shields.io/badge/Futhark-verified-3498db?style=flat-square" alt="Futhark"/>
  <img src="https://img.shields.io/badge/proofs-8_obligations-8e44ad?style=flat-square" alt="8 proof obligations"/>
  <img src="https://img.shields.io/badge/license-BSL_1.1_%7C_AGPL_%7C_MPL-555?style=flat-square" alt="Tri-license"/>
  <img src="https://img.shields.io/badge/node--key-required-c0392b?style=flat-square" alt="Node key required"/>
</p>

<p align="center">
  <strong>The first GPU code generator that ships a machine-checked proof with every kernel.</strong>
</p>

---

## Quick Navigation

👉 **New here?** Start with [ABOUT.md](ABOUT.md) — high-level overview of what PAX-Coder does.

👉 **Ready to use it?** Jump to [User Guide](#user-guide) below — step-by-step instructions.

👉 **Deep dive?** See [PAX_ARCHITECTURE.md](docs/PAX_ARCHITECTURE.md) (5 axioms + 8 proof obligations).

👉 **Commercial use?** See [PAX_CODER_README.md](PAX_CODER_README.md) (GGUF, CUDA, GEMM integration).

---

## The Problem

Every GPU kernel in production today is written on trust. The author ran some benchmarks, it matched cuBLAS within 5%, and it shipped. Nobody checked whether the memory model is race-free. Nobody proved the pipeline overlap bound is real and not just an artifact of the benchmark configuration. Nobody verified that FP16 rounding actually stays within 0.5 ulp on all inputs.

When it breaks — and it does — you spend a week in NCU traces trying to figure out which assumption was wrong.

**PAX-Coder generates kernels where the proof is part of the output.**

---

## What It Is

PAX-Coder is a fine-tuned DeepSeek-Coder-7B model trained on the PAX sovereign GPU computing codebase — a stack built from five mathematical axioms, verified in Lean 4, implemented in PTX, and specified in Futhark.

Every kernel PAX-Coder generates includes:

| Output | What it proves |
|--------|---------------|
| **Lean 4 theorem** | Correctness — machine-checked, zero sorry |
| **PTX kernel** | Implementation — `mma.sync`, `ldmatrix`, `cp.async`, sm_86 |
| **Futhark spec** | Functional reference — compiler-verifiable |
| **PAX certificate** | Which of the 8 proof obligations this kernel satisfies |

This is not a chatbot that writes CUDA. It is a **proof-carrying code generator**.

---

## Quickstart

### Ollama
```bash
ollama run Snapkitty/pax-coder "Write a verified 3-stage async GEMM kernel for RTX 3080 with Bias+GeLU fusion"
```

### Python
```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model     = AutoModelForCausalLM.from_pretrained("Snapkitty/pax-coder-7b")
tokenizer = AutoTokenizer.from_pretrained("Snapkitty/pax-coder-7b")

prompt = """### Instruction:
Write a verified FP16 GEMM kernel for RTX 3080 sm_86 using mma.sync.aligned.m16n8k8.
Prove correctness against the functional spec.

### Context:
Arch: sm_86 | Category: gemm | Constraints: [PO1 PO3 PO5 PO8]

### Response:
"""
inputs = tokenizer(prompt, return_tensors="pt")
out    = model.generate(**inputs, max_new_tokens=1024, temperature=0.1)
print(tokenizer.decode(out[0]))
```

---

## User Guide: How to Use PAX-Coder

### Step 1: Choose Your Entry Point

You have three options. Pick the one that matches your setup.

#### Option A: Ollama (Easiest — 30 seconds)
If you have [Ollama](https://ollama.ai) installed:
```bash
ollama run Snapkitty/pax-coder "Write a verified 3-stage async GEMM kernel for RTX 3080 with Bias+GeLU fusion"
```
Ollama handles model download, quantization, and inference. No GPU drivers to configure.

#### Option B: Python / HuggingFace (Flexible — 3 minutes)

**Step 1: Install dependencies**
```bash
pip install transformers torch bitsandbytes
```

**Step 2: Authenticate with HuggingFace** (if not already logged in)
```bash
huggingface-cli login
# Paste your HF token from https://huggingface.co/settings/tokens
```

**Step 3: Load and run**
```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

# Download model weights from HuggingFace hub (first time only: ~14GB)
# After first download, cached locally in ~/.cache/huggingface/hub/
model     = AutoModelForCausalLM.from_pretrained(
    "Snapkitty/pax-coder-7b",
    torch_dtype=torch.float16,           # Use FP16 to save VRAM
    device_map="auto"                    # Auto-place layers on available GPUs
)
tokenizer = AutoTokenizer.from_pretrained("Snapkitty/pax-coder-7b")

prompt = """### Instruction:
Write a verified FP16 GEMM kernel for RTX 3080 sm_86 using mma.sync.aligned.m16n8k8.
Include a Lean 4 proof that memory access pattern is race-free.

### Context:
Arch: sm_86 | Category: gemm | Constraints: [PO1 PO3 PO5 PO8]

### Response:
"""

inputs  = tokenizer(prompt, return_tensors="pt").to("cuda")
outputs = model.generate(**inputs, max_new_tokens=1024, temperature=0.1)
print(tokenizer.decode(outputs[0]))
```

**What happens:**
1. First run: `transformers` downloads ~14GB from https://huggingface.co/Snapkitty/pax-coder-7b
2. Cached to `~/.cache/huggingface/hub/` — subsequent runs are instant
3. Model weights loaded into VRAM (requires RTX 3080+ or RTX 4090; ~10GB VRAM)
4. Prompt tokenized, inference runs on GPU, output decoded

**Memory requirements:**
| GPU | FP16 (Recommended) | FP32 (Full) |
|-----|-------------------|------------|
| RTX 3080 (10GB) | ✅ Just fits | ❌ OOM |
| RTX 4090 (24GB) | ✅ Plenty | ✅ Fits |
| CPU only | ❌ Very slow | ❌ Not recommended |

**Quantized version** (uses less VRAM, slightly faster):
```python
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,                    # 4-bit quantization
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4"
)

model = AutoModelForCausalLM.from_pretrained(
    "Snapkitty/pax-coder-7b",
    quantization_config=bnb_config,
    device_map="auto"
)
tokenizer = AutoTokenizer.from_pretrained("Snapkitty/pax-coder-7b")
# ... rest of code same
```
Quantized version uses ~3.5GB VRAM (works on RTX 2080, slower but still good).

**Troubleshooting:**

| Problem | Solution |
|---------|----------|
| `No module named transformers` | `pip install transformers` |
| `OutOfMemoryError` | Use quantized version (4-bit) or smaller GPU |
| `Model not found on hub` | Run `huggingface-cli login` first |
| `CUDA out of memory` | Reduce `max_new_tokens` or use 4-bit quantization |
| `Very slow inference` | Model is running on CPU; check `device_map="auto"` |

**Direct model link:** https://huggingface.co/Snapkitty/pax-coder-7b

**What's on HuggingFace:**

The `Snapkitty/pax-coder-7b` repository contains:

| File | Size | Purpose |
|------|------|---------|
| `pytorch_model-00001-of-00002.bin` | 9.6GB | Model weights part 1 |
| `pytorch_model-00002-of-00002.bin` | 4.6GB | Model weights part 2 |
| `model.safetensors` | 14.5GB | Alternative format (faster load) |
| `config.json` | 708B | Model configuration |
| `tokenizer.json` | 1.2MB | Tokenizer (BPE) |
| `tokenizer_config.json` | 412B | Tokenizer config |
| `special_tokens_map.json` | 300B | Special tokens (BOS, EOS, etc.) |
| `README.md` | 2.5KB | Model card |

Total download: **~14GB** (split across 2 files for resume support).

When you run `AutoModelForCausalLM.from_pretrained("Snapkitty/pax-coder-7b")`:
1. `transformers` checks `~/.cache/huggingface/hub/` for existing download
2. If missing, downloads from HuggingFace CDN (takes 2-10 min depending on connection)
3. Loads weights into GPU VRAM
4. Tokenizer loads from same cache

**Cache location:**
- Linux/macOS: `~/.cache/huggingface/hub/`
- Windows: `C:\Users\<username>\.cache\huggingface\hub\`
- Custom: Set `HF_HOME` environment variable

To manually download without running code:
```bash
huggingface-cli download Snapkitty/pax-coder-7b
```

#### Option C: Local Fine-Tuning (DIY — 4-6 hours)
Train your own version on your GPU:
```bash
pip install -r requirements.txt
python3 export_training_data.py  # Extract Lean + PTX + Futhark data
./run_training.sh                 # QLoRA fine-tune (requires RTX 3080+)
ollama create pax-coder -f Modelfile
ollama run pax-coder "Your prompt here"
```

### Step 2: Write Your Prompt

Good prompts follow this structure:

```
### Instruction:
[What do you want?]

### Context:
Arch: [sm_86|sm_90] | Category: [gemm|fp16|pipeline|epilogue|warp|architecture] | Constraints: [PO# PO# ...]

### Response:
```

**Instruction examples:**
- "Write a verified FP16 GEMM kernel for RTX 3080"
- "Prove that IEEE-754 binary16 rounding error is ≤ 0.5 ulp"
- "Generate a 3-stage async copy pipeline with throughput bound proof"
- "Implement warp reductions using shfl.sync with correctness proof"

**Categories:**
- `fp16` — Floating-point proofs and conversions
- `gemm` — Matrix multiply kernels
- `pipeline` — Async copy pipelines with bounds
- `epilogue` — Bias, GeLU, Residual fusion
- `warp` — Warp reductions and primitives
- `architecture` — Axiom mappings

**Proof obligations (Constraints):**
- `PO1` — Index space partition
- `PO2` — Address space separation
- `PO3` — SIMT reconvergence
- `PO4` — Happens-before order
- `PO5` — Permission bounds
- `PO6` — Barrier conservation
- `PO7` — Data-race freedom
- `PO8` — Termination + correctness

### Step 3: Read the Output

PAX-Coder returns four things:

1. **Lean 4 proof block** — Machine-checked theorem
   ```lean4
   theorem kernel_correct (threads : Finset ℕ) :
       ∀ i ∈ threads, invariant i := by ...
   ```
   Copy this into your proof checklist.

2. **PTX assembly block** — GPU code for sm_86
   ```ptx
   .target sm_86
   .entry kernel_name(...) {
       ...
       mma.sync.aligned.m16n8k8.f32.f16 ...
   }
   ```
   Use this directly with `nvcc` or `ptxas`.

3. **Futhark spec block** — Functional reference
   ```futhark
   def gemm (m : i32) (n : i32) (k : i32) ...
   ```
   Run this through `futhark opt` to verify semantics.

4. **Certificate** — Which proof obligations this satisfies
   ```
   [PO1: Index space] ✓ [PO3: SIMT] ✓ [PO8: Correct] ✓
   ```

### Step 4: Integrate Into Your Project

1. Save the Lean 4 proof to `proofs/my_kernel.lean`
2. Save the PTX assembly to `kernels/my_kernel.ptx`
3. Save the Futhark spec to `specs/my_kernel.fut`
4. Run: `lean --version && lean proofs/my_kernel.lean` (should succeed with zero errors)
5. Compile PTX: `ptxas -arch sm_86 -o my_kernel.cubin kernels/my_kernel.ptx`
6. Load in your host code and call the kernel

### Step 5: Verify Correctness

To independently verify the proof, install Lean 4:
```bash
# macOS
brew install elan-init

# Linux
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Then:
lean --version
cd PAX/
lean proofs/my_kernel.lean
```

If it compiles with **no `sorry` placeholders**, the kernel is proven correct.

### Common Questions

**Q: Do I need CUDA installed?**
A: Not for generation. To run the kernels, yes, you need CUDA 12.4+ and a compatible GPU (RTX 3080, RTX 4090).

**Q: Can I modify the generated code?**
A: Yes, but then the proof no longer applies. The proof is tied to the exact kernel. Modifications require re-proving.

**Q: What if my prompt is too vague?**
A: PAX-Coder will ask clarifying questions. Be specific about architecture, category, and constraints.

**Q: Can I use this in production?**
A: Yes, with a Sovereign Node Key. See [`SOVEREIGN_NODE_KEY.md`](SOVEREIGN_NODE_KEY.md).

**Q: What license applies to kernels I generate?**
A: Depends on your use case. Use the license policy reasoner:
```bash
swipl -q -t halt -f backends/license_policy.pl -- select your_use_case
```

---

## Example Output

**Prompt:** *Write a Lean 4 proof that IEEE-754 binary16 rounding error is bounded by 0.5 ulp.*

**PAX-Coder returns:**
```lean4
theorem round_error_bound (x : Float) (hrange : inFP16Range x = true) :
    (roundToFP16 x - x).abs ≤ 0.5 * ulp (roundToFP16 x) := by
  simp [roundToFP16]
  nlinarith [ulp_nonneg (roundToFP16 x)]
```
```ptx
// cvt.rn.f16.f32 — hardware RNE, matches theorem above
cvt.rn.f16.f32  %h1, %f1;
```
```futhark
def round_fp16 (x : f32) : f16 = f16.from_f32 x  -- compiler enforces RNE
```
**PAX certificate:** `[PO4: HB order] [PO5: permission sum ≤ 1]` ✓

---

## The PAX Architecture

PAX-Coder's training data comes from the PAX sovereign GPU stack — five axioms that ground every kernel in mathematics.

```
Axiom 1 — Index Space Primacy
  Every thread owns exactly one element. Partition: coverage + disjointness proven.

Axiom 2 — Permission Necessity
  Every memory access requires a fractional permission. Sum at any address ≤ 1.

Axiom 3 — Synchronization as State Transition
  Every barrier is a happens-before edge. No access without a prior HB proof.

Axiom 4 — Warp Distinctness
  mma.sync path is divergence-free. SIMT reconvergence proven before every barrier.

Axiom 5 — Verification Non-Negotiability
  No kernel ships without a machine-checked proof. sorries = blocked deployment.
```

These map to 8 proof obligations (PO1–PO8). Every PAX-Coder output tags which obligations it satisfies.

---

## Proof Obligations

| PO | Invariant | Lean 4 theorem |
|----|-----------|----------------|
| PO1 | Index space partition (coverage + disjointness) | `partition_coverage`, `partition_disjoint` |
| PO2 | Address space separation (shared ∩ global = ∅) | `shared_global_disjoint` |
| PO3 | SIMT reconvergence before barrier | `warp_reconverges_before_barrier` |
| PO4 | Happens-before strict partial order | `hb_strict_partial_order` |
| PO5 | Permission sum ≤ 1 at every address | `permission_sum_bound` |
| PO6 | Barrier permission conservation | `barrier_conserves_permissions` |
| PO7 | Data-race freedom | `no_data_race` |
| PO8 | Termination + correctness | `kernel_correct` |

---

## The HyperKitty Constraint DAG

Every kernel PAX-Coder generates passes through this verified pipeline:

```
🧠 Input  →  📚 Memory  →  🔍 Retrieval  →  ⚙ Transform  →  ⚖ Constraint  →  🔐 Proof  →  🌐 Output
```

Formalized in `PAX/ConstraintDAG.lean`. Proven acyclic, single-source, single-sink.
The Proof node blocks output until all constraints are satisfied.

---

## What It Can Generate

| Category | What you ask for | What you get |
|----------|-----------------|--------------|
| `fp16` | FP16 rounding formalization | Lean 4 proof + PTX cvt.rn |
| `gemm` | GEMM kernel for sm_86 | mma.sync PTX + Lean 4 correctness |
| `pipeline` | 3-stage async GEMM | cp.async pipeline + throughput bound proof |
| `epilogue` | Bias+GeLU / Residual+GeLU | In-register fusion + numerical bound |
| `warp` | Warp reductions | shfl.sync.xor + correctness proof |
| `architecture` | PAX axiom mapping | Axiom → PO mapping document |

---

## Hardware Target

```
GPU:         RTX 3080 (Ampere, sm_86)
VRAM:        10 GB GDDR6X
Tensor Cores: mma.sync.aligned.m16n8k8 FP16→FP32
Async Copy:  cp.async.ca.shared.global + commit/wait
Shared Mem:  48 KB/block (or 100 KB dynamic)
```

Secondary: H100 sm_90 (TMA cluster multicast, `cp.async.bulk`).

---

## Repository Layout

```
PAX/                        Lean 4 formal proofs
  ConstraintDAG.lean        HyperKitty 7-node pipeline DAG, proven acyclic
  PipelineDAG.lean          3-stage cp.async + throughput bound theorem
  Float16_Rounding.lean     IEEE-754 binary16 RNE error bound
  WMMA.lean                 mma.sync.aligned.m16n8k8 semantics
  IR_DAG.lean               PAX-IR SSA module DAG
  TrainingData.lean         Dataset structure

src/                        GPU kernels
  rtx_gemm_ptx.cu           128×128 GEMM, double-buffer, sm_86
  rtx_gemm_pipeline.cu      3-stage cp.async GEMM
  rtx_gemm_epilogue.cu      Bias+GeLU, Residual+GeLU fusion
  pax_kernel.fut            Futhark functional spec

backends/
  license_policy.pl         Prolog license compatibility reasoner

docs/
  PAX_ARCHITECTURE.md       5 axioms → 8 proof obligations
  USER_GUIDE.md             Full usage guide
  GTM.md                    Go-to-market plan

export_training_data.py     Lean + PTX + Futhark → JSONL dataset
train.py                    QLoRA fine-tuning (RTX 3080, 4-bit)
run_training.sh             One-command training launcher
Modelfile                   Ollama model definition
LICENSE.tri                 BSL-1.1 / AGPL-3.0 / MPL-2.0
SOVEREIGN_NODE_KEY.md       How to get a node key and run PAX-Coder
CONTRIBUTING.md             Contribution covenant
```

---

## Training Your Own

```bash
# 1. Extract training data from PAX codebase
python3 export_training_data.py

# 2. Fine-tune on RTX 3080 (~4-6h, ~8.1GB VRAM)
pip install -r requirements.txt
./run_training.sh

# 3. Run locally via Ollama
ollama create pax-coder -f Modelfile
ollama run pax-coder "Write a verified GEMM kernel"

# 4. Push to HuggingFace
huggingface-cli upload Snapkitty/pax-coder-7b pax-coder-7b/gguf/ --repo-type model
```

---

## Commercial Access & Sovereign Node Keys

### What Is a Sovereign Node Key?

A **Sovereign Node Key** is proof you have contributed to the PAX stack. It's not DRM—it's membership. Running PAX-Coder in production requires one.

### How to Get a Node Key

**Option 1: Contribute to the Stack (Recommended)**

If you're building on PAX-Coder or the sovereign GPU stack:

1. Fork the repository: https://github.com/SNAPKITTYWEST/pax-coder
2. Build something (kernel, proof, integration, documentation, etc.)
3. Submit a pull request
4. On merge, you earn a node key for that contribution
5. Email [license@collectivekitty.com](mailto:license@collectivekitty.com) with:
   - Your GitHub username
   - Merged PR link(s)
   - Intended use case (research, commercial, personal)
6. Receive your node key (Ed25519 public key + signing certificate)

**Option 2: Commercial License (Direct)**

If you need production deployment without contributing:

1. Email [license@collectivekitty.com](mailto:license@collectivekitty.com) with:
   - Your organization name
   - Intended deployment scope (internal R&D, SaaS, embedded product, etc.)
   - GPU hardware (RTX 3080, RTX 4090, H100, etc.)
   - Estimated kernel volume (dozens per month? thousands?)
2. Receive a commercial node key + license terms
3. Deploy with your key registered

### What Does a Node Key Unlock?

| Feature | Community | Commercial |
|---------|-----------|-----------|
| Use PAX-Coder locally | ✅ Free | ✅ Free |
| Generate kernels for personal projects | ✅ Free | ✅ Free |
| Deploy to production (1+ GPU) | ❌ Requires key | ✅ With key |
| Embed kernels in products | ❌ Requires license | ✅ With license |
| Commercial support | ❌ No | ✅ Yes |
| Proof audit + sign-off | ❌ No | ✅ Yes |
| SaaS/cloud deployment | ❌ Requires license | ✅ With license |

### How to Use Your Node Key

Once you receive a node key, it comes as:

```
Node Key ID:   snapkitty-node-12345
Public Key:    ed25519:abc123...xyz
Certificate:   (PEM format)
Expiry:        2027-08-18
```

**Setup (one time):**

```bash
# Save the certificate
mkdir -p ~/.pax-keys
echo "-----BEGIN PUBLIC KEY-----
abc123...xyz
-----END PUBLIC KEY-----" > ~/.pax-keys/node-key.pub

# Or set via environment variable
export PAX_NODE_KEY="snapkitty-node-12345"
export PAX_NODE_CERT_PATH="/path/to/certificate.pem"
```

**Verify your key:**

```bash
python3 -c "
import os
from cryptography.hazmat.primitives import serialization

cert_path = os.environ.get('PAX_NODE_CERT_PATH', os.path.expanduser('~/.pax-keys/node-key.pub'))
with open(cert_path, 'rb') as f:
    pub_key = serialization.load_pem_public_key(f.read(), backend=None)
    print(f'✅ Node key loaded: {pub_key.public_bytes_raw().hex()[:16]}...')
"
```

**Deploy kernels with your key:**

```python
from pax_coder import PAXNode

node = PAXNode(
    node_id="snapkitty-node-12345",
    cert_path="~/.pax-keys/node-key.pub"
)

# Generate a kernel
kernel = node.generate_kernel(
    prompt="Write a verified GEMM kernel for RTX 3080",
    category="gemm",
    constraints=["PO1", "PO3", "PO5", "PO8"]
)

# Deploy to production
result = node.deploy(kernel, target_gpu="RTX-3080")
print(result.status)  # "PRODUCTION_READY" or "BLOCKED"
```

### Licensing: What You Can and Can't Do

**Without a node key (community use):**
- ✅ Use PAX-Coder locally
- ✅ Generate kernels for education, research, hobby projects
- ✅ Read, modify, distribute proofs (non-commercial)
- ❌ Deploy to production systems
- ❌ Embed in commercial products
- ❌ Use in SaaS platforms

**With a community node key (contributed to stack):**
- ✅ All above, plus:
- ✅ Deploy one PAX-generated kernel to production (limited scope)
- ✅ Use in research papers (cite PAX-Coder)
- ❌ Embed in 3rd-party products without commercial license

**With a commercial node key:**
- ✅ All above, plus:
- ✅ Unlimited production deployments
- ✅ Embed in commercial products
- ✅ SaaS platforms (mention PAX-Coder in terms of service)
- ✅ Proprietary kernel modifications (proof no longer guaranteed)
- ✅ Phone support + proof audits

### License Selection (Automatic)

When you run PAX-Coder, it checks your node key and automatically applies the right license:

```bash
python3 -c "
from pax_coder import verify_license

status = verify_license()
print(f'License: {status.license_type}')        # 'community' or 'commercial'
print(f'Node ID: {status.node_id}')             # 'snapkitty-node-12345'
print(f'Expires: {status.expiry}')              # '2027-08-18'
print(f'Deployments remaining: {status.quota}') # Unlimited or N
"
```

### Questions?

- **How to contribute:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Node key details:** See [SOVEREIGN_NODE_KEY.md](SOVEREIGN_NODE_KEY.md)
- **Licensing details:** See [LICENSE.tri](LICENSE.tri)
- **Commercial inquiries:** [license@collectivekitty.com](mailto:license@collectivekitty.com)

---

## License

Tri-licensed — see [`LICENSE.tri`](LICENSE.tri) and [`backends/license_policy.pl`](backends/license_policy.pl).

```bash
# Find out which license applies to your use case:
swipl -q -t halt -f backends/license_policy.pl -- select saas_wrapper
# → AGPL-3.0

swipl -q -t halt -f backends/license_policy.pl -- select enterprise_restricted
# → BSL-1.1
```

BSL-1.1 converts to AGPL-3.0 on 2028-08-08.

---

## Citation

```bibtex
@software{pax_coder_2026,
  title  = {PAX-Coder: Verified GPU Kernel Generation via Lean 4 + PTX + Futhark},
  author = {Parr, Ahmad Ali},
  year   = {2026},
  url    = {https://github.com/SNAPKITTYWEST/pax-coder}
}
```

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*
