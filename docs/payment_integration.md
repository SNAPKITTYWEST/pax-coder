# Node Key Payment Integration Guide

**For:** PAX-Coder team  
**Purpose:** How to handle node key payment requests  
**Status:** Active  

---

## Payment Platform: Stripe

All payments go through Stripe. No payment data stored locally.

**Stripe Account:** snapkittywest  
**Product IDs:**
- Individual node key: `price_individual_nodekey`
- Academic node key: `price_academic_nodekey`
- Commercial node key: `price_commercial_nodekey`

---

## After Payment: Issuing Tokens

When someone completes payment:

### 1. Receive Notification
Stripe webhook → `POST /webhooks/nodekey-payment`

Payload includes:
```json
{
  "customer_email": "user@example.com",
  "tier": "individual|academic|commercial|enterprise",
  "timestamp": "2026-08-18T...",
  "payment_id": "pi_xxxxx"
}
```

### 2. Generate Authorization Token
```bash
# Token format: pax-<tier>-<32-char-random>-<timestamp>
# Example: pax-individual-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6-2026-08-18T14-30-00Z

TOKEN=$(openssl rand -hex 16 | tr -d '\n')-$(date -u +"%Y-%m-%dT%H-%M-%SZ")
FULL_TOKEN="pax-${TIER}-${TOKEN}"
```

### 3. Set Expiration
Tokens expire **30 days** after issue.

Store in database:
```
token: pax-individual-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6-2026-08-18T14-30-00Z
tier: individual
email: user@example.com
created: 2026-08-18T14:30:00Z
expires: 2026-09-17T14:30:00Z
used: false
used_at: null
payment_id: pi_xxxxx
```

### 4. Send Confirmation Email

**To:** user@example.com  
**Subject:** Your PAX-Coder Node Key Authorization

Body:
```
Hi there,

Thank you for your payment! Your node key authorization is ready.

Your authorization token:
    pax-individual-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6-2026-08-18T14-30-00Z

This token expires on: 2026-09-17 at 14:30 UTC

Next steps:
1. Clone PAX-Coder (or update your clone)
2. Set the token: export PAX_AUTH_TOKEN="<your-token>"
3. Run: ./scripts/verify-release
4. Run: cd sovereign && ./generate_node_key.sh

Your private key is generated locally and never transmitted to us.

Questions? See NODE_KEY_REQUEST_POLICY.md or email support@snapkittywest.com

Best,
PAX-Coder Team
```

---

## Token Validation

When user runs `verify-release` with their token:

```bash
# User:
export PAX_AUTH_TOKEN="pax-individual-..."
./scripts/verify-release
```

Script checks:
1. Token format is valid (`pax-<tier>-...`)
2. Token is in database
3. Token is not expired
4. Token is not already used

If all checks pass:
- Exit 0 (VERIFIED_AND_AUTHORIZED)
- User proceeds with `generate_node_key.sh`

If any check fails:
- Exit 2 (VERIFIED_NOT_AUTHORIZED)
- Clear error message

---

## One-Time Use

After `generate_node_key.sh` completes successfully:

```bash
# Mark token as used
UPDATE tokens SET used = true, used_at = NOW() WHERE token = "pax-...";
```

Second attempt with same token:
- Script detects it's been used
- Returns: "Token already used"
- User must request new authorization (may be charged again)

---

## Tier-Specific Rules

### Individual ($29)
- 1 token issued
- Expires 30 days
- Generates 1 node key
- Can request new tokens (charged \$29 each)

### Academic (Free)
- Requires .edu email OR faculty verification
- 1 token issued
- Expires 30 days
- Generates 1 node key
- Can request new tokens (free, but must re-verify)

### Commercial ($199/year)
- 5 tokens issued per year
- Each token generates 1 key
- Can issue new tokens anytime during year (no additional charge)
- Year resets on anniversary date

### Enterprise (Custom)
- Unlimited tokens
- Direct negotiation with sales team
- Custom terms per agreement

---

## Database Schema

```sql
CREATE TABLE node_key_tokens (
  id INTEGER PRIMARY KEY,
  token TEXT UNIQUE NOT NULL,
  tier TEXT NOT NULL,  -- individual, academic, commercial, enterprise
  email TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used BOOLEAN DEFAULT false,
  used_at TIMESTAMP NULL,
  payment_id TEXT NOT NULL,
  notes TEXT,
  INDEX (email),
  INDEX (token),
  INDEX (expires_at)
);

CREATE TABLE node_keys_generated (
  id INTEGER PRIMARY KEY,
  token TEXT NOT NULL,  -- Reference to tokens table
  node_id TEXT NOT NULL,
  node_pk_hash TEXT NOT NULL,  -- SHA256 of public key
  generated_at TIMESTAMP NOT NULL,
  generator_ip TEXT,  -- For audit trail (optional)
  INDEX (node_id),
  INDEX (token)
);
```

---

## Handling Issues

### Token Expired
User: "My token expired!"

```bash
# Check expiration
SELECT expires_at FROM node_key_tokens WHERE token = "pax-...";

# If expired, user must re-request and re-pay
```

### Token Lost
User: "I didn't save my token!"

```bash
# Verify they are the payer
# If verified, re-issue same tier (may be charged again)
```

### Token Used Twice (Bug)
Script should prevent this, but if it happens:

```bash
# Check: SELECT used FROM node_key_tokens WHERE token = "pax-...";
# If true, explain: "This token was already used to generate a key"
# Offer: Re-request for fee (or free if our bug)
```

### Payment Failed
Stripe → Webhook with error code

```json
{
  "type": "charge.failed",
  "customer_email": "user@example.com",
  "reason": "insufficient_funds"
}
```

Send email: "Your payment didn't go through. Please try again or contact support."

---

## Refund Process

Academic: Send refund reason + screenshot of .edu email  
Individual: 7-day refund window after purchase  
Commercial: Pro-rated refund for unused portion of year  
Enterprise: Per contract

---

## Stripe Webhook Setup

Endpoint: `https://snapkittywest.com/webhooks/nodekey-payment`

Events to subscribe:
- `charge.succeeded`
- `charge.failed`
- `payment_intent.succeeded`
- `payment_intent.payment_failed`

---

## Contact & Support

**Payments/Billing:** support@snapkittywest.com  
**Technical Issues:** support@snapkittywest.com  
**Enterprise Deals:** sales@snapkittywest.com  

---

**Created:** 2026-08-18  
**Last Updated:** 2026-08-18  
**Status:** Ready for implementation
