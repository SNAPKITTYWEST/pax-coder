# PAX-Coder Pricing & Provisioning

**Last Updated:** 2026-08-18  
**All prices in USD**

---

## Overview

PAX-Coder is a commercial product. Production authorization requires contact, approval, and a commercial agreement.

**All production access requires approval and commercial terms.** Contact for access request at [CONTACT.md](CONTACT.md).

---

## Tiers

### 1. Individual / Node Key — Production Authorization Credential

**$250–$500 per node key (one-time)**

**Audience:** Independent developers and small labs

**What this tier grants:**

A provisioned Sovereign Node Key that authorizes your workstation for production operations.

- ✅ One production-authorized node (one workstation)
- ✅ Ed25519 cryptographic identity + operator-signed authorization
- ✅ Authority to sign official releases
- ✅ Authority to deploy production kernels
- ✅ Local production execution rights
- ✅ Provisioning is permanent (non-revocable unless terms violated)

**What this tier does NOT include:**
- ❌ Commercial licensing (BSL-1.1 applies; separate commercial agreement required)
- ❌ Commercial redistribution rights
- ❌ Enterprise support SLA
- ❌ Multiple nodes (additional nodes: purchase additional keys at same price)
- ❌ Custom Lean 4 proof development
- ❌ Legal claims or warranties

**Important distinction:**
- **Payment** enables provisioning review
- **Approval** grants the right to provision
- **Provisioning** creates the Sovereign Node Key
- **Authorization** is operator-signed (cannot be self-created)
- **Protected operations** require valid authorization

**Provisioning Flow:**
1. Submit provisioning request (CONTACT.md form)
2. PAX-Coder reviews request (1–3 business days)
3. Request approved or denied
4. Payment processing (if approved)
5. Node credential generated (node.json, node_pk.pem, .node_sk)
6. Operator-signs authorization record (authorization.json)
7. Node activated (authorization status = ACTIVE)

---

### 2. Commercial Team — Production Authorization + Commercial Licensing

**$12,000–$25,000 per year**

**Audience:** AI startups, HFT shops, cloud GPU laboratories

**What this tier grants:**

Unlimited production-authorized nodes within your organization, plus commercial licensing rights.

- ✅ Unlimited internal Sovereign Node keys (all provisioned and operator-authorized)
- ✅ Full commercial licensing
- ✅ Hardware target support (sm_86, sm_90)
- ✅ Multiple provisioned nodes
- ✅ Team deployment rights
- ✅ Release signing capability
- ✅ Priority email support
- ✅ Annual renewal

**What's NOT included:**
- ❌ Custom Lean 4 proof development
- ❌ Formal kernel audits
- ❌ SLA-backed support
- ❌ White-label embedding

**Process:**
1. Submit provisioning request
2. Commercial review
3. Agreement negotiation
4. Payment processing
5. Team provisioning setup

---

### 3. Enterprise Verification

**$50,000–$150,000+ per year**

**Audience:** Mission-critical, defense, and FinTech deployments

**What's included:**
- ✅ Unlimited Sovereign Node keys
- ✅ Custom Lean 4 proof modeling for your kernels
- ✅ Formal kernel audits and sign-off
- ✅ Direct SLA (response time guarantees)
- ✅ White-label embedding rights
- ✅ Enterprise commercial licensing
- ✅ Custom hardware target support
- ✅ Direct technical contact
- ✅ Annual renewal

**Custom packages available:**
- Multi-year contracts
- Exclusive deployments
- Custom feature development
- Governance involvement

**Process:**
1. Executive engagement
2. Detailed requirements gathering
3. Custom quote
4. Legal/procurement
5. Deployment and provisioning

---

### 4. Proof Audit & Sign-Off

**$10,000+ per custom kernel**

**What's included:**
- ✅ Formal verification of custom CUDA kernel
- ✅ Lean 4 proof verification outside standard axiom basis (PO_1–PO_8)
- ✅ Cryptographic sign-off with Sovereign Node key
- ✅ Detailed audit report
- ✅ Proof artifact

**Process:**
1. Submit kernel and specifications
2. Audit engagement
3. Verification and proof development
4. Sign-off and delivery

---

## Provisioning & Node Credentials

### What is a Sovereign Node?

A Sovereign Node is:
- ✅ A cryptographic identity (Ed25519 public/private keypair)
- ✅ A provisioned authorization record
- ✅ Eligible for signed authorization capabilities
- ✅ Bound to commercial agreement terms

A Sovereign Node is NOT:
- ❌ Something generated locally by running a script
- ❌ Something from cloning the repository
- ❌ A self-signed or self-authorized credential
- ❌ Automatically available to anyone

### Node Provisioning States

```
UNPROVISIONED
    (no request)
         ↓
REQUESTED
    (user submitted request)
         ↓
REVIEWING
    (PAX-Coder authority review)
         ↓
  APPROVED ← or ← REJECTED
         ↓
PROVISIONING
    (credential issuance)
         ↓
ACTIVE
    (node is authorized)
         ↓
REVOKED (if terms violated)
```

### How to Get a Node

**Step 1: Select Tier**

Choose the appropriate plan above (Community, Individual, Commercial Team, or Enterprise).

**Step 2: Request Provisioning**

Fill out the provisioning form at:

```
https://snapkittywest.com/pax-coder/request
```

or email:

```
pax-coder@snapkittywest.com
```

Include:
- Your name / organization
- Intended use case
- Requested tier
- Deployment requirements
- Contact email

**Step 3: Review & Approval**

- Individual tier: 1–3 business day review
- Commercial/Enterprise: Formal review process

**Step 4: Commercial Agreement & Payment**

- Individual: Secure payment link (one-time)
- Commercial/Enterprise: Formal commercial agreement

**Step 5: Provisioning**

- Node credential created
- Authentication material provided
- Activation in your environment

**Step 6: Active Node**

Use your provisioned credential for:
- Signing releases
- Protected kernel operations
- Production deployment

---

## FAQ

### Q: Can I access the repository?

**A:** Repository access is free for verification/testing. Production authorization requires contact, approval, and the applicable commercial tier. See [CONTACT.md](CONTACT.md).

### Q: Do I get a Sovereign Node automatically?

**A:** No. Approval is required for access. To perform protected operations (signing releases, production deployment), you need a provisioned node through the appropriate tier after approval and payment.

### Q: How much does a Sovereign Node cost?

**A:** It depends on your usage:
- **Individual:** $250–$500 (one-time, one workstation)
- **Commercial Team:** Included with $12,000–$25,000/year plan
- **Enterprise:** Included with $50,000–$150,000+/year plan

### Q: Can I generate a node key locally?

**A:** You can generate a local cryptographic keypair, which creates a node IDENTITY. However, this is NOT a provisioned node. It is UNREGISTERED and UNAUTHORIZED for production use. Only provisioned nodes (obtained through purchase/provisioning) are authorized for protected operations.

### Q: What's the difference between node IDENTITY and node AUTHORIZATION?

**A:** 
- **Identity:** A cryptographic public key + metadata. Anyone can generate one locally. Not sufficient for authorization.
- **Authorization:** A provisioned credential from PAX-Coder authority, issued only after provisioning. Required for protected operations.

### Q: Can I use an Individual node on multiple machines?

**A:** The Individual tier includes one provisioned node for one workstation. Additional machines require additional node keys (additional $250–$500 each). Commercial Team and Enterprise tiers support multiple nodes.

### Q: What happens if I don't renew my subscription?

**A:** 
- **Individual:** One-time purchase; no renewal required. Your node remains active indefinitely (unless revoked for terms violation).
- **Commercial/Enterprise:** Upon renewal deadline, the subscription ends. Existing nodes become inactive; new authorization capabilities are not issued. Contact for reactivation.

### Q: Can I transfer my node to another person/organization?

**A:** No. Nodes are provisioned to the named organization/individual. Transfer requires a new provisioning request and agreement.

### Q: What if I violate the commercial terms?

**A:** Terms violations may result in:
- Provisioning revocation
- Capability expiration
- Node deactivation
- Legal action (depending on violation severity)

Contact support if you believe a violation has occurred.

### Q: How do I request an Enterprise contract?

**A:** Email:

```
enterprise@snapkittywest.com
```

Include:
- Organization name
- Executive/technical contact
- Deployment requirements
- Estimated kernel volume
- Custom requirements

Enterprise team will respond within 2 business days.

---

## Commercial Licensing

PAX-Coder is dual-licensed:

- **BSL-1.1:** For commercial usage under provisioning agreement
- **AGPL-3.0:** For source code review and non-commercial use

Provisioning establishes the commercial usage rights appropriate to your tier.

See [LICENSE.md](LICENSE.md) for full details.

---

## Support

### Community Users

- GitHub Issues for bug reports
- Documentation at snapkittywest.com
- Community forum (link)

### Individual Tier

- Email support: individual-support@snapkittywest.com
- Response time: 2–5 business days
- Included: Technical questions about provisioning and kernel generation

### Commercial/Enterprise Tier

- Dedicated Slack channel
- Priority email support
- Phone support (Enterprise only)
- Response time: 1 business day (Commercial), 4 hours (Enterprise)

---

## Contact

**General inquiries:**
```
pax-coder@snapkittywest.com
```

**Provisioning requests:**
```
https://snapkittywest.com/pax-coder/request
```

**Enterprise:**
```
enterprise@snapkittywest.com
```

**Support issues:**
```
support@snapkittywest.com
```

---

**PAX-Coder is developed by SnapKitty.**  
**© 2026 SnapKitty. All rights reserved.**
