# PAX-Coder Demo Installation & Quick Start

## Installation

No installation required! The demo works out of the box with Python 3.10+.

```bash
cd C:/Users/jessi/Desktop/pax-coder
python3 demo/demo.py
```

## Quick Start

### 1. Default Demo (Mock Mode, RTX 3080)
```bash
python3 demo/demo.py
```
Shows all 5 kernel categories with interactive pauses between demos.

### 2. Non-Interactive (Perfect for CI/Scripting)
```bash
python3 demo/demo.py --no-pause
```
Runs all 5 demos back-to-back without pausing.

### 3. Target H100 (Hopper, sm_90)
```bash
python3 demo/demo.py --arch sm_90 --no-pause
```
Same 5 demos but with sm_90 target instead of sm_86.

### 4. Plain Text (No Colored Output)
```bash
python3 demo/demo.py --no-rich --no-pause
```
Works on minimal terminals without color support.

## Optional Dependencies

Install `rich` for prettier terminal output:
```bash
pip install rich
```

For live Ollama mode, install `requests`:
```bash
pip install requests
```

Then run Ollama in one terminal:
```bash
ollama serve
ollama run Snapkitty/pax-coder-7b  # Download model
```

And query in another:
```bash
python3 demo/demo.py --live
```

## What Each Flag Does

| Flag | Purpose | Example |
|------|---------|---------|
| `--help` | Show all options | `python3 demo.py --help` |
| `--no-pause` | Skip pauses (CI mode) | `python3 demo.py --no-pause` |
| `--no-rich` | Plain text only | `python3 demo.py --no-rich` |
| `--arch sm_90` | Target H100 (default: sm_86) | `python3 demo.py --arch sm_90` |
| `--live` | Use Ollama model | `python3 demo.py --live` |
| `--speed 2.0` | 2x faster animation | `python3 demo.py --speed 2.0` |

## Expected Output

The demo produces ~680 lines showing:

1. **Banner** (14 lines) — PAX-Coder branding + copyright
2. **5 Demos** (~130 lines each):
   - Prompt
   - Lean 4 proof
   - PTX kernel
   - Futhark spec
   - PAX certificate
3. **VRAM Stats** (~10 lines) — RTX 3080 breakdown
4. **CTA** (~10 lines) — Sovereign Node Key link
5. **Footer** (~5 lines) — GitHub/HuggingFace links

Total: 680+ lines when run with `--no-pause`.

## Output Format

Each demo shows:

```
================================================================================
DEMO 1/5: FP16
================================================================================

📋 PROMPT:
  [User's request for verified kernel]

🔍 LEAN 4 PROOF:
  [15-26 lines of Lean 4 theorem + lemmas]

⚙️  PTX KERNEL:
  [34-77 lines of Ampere/Hopper assembly]

🌐 FUTHARK SPEC:
  [10-26 lines of functional reference]

✓ PAX CERTIFICATE: [PO1 | PO3 | PO5 | PO7 | PO8]
```

## Troubleshooting

### "UnicodeEncodeError" on Windows
The demo handles UTF-8 automatically. If issues persist:
```bash
python3 demo/demo.py --no-rich --no-pause
```

### "No module named 'rich'"
Rich is optional. Just run without it:
```bash
python3 demo/demo.py --no-rich
```

### Ollama connection refused (--live)
Ensure Ollama is running:
```bash
# Terminal 1: Start Ollama server
ollama serve

# Terminal 2: Download model (first time)
ollama pull Snapkitty/pax-coder-7b

# Terminal 3: Run demo with --live
python3 demo/demo.py --live
```

## File Structure

```
pax-coder/
├── demo/
│   ├── demo.py                  ← Main demo script
│   ├── README.md                ← Full documentation
│   ├── INSTALLATION.md          ← This file
│   └── DEMO_SUMMARY.txt         ← Detailed manifest
├── PAX/                         ← Lean 4 proofs
├── src/                         ← GPU kernels
├── docs/                        ← Architecture docs
└── README.md                    ← Main project README
```

## Next Steps

1. **Run the demo**:
   ```bash
   python3 demo/demo.py --no-pause
   ```

2. **Read the architecture**:
   - See `../PAX/` for Lean 4 proofs
   - See `../src/` for actual GPU kernels
   - See `../docs/` for detailed docs

3. **Get a Sovereign Node Key** (for production):
   - Submit request: See `../CONTACT.md`
   - Select tier (Community $0, Individual $250-500, Commercial $12-25K/yr)
   - Receive provisioned authorization
   - Required for production use

4. **Fine-tune your own**:
   ```bash
   python3 ../export_training_data.py
   pip install -r ../requirements.txt
   ./run_training.sh
   ```

## License

PAX-Coder is tri-licensed:
- BSL-1.1 (until 2028-08-08)
- AGPL-3.0 (from 2028-08-08)
- MPL-2.0 (alternative)

Copyright: Ahmad Ali Parr, Bel Esprit D'Accord Irrevocable Trust

---

Happy kernel proving! 🚀
