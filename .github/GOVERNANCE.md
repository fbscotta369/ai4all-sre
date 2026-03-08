# Professional Governance for AI4ALL-SRE

## Decision-Making Process
The AI4ALL-SRE project follows a consensus-driven approach to architectural changes. All major technical pivots must be documented via **Architecture Decision Records (ADRs)** located in the `adr/` directory.

## Contribution Flow
1. **RFC / ADR**: Propose significant changes via a new ADR.
2. **Implementation**: Code changes should follow the established patterns in `platforms/` and `gitops/`.
3. **Review**: Changes must be approved by the designated [CODEOWNERS](CODEOWNERS).

## Technical Stewardship
The project is maintained as a Tier-1 SRE Laboratory, emphasizing:
- **Zero-Trust Security** (mTLS by default).
- **GitOps Sovereignty** (ArgoCD as the Source of Truth).
- **Autonomous Operates** (AI-driven remediation).
