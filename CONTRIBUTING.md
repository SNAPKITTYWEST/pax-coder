# Contributing to PAX-Coder

![contribution-only](https://img.shields.io/badge/mode-contribution--only-c0392b?style=flat-square)
![sovereign](https://img.shields.io/badge/sovereignty-sealed-8e44ad?style=flat-square)
![node-key](https://img.shields.io/badge/node--key-required-2e86c1?style=flat-square)

---

## This Is Not Open Source

PAX-Coder is tri-licensed under BSL-1.1 / AGPL-3.0 / MPL-2.0.
See `LICENSE.tri` and run `backends/license_policy.pl` to determine which applies to you.

You may:
- **Read** the code and proofs
- **Learn** from the architecture
- **Fork** for personal study
- **Contribute** back improvements (PR required, reviewed by sovereign authority)

You may NOT without a Sovereign Node Key:
- Run PAX-Coder in production
- Seal outputs for deployment
- Access the `pax-verify` API
- Offer PAX-Coder as a managed service

---

## Before Contributing

1. **Hold a Sovereign Node Key** — see `SOVEREIGN_NODE_KEY.md`
2. Read `docs/PAX_ARCHITECTURE.md` — understand the 5 axioms and 8 proof obligations
3. If your contribution touches Lean 4, build the proofs: `cd PAX && lake build`

---

## What We Accept

- Bug fixes — must include a test or proof that demonstrates the fix
- Lean 4 proof improvements — fill in `sorry` stubs with real proofs
- New PTX kernel categories — must satisfy all relevant POs
- Futhark spec additions — functional correctness required
- Performance improvements — must include NCU benchmark data
- Documentation — especially worked examples and user guides

## What We Reject

- Breaking changes to sealed interfaces
- New dependencies (PAX is zero-runtime-dep by design)
- Kernels without at least PO8 (termination + correctness) satisfied
- AI-generated PRs without human review and a node key seal
- Anything that compromises the proof chain

---

## Commit Standards

Every commit message starts with a verb: `add`, `fix`, `seal`, `verify`, `prove`, `lower`.

```
prove: Float16 RNE error bound — fills sorry in PAX/Float16_Rounding.lean
add: warp shuffle reduction for softmax, satisfies PO3+PO4
fix: pipeline stage count off-by-one in throughput bound
```

---

## PR Process

1. Fork → branch from `main` → make changes
2. Run `cd PAX && lake build` — all proofs must compile, zero sorry on critical path
3. Run `nvcc -arch=sm_86` on any PTX changes — must compile clean
4. Submit PR — describe the what, why, and which POs are satisfied/improved
5. Sovereign authority reviews — typically 3-5 days

All merged contributors are logged in the WORM ledger with their node key.
Your contribution is cryptographically sealed and timestamped. Permanently.

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*
