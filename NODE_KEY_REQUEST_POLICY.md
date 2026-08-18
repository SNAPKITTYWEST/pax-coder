# Node Key Request & Authorization Policy

**Last Updated:** 2026-08-18  
**Status:** Active  

---

## Overview

Node key generation is a **protected operation**. This document defines:
- Who can request a node key
- How to request one
- Payment and pricing
- What you get
- Terms and conditions

---

## Request Flow

```
1. Submit Payment
   ↓
2. Verification Email (confirm your identity)
   ↓
3. Authorization Token Issued
   ↓
4. Run: export PAX_AUTH_TOKEN=<token>
   ↓
5. Run: ./sovereign/generate_node_key.sh
   ↓
6. Your Ed25519 keypair is generated locally (never transmitted)
```

---

## Pricing

| Tier | Cost | What You Get | Duration |
|------|------|--------------|----------|
| **Individual** | $29 | 1 node key + verification utilities | Lifetime |
| **Academic** | Free* | 1 node key + documentation | Lifetime |
| **Commercial** | $199/yr | 5 node keys + support | 1 year |
| **Enterprise** | Custom | Unlimited keys + SLA | Contact us |

*Academic: Must provide university email or verification from faculty member.

---

## How to Request

### Step 1: Choose Your Tier

- **Individual:** Anyone. $29, instant.
- **Academic:** Faculty/student with .edu email. Free, instant verification.
- **Commercial:** Companies using PAX-Coder in production. $199/year.
- **Enterprise:** High-volume use. Contact sales@snapkittywest.com.

### Step 2: Initiate Payment

Click the payment link in [README.md](README.md):
- **Individual/Academic/Commercial:** Stripe checkout
- **Enterprise:** Contact sales team

### Step 3: Provide Details

After payment, you'll receive an email asking for:
- Full name or organization name
- Email address (for token delivery)
- Intended use (e.g., "GPU kernel verification", "academic research")
- GitHub username (optional, for tracking)

### Step 4: Receive Authorization Token

Within **24 hours**, you'll receive:
- Authorization token via secure email
- Link to this policy document
- Link to `sovereign/generate_node_key.sh` documentation

**Do NOT share your authorization token.**

### Step 5: Generate Your Key Locally

Once you have your token:

```bash
# Set the token in your environment
export PAX_AUTH_TOKEN=your-token-here

# Go to PAX-Coder directory
cd pax-coder

# Verify authorization
./scripts/verify-release
# Output should show: VERIFIED_AND_AUTHORIZED

# Generate your keypair
cd sovereign
./generate_node_key.sh
./verify_node_key.sh

# Your keypair is now ready (local only)
```

Your private key (`.node_sk`) is **never transmitted** to us. It stays on your machine.

---

## What You Get

After generation, you have:

### `node.json` (Public)
```json
{
  "node_id": "your-node-id-here",
  "node_name": "your-organization",
  "node_public_key_hex": "302a...",
  "created_at_utc": "2026-08-18T...",
  "verified": true
}
```

You can publish this publicly. It identifies your signing keypair.

### `node_pk.pem` (Public)
Your public key in PEM format. Use this for others to verify your signatures.

### `.node_sk` (Private — NEVER SHARE)
Your private signing key. Store securely:
- ✓ In a password-managed vault
- ✓ On an encrypted drive
- ✓ Offline if not in active use
- ✗ NOT in version control
- ✗ NOT in environment variables (except for CI/CD with proper access control)
- ✗ NOT shared, copied, or transmitted

### `prior_art.json` (Public)
Timestamp record of when your key was created. Proof of prior art for your work.

---

## Authorization Token

Your token is:
- **Single-use:** Can be used once to authorize key generation
- **Time-limited:** Expires 30 days after issue
- **Non-transferable:** Not useful after first use
- **Non-refundable:** If you don't use it, re-request (you may be charged again)

**If your token expires:** Contact support@snapkittywest.com for a reissue.

---

## Verification

After generation, verify your setup worked:

```bash
./sovereign/verify_node_key.sh
```

This checks:
- ✓ node.json is valid
- ✓ node_pk.pem is valid
- ✓ .node_sk exists and is readable (locally)
- ✓ Keys are mathematically consistent

---

## Use Cases

### ✅ You Can Use Your Node Key For

- Signing PAX-Coder releases you generate
- Creating timestamps for your research
- Proving non-repudiation of your work
- Academic papers and technical reports
- Commercial software releases
- Internal organizational use

### ❌ You Cannot Use Your Node Key For

- Impersonating others
- Signing work you didn't create
- Transferring to other organizations
- Revoking work you already signed (it's forever)
- Using after the key is compromised (generate a new one)

---

## Key Rotation

If your private key is compromised:

1. **Stop using it immediately**
2. **Contact support:** security@snapkittywest.com
3. **Request a new key:** Pay for a new authorization (or free replacement if we caused the issue)
4. **Old signatures remain valid** (you can't revoke them)
5. **Publish revocation notice** (warn others not to use the old key)

---

## Refund Policy

| Scenario | Refund |
|----------|--------|
| Never used token before expiration | ❌ No |
| Lost token (user error) | ❌ No |
| Payment system error | ✅ Yes |
| Unauthorized charge | ✅ Yes |
| Changed mind within 7 days | ✅ Yes |
| Token issued but you didn't use it | ❌ No |

Contact support@snapkittywest.com to dispute.

---

## Support

**Questions about node keys?**
- 📖 See: [SOVEREIGN_NODE.md](SOVEREIGN_NODE.md)
- 🔐 See: [SECURITY.md](SECURITY.md)

**Payment issues?**
- Contact: support@snapkittywest.com
- Stripe support: support@stripe.com

**Lost your token?**
- Email: security@snapkittywest.com
- Include: Payment confirmation email, requested node ID

---

## Legal

By requesting and using a node key, you agree to:

1. **Non-Repudiation:** You are responsible for any work signed with your key
2. **No Transfer:** You may not transfer your key to other parties
3. **Secure Storage:** You are responsible for keeping your private key secure
4. **No Warranty:** We provide the key; you are responsible for its security
5. **Compliance:** You will not use the key to impersonate others or violate laws

---

## Pricing Changes

We reserve the right to adjust pricing with **30 days notice**. Existing tokens remain valid at the time of purchase.

---

## Contact

- **Requests:** See payment link in [README.md](README.md)
- **Support:** support@snapkittywest.com
- **Security Issues:** security@snapkittywest.com
- **General:** info@snapkittywest.com

---

**Questions?** This policy is a living document. Email us suggestions.

---

**Policy Version:** 1.0  
**Effective:** 2026-08-18  
**Last Updated:** 2026-08-18
