# PAX-Coder Pricing & Provisioning

**Last Updated:** 2026-08-18  
**All prices in USD**

---

## Overview

PAX-Coder offers four tiers of access and support.

**All access requires approval.** Contact for access request at [CONTACT.md](CONTACT.md).

Commercial usage, production deployment, and provisioned Sovereign Node credentials require the appropriate tier selection.

---

## Tiers

### 1. Community / Contributor

**Free**

**Audience:** Open-source developers and researchers

**Access:** Approval required (non-commercial/research use)

**What's included (after approval):**
- ✅ Repository access
- ✅ Local kernel generation
- ✅ Non-commercial testing
- ✅ Research usage

**What's NOT included:**
- ❌ Provisioned Sovereign Node credential
- ❌ Production deployment
- ❌ Commercial support

**Qualifying usage:**
- Open-source developers
- Academic researchers
- Non-commercial projects

---

### 2. Individual / Node Key

**$250–$500 per node key (one-time)**

**Audience:** Independent developers and small labs

**What's included:**
- ✅ One provisioned Sovereign Node credential
- ✅ Ed25519 production signing key
- ✅ Local production deployment (one workstation)
- ✅ Release signing capability
- ✅ Kernel generation for production use
- ✅ Non-revocable provisioning (unless terms violated)

**What's NOT included:**
- ❌ Commercial redistribution rights
- ❌ Enterprise support SLA
- ❌ Multiple nodes (additional node keys available at same price)
- ❌ Custom Lean 4 proof development

**Process:**
1. Submit provisioning request (contact form)
2. Review and approval
3. Payment processing
4. Node credential issuance
5. Activation in your environment

---

### 3. Commercial Team

**$12,000–$25,000 per year**

**Audience:** AI startups, HFT shops, cloud GPU laboratories

**What's included:**
- ✅ Unlimited internal Sovereign Node keys
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

### 4. Enterprise Verification

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

## Additional Services

### Proof Audit & Sign-Off

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

- Community tier: Automatic approval for qualifying projects
- Individual tier: 1–3 business day review
- Commercial/Enterprise: Formal review process

**Step 4: Agreement & Payment**

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

**A:** Access requires approval. Contact at [CONTACT.md](CONTACT.md) to request access. Community/research usage is $0 after approval.

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
