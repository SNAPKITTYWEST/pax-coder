# Sovereign Node Key

To run PAX-Coder in production you must hold a Sovereign Node Key.

A node key is proof of contribution to the SnapKitty Sovereign Stack.
It is an Ed25519 keypair derived from your donor transaction hash.
Without a valid key, the PAX seal gate will refuse to sign outputs.

---

## Why a Key Exists

PAX-Coder is not a product built overnight. The PAX architecture — five axioms, eight proof
obligations, formally verified GEMM pipeline, pipeline calculus, epilogue algebra — represents
years of work. The Lean 4 proofs alone are hundreds of hours.

**Running it without contributing is extraction. The key is the covenant.**

It does not restrict what you build. It records that you showed up.

---

## Tiers

| Tier | Minimum | What You Get |
|------|---------|--------------|
| **Node** | $25 | 1 sovereign node key — run PAX-Coder, seal outputs |
| **Forge** | $100 | Node key + listed as Forge Contributor in WORM ledger |
| **Sovereign** | $500 | Node key + name sealed in genesis block of next chain |
| **Enterprise** | $5,000/yr | Node key + `pax-verify` API access + custom fine-tuning + SLA |

---

## How to Get a Key

**Step 1 — Donate**

- **Stripe:** [collectivekitty.com/donate](https://collectivekitty.com/donate)
- **Email after payment:** `ahmedparr93@gmail.com`
  Subject line: `PAX-CODER NODE KEY REQUEST`
  Include: transaction hash or receipt

**Step 2 — Generate your Ed25519 keypair** (or we generate one for you)

```bash
# Generate keypair (standard Ed25519)
openssl genpkey -algorithm Ed25519 -out node_sk.pem
openssl pkey -in node_sk.pem -pubout -out node_pk.pem

# Extract raw 32-byte keys
openssl pkey -in node_sk.pem -outform DER | tail -c 32 > node_sk.bin
openssl pkey -in node_pk.pem -pubin -outform DER | tail -c 32 > node_pk.bin
```

Send your **public key** (`node_pk.bin` as hex or base64) in the email.
We register it in the Bifrost WORM ledger and return your signed node certificate.

**Step 3 — Run with your key**

```bash
# Ollama — set node key as env var
export PAX_NODE_KEY="$(xxd -p node_sk.bin | tr -d '\n')"
ollama run pax-coder "Write a verified GEMM kernel"

# Python — pass key at init
from pax_coder import PAXCoder
model = PAXCoder(node_key_path="node_sk.bin")
```

---

## How the Key Works Technically

Every output PAX-Coder seals is signed with your node key via Ed25519:

```
output_hash  = Blake3(lean_proof || ptx_kernel || futhark_spec || pax_certificate)
signature    = Ed25519_sign(node_sk, output_hash)
worm_entry   = { hash, signature, node_pk, timestamp, tier }
```

The WORM ledger records your public key against every output you seal.
Anyone can verify: `Ed25519_verify(node_pk, output_hash, signature)`.

Your contributions are cryptographically timestamped and permanently attributed.

---

## What the Key Does NOT Do

- It does not phone home. The key runs entirely local.
- It does not restrict what kernels you generate.
- It does not expire (Node tier keys are perpetual).
- It does not require internet access to verify locally.

---

## Registering Your Key

After receiving your signed node certificate, register it:

```bash
# Register in local PAX keystore
pax-coder register --cert node_cert.json --pk node_pk.bin

# Verify registration
pax-coder verify-key --pk node_pk.bin
# → Node registered: FORGE tier · WORM block #4821 · 2026-08-17
```

---

## Enterprise API Access

Enterprise tier ($5,000/yr) includes access to the `pax-verify` REST API:

```bash
# POST a kernel for remote verification
curl -X POST https://api.collectivekitty.com/pax-verify \
  -H "Authorization: Bearer $PAX_ENTERPRISE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"lean_proof": "...", "ptx_kernel": "...", "target_arch": "sm_86"}'

# Response:
# {
#   "verified": true,
#   "obligations": ["PO1", "PO3", "PO5", "PO8"],
#   "worm_seal": "blake3:a3f8...",
#   "certificate": "ed25519:..."
# }
```

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · EIN 42-6976431*
*Evidence or Silence — 2026*
