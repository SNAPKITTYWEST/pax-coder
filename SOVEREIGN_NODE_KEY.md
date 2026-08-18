# Sovereign Node Key — Production Authorization Credential

To run PAX-Coder in production you must hold a provisioned Sovereign Node Key.

A **Sovereign Node Key** is an Ed25519 keypair + operator-signed authorization record that grants production authorization for protected operations. The PAX-Coder authority signs the authorization; the node cannot self-authorize.

---

## What a Node Key Grants

A provisioned Sovereign Node Key authorizes a specific workstation/node to:
- ✓ Sign production releases
- ✓ Deploy production kernels
- ✓ Perform protected operations within your authorized scope

---

## Commercial Pricing Model

Production-authorized nodes are available through commercial tiers:

| Tier | Price | What You Get |
|------|-------|--------------|
| **Individual Node** | $250–$500 | One production-authorized node (one workstation) |
| **Commercial Team** | $12,000–$25,000/year | Unlimited production-authorized nodes within your organization |
| **Enterprise** | $50,000–$150,000+/year | Custom audits, white-label rights, direct SLA |

---

## How to Get a Production-Authorized Node

**Step 1 — Request Access**

Submit provisioning request at:
- **Form:** [CONTACT.md](CONTACT.md)
- **Email:** pax-coder@snapkittywest.com

Include:
- Your name/organization
- Intended use case
- Requested tier
- Deployment requirements

**Step 2 — Approval**

PAX-Coder reviews and approves or denies (1–3 business days).

**Step 3 — Generate Your Ed25519 Keypair** (or operator generates one for you)

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
