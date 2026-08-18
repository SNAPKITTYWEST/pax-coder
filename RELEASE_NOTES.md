# PAX-Coder v1.0.0 Release Notes

Release date: 2026-08-18
Repository: `SNAPKITTYWEST/pax-coder`

## Summary

PAX-Coder v1.0.0 is the institutional foundation release for the
proof-carrying GPU kernel generation program. It packages the repository as a
governed system: proof modules, CUDA/PTX source, Futhark specifications,
training-data export, model fine-tuning, demos, licensing, node-key policy, and
release evidence rules.

## Included Surfaces

- `PAX/`: Lean 4 proof-module surfaces and training schema.
- `src/`: RTX/Ampere CUDA kernel sources and Futhark specification.
- `export_training_data.py`: repository-to-JSONL training-data exporter.
- `train.py`: RTX 3080 oriented QLoRA/Unsloth fine-tuning script.
- `demo/`: static and scripted demonstration package.
- `docs/`: user, architecture, go-to-market, and visual documentation.
- `backends/license_policy.pl`: Prolog license-policy reasoner.
- `LICENSE.tri`: BSL-1.1 / AGPL-3.0 / MPL-2.0 / commercial structure.
- `SOVEREIGN_NODE_KEY.md`: node-key and seal policy.

## Packaging Validation

`python export_training_data.py` completed successfully on Windows after the
v1.0.0 console-output fix.

Observed package split:

```text
Total unique examples: 10
train: 9 examples
val: 0 examples
test: 1 examples
```

## Institutional Guarantees

- PAX proof obligations are described relative to the declared PAX axiom basis.
- Release claims must be traceable to files, commands, outputs, hardware or
  toolchain context, and license path.
- Generated kernels are candidates until proof, compiler, runtime, and license
  gates are satisfied for the exact artifact.

## Verification Commands

```bash
cd PAX
lake build
```

```bash
python export_training_data.py
```

```bash
nvcc -arch=sm_86 -ptx src/rtx_gemm_ptx.cu -o build/pax_gemm.ptx
```

Run the commands that apply to the artifact being released and record the exact
output. If a command is not available in the local environment, mark that gate
as toolchain-gated rather than inferred.

## License

This release follows `LICENSE.tri`:

- BSL-1.1 source-available path with commercial restrictions until `2028-08-08`.
- AGPL-3.0 network-copyleft path.
- MPL-2.0 file-level copyleft path.
- Commercial terms for copyleft bypass and negotiated production use.

## Release Decision

Status: v1.0.0 institutional package.

Production deployment of generated kernels remains artifact-specific and must
pass the verification and licensing gates documented in `README.md`.
