# PAX-Coder Demo

Verified GPU kernel generation demonstration with realistic Lean 4 proofs, PTX kernels, and Futhark specs.

## Quick Start

```bash
# Mock mode (no model download required)
python3 demo.py

# Non-interactive mode (useful for CI/scripting)
python3 demo.py --no-pause

# Use actual Ollama model (if running locally)
python3 demo.py --live

# Target H100 (Hopper, sm_90) instead of RTX 3080 (Ampere, sm_86)
python3 demo.py --arch sm_90
```

## What It Shows

The demo demonstrates PAX-Coder end-to-end with 5 kernel categories:

| Category | What's Proven | Example Output |
|----------|---------------|-----------------|
| **FP16** | IEEE-754 binary16 rounding error bound | Lean 4 proof + PTX `cvt.rn.f16.f32` |
| **GEMM** | 128×128 matrix multiply correctness | `mma.sync` kernel + index partition proof |
| **Pipeline** | 3-stage async GEMM throughput bound | `cp.async` + happens-before proof |
| **Epilogue** | Bias+GeLU fusion numerical stability | In-register computation proof |
| **Warp** | Tree-reduction warp shuffle correctness | `shfl.sync.xor` + divergence-free guarantee |

For each category, you see:
- **Prompt**: What was asked
- **Lean 4 Proof**: Machine-checked correctness (zero sorry)
- **PTX Kernel**: Hand-rolled `mma.sync`, `ldmatrix`, `cp.async` code
- **Futhark Spec**: Functional reference implementation
- **PAX Certificate**: Which proof obligations (PO1–PO8) are satisfied

## Command-Line Options

```
--live              Use actual Ollama instance (localhost:11434)
--arch {sm_86,sm_90}
                    Target GPU (default: sm_86 / RTX 3080)
--no-rich           Disable colored terminal output (plain text)
--speed SPEED       Streaming animation speed multiplier (default: 1.0)
--no-pause          Skip pauses between demos (for CI/automation)
--help              Show this help message
```

## Requirements

### Minimal (Mock Mode)
- Python 3.10+
- Standard library only

### Optional (Live Mode + Rich Output)
- Ollama running at `localhost:11434` with `Snapkitty/pax-coder-7b` model
- `rich` library: `pip install rich`

```bash
# Install rich for prettier output
pip install rich

# Run Ollama locally for --live mode
ollama run Snapkitty/pax-coder-7b
```

## Example Output

Running `python3 demo.py --no-pause` will generate ~680 lines showing:

1. **PAX-Coder banner** with legal information
2. **5 kernel demos** (fp16, gemm, pipeline, epilogue, warp)
3. **VRAM usage breakdown** (~8.1 GB on RTX 3080)
4. **Call-to-action** for Sovereign Node Key
5. **Links** to GitHub, HuggingFace, documentation

### Sample Output Structure

```
================================================================================
DEMO 1/5: FP16
================================================================================

📋 PROMPT:
Prove that IEEE-754 binary16 rounding error is bounded by 0.5 ulp...

🔍 LEAN 4 PROOF:
theorem fp16_rounding_bound (x : Float)...
  nlinarith [ulp_nonneg (roundToFP16 x), ...]

⚙️  PTX KERNEL:
// IEEE-754 binary16 RNE conversion
.target sm_86
cvt.rn.f16.f32 h_out, f_in;

🌐 FUTHARK SPEC:
def round_fp16 (x : f32) : f16 = f16.from_f32 x

✓ PAX CERTIFICATE: [PO4 | PO5 | PO7]
```

## Proof Obligations (PO1–PO8)

| PO | Invariant | Example |
|----|-----------|---------|
| PO1 | Index space partition | Coverage + disjointness proven |
| PO2 | Address space separation | `shared ∩ global = ∅` |
| PO3 | SIMT reconvergence | Before every barrier |
| PO4 | Happens-before SPO | Strict partial order proven |
| PO5 | Permission sum ≤ 1 | Fractional permissions at every address |
| PO6 | Barrier permission conservation | Preserved across `__syncthreads` |
| PO7 | Data-race freedom | No concurrent writes to same address |
| PO8 | Termination + correctness | Kernel always terminates correctly |

Each PAX-Coder output lists which POs are satisfied by that kernel.

## Architecture Targets

### Ampere (sm_86) — RTX 3080 — Default
- `mma.sync.aligned.m16n8k8.f32` (FP32 accumulate)
- `mma.sync.aligned.m16n8k16.f32` (FP16 input)
- `ldmatrix.sync.aligned.m8n8.x4.b16`
- `cp.async.ca.shared.global` + `cp.async.wait_group`
- Shared memory: 48 KB (or 100 KB dynamic)

### Hopper (sm_90) — H100 — `--arch sm_90`
- TMA (Tensor Memory Accelerator) multicast
- `cp.async.bulk` (pipelined async copy)
- Cluster sync primitives
- Thread blocks per cluster

## Running on Different GPUs

```bash
# Default: RTX 3080 Ampere (sm_86)
python3 demo.py

# H100 Hopper (sm_90)
python3 demo.py --arch sm_90

# With actual model (requires Ollama)
ollama run Snapkitty/pax-coder-7b "Write verified GEMM for sm_90"
python3 demo.py --live --arch sm_90
```

## For CI/Automation

```bash
# Non-interactive, plain text, full output to file
python3 demo.py --no-pause --no-rich > pax_demo.log 2>&1

# Check all POs are satisfied
python3 demo.py --no-pause 2>&1 | grep "PAX CERTIFICATE"
```

## Troubleshooting

### `ModuleNotFoundError: No module named 'rich'`
Rich is optional. Run `pip install rich` or use `--no-rich` for plain output.

### `ModuleNotFoundError: No module named 'requests'`
Only needed for `--live` mode. Install with `pip install requests`.

### Ollama connection refused
Ensure Ollama is running: `ollama serve`
Then in another terminal: `ollama run Snapkitty/pax-coder-7b`

### Unicode/Encoding errors on Windows
The script handles UTF-8 automatically. If issues persist, try `--no-rich`.

---

## Learn More

- **GitHub**: https://github.com/SNAPKITTYWEST/pax-coder
- **HuggingFace**: https://huggingface.co/Snapkitty/pax-coder-7b
- **Architecture Doc**: https://github.com/SNAPKITTYWEST/pax-coder/tree/main/PAX
- **User Guide**: https://github.com/SNAPKITTYWEST/pax-coder/tree/main/docs

## License

PAX-Coder is tri-licensed:
- **BSL-1.1** (Business Source License 1.1) — restricts until 2028-08-08
- **AGPL-3.0** (GNU Affero General Public License 3.0) — starting 2028-08-08
- **MPL-2.0** (Mozilla Public License 2.0) — alternative terms

Copyright: Ahmad Ali Parr, Bel Esprit D'Accord Irrevocable Trust

---

*Evidence or Silence — 2026*
