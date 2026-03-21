# 🛡️ DevSecOps: Security by Default and Governance
> **Tier-1 Engineering Standard: v5.1.0**

In the AI4ALL-SRE Laboratory, security is implemented as a baseline platform primitive rather than an afterthought. We utilize a **Defense-in-Depth** strategy that spans from CI/CD to runtime enforcement, ensuring machine-speed resilience without compromising integrity.

## 🆕 Security Enhancements (v5.1.0)

### Zero Hardcoded Credentials

All hardcoded passwords have been eliminated and replaced with secure alternatives:

| Component | Previous State | Current State |
|-----------|---------------|---------------|
| Terraform Secrets | `"password123!"` | `random_password` resource |
| Python Defaults | `"admin"`, `"password"` | Environment variable validation |
| Credential Storage | Plain text in config files | Kubernetes Secrets only |

**Implementation:**
```hcl
# Before (insecure)
resource "kubernetes_secret" "credentials" {
  data = {
    password = "password123!"
  }
}

# After (secure)
resource "random_password" "password" {
  length  = 32
  special = true
}

resource "kubernetes_secret" "credentials" {
  data = {
    password = random_password.password.result
  }
}
```

### Credential Validation

Python modules now validate required credentials at startup:

```python
# Before (default values)
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "password")

# After (validation)
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")

if not MINIO_ACCESS_KEY:
    raise ValueError("MINIO_ACCESS_KEY environment variable is required")
if not MINIO_SECRET_KEY:
    raise ValueError("MINIO_SECRET_KEY environment variable is required")
```

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

## 🔄 Resilience Patterns (v5.1.0)

### Circuit Breaker Pattern

The AI Agent now implements circuit breakers to protect against cascading failures:

```python
from circuit_breaker import CircuitBreakers

# Protected calls with automatic fallback
result = CircuitBreakers.ollama.execute(query_function)
result = CircuitBreakers.redis.execute(redis_operation)
```

**Security Benefits:**
- Prevents denial-of-service from dependency failures
- Graceful degradation when services are unavailable
- Automatic recovery when services restore
- Thread-safe implementation prevents race conditions

### Health Monitoring

Circuit breaker states are exposed via the `/health` endpoint for monitoring:

```json
{
  "status": "ok",
  "circuit_breakers": {
    "ollama": {"state": "CLOSED", "failure_count": 0},
    "redis": {"state": "CLOSED", "failure_count": 0},
    "k8s_api": {"state": "CLOSED", "failure_count": 0},
    "git": {"state": "CLOSED", "failure_count": 0}
  }
}
```

---

## 🕵️ AI Agent Threat Model & Mitigations

The introduction of an Autonomous AI Agent requires specific security considerations.

- **Threat: Prompt Injection**: Malicious logs could attempt to trick the agent into running unauthorized commands.
  - **Mitigation**: Rigid Regex-based Command Validation (Guardrails) and APF (API Priority and Fairness) limits.
  - **Enhanced Mitigation (v5.1.0)**: Pydantic schema validation for structured LLM output eliminates regex parsing risks.
- **Threat: Unauthorized Patching**: The agent attempting to modify `kube-system`.
  - **Mitigation**: Kubernetes RBAC is restricted to `online-boutique` namespace only.
- **Threat: Dependency Compromise**: Malicious or compromised external services.
  - **Mitigation (v5.1.0)**: Circuit breaker pattern isolates failures and prevents cascading attacks.

---
*CISO / DevSecOps Lead: AI4ALL-SRE Engineering*
