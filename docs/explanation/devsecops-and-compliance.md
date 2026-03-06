# 🛡️ DevSecOps: Security by Default and Governance
> **Tier-1 Engineering Standard: v4.2.0**

In the AI4ALL-SRE Laboratory, security is implemented as a baseline platform primitive rather than an afterthought. We utilize a **Defense-in-Depth** strategy that spans from CI/CD to runtime enforcement, ensuring machine-speed resilience without compromising integrity.

---

## 🔐 The Secure Chain of Custody

Our **DevSecGitOps** pipeline ensures that only verified, secure code reaches the production perimeter.

### 1. Static Security (CI/CD)
Before a container is built, the pipeline executes a rigorous series of checks:
- **Gitleaks**: Automated secret scanning to prevent credential leakage.
- **CodeQL (SAST)**: Semantic analysis of Python/Go code to identify complex vulnerability patterns (e.g., SSRF, SQLi).
- **Trivy (SBOM)**: Generation of CycloneDX SBOMs and CVE scanning of base images.

### 2. Admission Governance (Kyverno)
The **Kyverno** Admission Controller acts as the final gatekeeper for the Kubernetes API.
- **Vulnerability Gating**: Pods with `CRITICAL` vulnerabilities are blocked from deployment.
- **Hardened Defaults**: Mandatory enforcement of non-root execution and read-only root filesystems.
- **Pod Security Standards**: Strict alignment with K8s **Restricted** security profile.

---

## 🕸️ Zero-Trust Data Plane (Linkerd)

We assume the network assumes the perimeter has already been breached. Our zero-trust model relies on cryptographic identity.

- **Explicit Authorization**: No traffic is permitted by default. Every flow requires a Linkerd `Server` and `AuthorizationPolicy`.
- **Identity-Based mTLS**: All mesh traffic is encrypted using ephemeral certificates issued by the internal Linkerd Trust Anchor.
- **Automated Rotation**: Short-lived certificates (24h) minimize the blast radius of potential compromises.

---

## ⚖️ Compliance as Code & Governance Mappings

The laboratory maps technical controls directly to industrial compliance frameworks.

| Framework | Control Requirement | Laboratory Mechanism |
| :--- | :--- | :--- |
| **SOC2 (CC6.1)** | Access Control & Identity | Linkerd mTLS + Authz Policies |
| **SOC2 (CC7.1)** | System Monitoring | OTel/Prometheus Trace Correlation |
| **GDPR (Art. 32)** | Security of Processing | Kyverno Admission Gating (CVE-0) |
| **PCI-DSS (Req. 1)** | Network Segmentation | Linkerd Authorization Scoping |

---

## 🕵️ AI Agent Threat Model & Mitigations

The introduction of an Autonomous AI Agent requires specific security considerations.

- **Threat: Prompt Injection**: Malicious logs could attempt to trick the agent into running unauthorized commands.
  - **Mitigation**: Rigid Regex-based Command Validation (Guardrails) and APF (API Priority and Fairness) limits.
- **Threat: Unauthorized Patching**: The agent attempting to modify `kube-system`.
  - **Mitigation**: Kubernetes RBAC is restricted to `online-boutique` namespace only.

---
*CISO / DevSecOps Lead: AI4ALL-SRE Engineering*
