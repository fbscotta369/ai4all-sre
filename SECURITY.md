# Security Policy — AI4ALL-SRE Platform

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 4.x+    | ✅ Active           |
| < 4.0   | ❌ Not supported    |

## Reporting a Vulnerability

**Do NOT open a public GitHub issue for security vulnerabilities.**

Please report security issues via **private disclosure**:

1. Email: `security@ai4all-sre.internal` (or the team's private channel)
2. Include: description, reproduction steps, impact assessment, and suggested fix
3. CVSSv3 score if known

We will acknowledge receipt within **24 hours** and aim to release a fix within **72 hours** for Critical issues.

## Security Architecture

This project enforces the following security controls:

| Control | Mechanism | Status |
|:---|:---|:---|
| Zero-Trust mTLS | Linkerd service mesh | ✅ Active |
| PKI Automation | Cert-Manager + HashiCorp Vault | ✅ Active |
| Policy-as-Code | Kyverno ClusterPolicies | ✅ Active |
| CVE Scanning | Trivy Operator (continuous) | ✅ Active |
| Secret Management | Vault Agent Sidecar Injection | ✅ Active |
| AI Action Safety | Pydantic structured output + namespace allowlist | ✅ Active |
| Network Isolation | Kubernetes NetworkPolicy (default-deny) | ✅ Active |
| GitOps Auditability | ArgoCD + CODEOWNERS + branch protection | ✅ Active |

## AI Agent Security Notes

The autonomous SRE agent (`ai_agent.py`) operates under strict constraints:
- **Namespace allowlist**: Can only act on `online-boutique` namespace
- **Action schema validation**: LLM output is constrained to a Pydantic schema — no free-form command execution
- **GitOps-first**: All remediations are committed as Git changes, not direct API patches
- **Debounce protection**: Redis TTL prevents duplicate concurrent remediations

## Branch Protection Requirements

The `main` branch requires:
- Pull Request with minimum **1 CODEOWNER** approval
- All CI/CD checks passing (including `terraform validate`, `trivy fs`, CodeQL)
- No direct pushes (including by the AI agent — it must open a PR)
