# Changelog

All notable repository-level release changes are tracked here.

## v1.0.0 - 2026-08-18

Institutional foundation release for PAX-Coder.

### Added

- Institutional root README for the PAX proof-carrying GPU kernel program.
- Institutional architecture SVG at `docs/assets/pax-coder-institutional-architecture.svg`.
- Version marker in `VERSION`.
- Release notes in `RELEASE_NOTES.md`.
- Package manifest in `PACKAGE.md`.

### Fixed

- Windows console packaging issue in `export_training_data.py` by replacing a
  Unicode progress arrow with ASCII output.

### Release Scope

- Lean 4 proof-module surfaces under `PAX/`.
- CUDA/PTX kernel source surfaces under `src/`.
- Futhark functional specification under `src/pax_kernel.fut`.
- Training-data exporter and QLoRA training script.
- Demo package and user/institutional documentation.
- Tri-license policy and node-key documentation.

### Evidence Boundary

- PAX proof obligations are stated relative to the declared PAX axiom basis.
- Generated outputs are candidate artifacts until checked through the release pipeline.
- Runtime production claims require compiler, target hardware, and reference-comparison evidence.
- License and node-key requirements remain part of production release governance.

### Packaging Evidence

- `python export_training_data.py` completed on Windows.
- Current source inventory produced 10 unique examples: 9 train, 0 validation,
  and 1 test.
