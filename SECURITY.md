# Security Policy — AI4ALL-SRE Platform

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 4.x+    | ✅ Active           |
| < 4.0   | ❌ Not supported    |

## Vulnerability Disclosure Program (VDP)

This project maintains a formal **Vulnerability Disclosure Program (VDP)**. We value the input of security researchers and the community to keep our platform secure.

### Disclosure Policy
- **Responsible Disclosure**: We ask that you provide us a reasonable amount of time to resolve the issue before disclosing it to the public or a third party.
- **Good Faith**: Researchers should make a good faith effort to avoid privacy violations, destruction of data, and interruption or degradation of our services.
- **Standard Contact**: Please see our standardized [security.txt](docs/well-known/security.txt) for technical contact details and encryption keys.

### Reporting a Vulnerability

**Do NOT open a public GitHub issue for security vulnerabilities.**

Please report security issues via **Private Disclosure**:

1. **Email**: `security@ai4all-sre.internal`
2. **Technical Details**: Include a summary, reproduction steps (with PoC if possible), impact assessment, and any suggested remediation.
3. **Classification**: Use CVSSv3.1 scoring to help us prioritize.

### Our Commitment
- **Acknowledgment**: We will acknowledge receipt of your report within **12-24 hours**.
- **Triage**: High and Critical issues will be triaged within **24 hours**.
- **Resolution**: We aim to release a fix for Critical issues within **72 hours**.
- **Recognition**: Valid disclosures that lead to a fix will be credited in our monthly Security Bulletin.

## Security Architecture

This project enforces the following security controls:

| Control | Mechanism | Status |
|:---|:---|:---|
| Zero-Trust mTLS | Linkerd service mesh | ✅ Active |
| PKI Automation | Cert-Manager + HashiCorp Vault | ✅ Active |
| Policy-as-Code (Runtime) | Kyverno ClusterPolicies (10 policies) | ✅ Active |
| Policy-as-Code (CI) | OPA/Conftest + Kyverno CLI tests | ✅ Active |
| CVE Scanning | Trivy Operator (continuous) | ✅ Active |
| SAST — Python | Bandit + CodeQL | ✅ Active |
| SAST — Multi-language | Semgrep (Python, Terraform, Dockerfile, K8s) | ✅ Active |
| Dependency Safety | pip-audit (CVE scan on all requirements) | ✅ Active |
| SBOM Generation | Trivy CycloneDX (filesystem + image-level) | ✅ Active |
| SBOM Attestation | Cosign in-toto CycloneDX attestation | ✅ Active |
| Image Signing | Cosign Keyless (Sigstore/Fulcio OIDC) | ✅ Active |
| Image Signature Verification | Kyverno `verify-image-signatures` admission | ✅ Audit |
| Supply Chain Provenance | SLSA Level 3 (slsa-github-generator) | ✅ Active |
| IaC Scanning | Checkov + tfsec + Conftest (OPA) | ✅ Active |
| Secret Scanning | Gitleaks (CI + pre-commit) | ✅ Active |
| Dockerfile Linting | Hadolint (CI + pre-commit) | ✅ Active |
| Secret Management | Vault Agent Sidecar Injection | ✅ Active |
| AI Action Safety | Pydantic structured output + namespace allowlist | ✅ Active |
| Network Isolation | Kubernetes NetworkPolicy (default-deny) | ✅ Active |
| GitOps Auditability | ArgoCD + CODEOWNERS + branch protection | ✅ Active |
| Pre-commit Hooks | Gitleaks, Bandit, Terraform, ShellCheck, Hadolint | ✅ Active |
| Container Hardening | Multi-stage builds, non-root, HEALTHCHECK | ✅ Active |

## DevSecOps Pipeline

Security is enforced at every stage of the SDLC (Shift-Left):

```
Developer Workstation → Pre-commit Hooks → CI Security Gates → Image Signing → Admission Control → Runtime Scanning
```

### CI Security Gates (`.github/workflows/security-gate.yml`)

| Gate | Tools | Enforcement |
|:---|:---|:---|
| SAST | Bandit, Semgrep, CodeQL | Fail on HIGH+ |
| Supply Chain | pip-audit, Trivy SBOM | Fail on CRITICAL CVE |
| Container Security | Docker build, Trivy image scan, Cosign sign | Fail on CRITICAL |
| Policy-as-Code | Kyverno CLI, Conftest (OPA), Checkov | Fail on policy violation |

### Kyverno Admission Policies (Runtime)

| Policy | Action | Category |
|:---|:---|:---|
| disallow-privileged-containers | Enforce | Pod Security |
| require-resource-limits | Audit | Resource Management |
| mutate-resource-limits | Audit (mutate) | Resource Management |
| enforce-linkerd-injection | Enforce | Zero-Trust |
| restrict-image-registries | Audit | Supply Chain |
| block-critical-vulnerabilities | Audit | CVE Prevention |
| require-image-digest | Enforce | Supply Chain |
| verify-image-signatures | Audit | Supply Chain |
| require-mandatory-labels | Audit | Governance / FinOps |
| require-probes | Audit | Reliability |

## AI Agent Security Notes

The autonomous SRE agent (`ai_agent.py`) operates under strict constraints:
- **Namespace allowlist**: Can only act on `online-boutique` namespace
- **Action schema validation**: LLM output is constrained to a Pydantic schema — no free-form command execution
- **GitOps-first**: All remediations are committed as Git changes, not direct API patches
- **Debounce protection**: Redis TTL prevents duplicate concurrent remediations

## Branch Protection Requirements

The `main` branch requires:
- Pull Request with minimum **1 CODEOWNER** approval
- All CI/CD checks passing (including `terraform validate`, `trivy fs`, CodeQL, Security Gates)
- No direct pushes (including by the AI agent — it must open a PR)

## Local Security Scanning

Developers can run the full security gate locally before pushing:

```bash
./scripts/security-scan.sh          # Full scan
./scripts/security-scan.sh --quick  # Fast scan (skip Terraform validate)
```

## Pre-commit Hooks

Install once to automatically enforce security on every commit:

```bash
pip install pre-commit
pre-commit install
```
