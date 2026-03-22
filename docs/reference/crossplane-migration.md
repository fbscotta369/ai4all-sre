# Crossplane Migration Path

> **ADR-005**: Why Terraform Now, Crossplane Later

## Status

**Accepted** — March 2026

## Context

Tier-1 Enterprise platform engineering teams increasingly adopt [Crossplane](https://crossplane.io/) to manage cloud resources (S3, RDS, IAM, VPC) directly via Kubernetes Custom Resources. This unifies the control plane — everything is a `kubectl apply`.

However, our AI4ALL-SRE Laboratory is a **local-first, single-cluster** environment running on K3s. The tradeoffs are different here.

## Decision

**Use Terraform for IaC. Defer Crossplane to Phase 2 (multi-cloud).**

### Why Terraform Is Correct NOW

| Factor | Terraform | Crossplane |
|:---|:---|:---|
| **Local-first K3s** | Native support, no dependencies | Requires cloud provider credentials |
| **State management** | Mature (S3 + DynamoDB locking) | K8s etcd (adds operational burden) |
| **Team familiarity** | Industry standard | Newer, steeper learning curve |
| **CI/CD integration** | GitHub Actions native | Requires ArgoCD + XRDs |
| **Drift detection** | `terraform plan` | Kubernetes reconciliation loop |
| **Cloud resources** | Not provisioned (lab is local) | Primary value is cloud resources |

### When to Migrate to Crossplane

Crossplane becomes the superior choice when:

1. **Multi-cloud provisioning** — Managing AWS + GCP + Azure from K8s
2. **Self-service developer portal** — Backstage + Crossplane Compositions
3. **GitOps-native IaC** — ArgoCD managing both apps AND infrastructure
4. **Ephemeral environments** — PR-based cloud environments via XRDs

## Migration Map

When ready, these Terraform resources map to Crossplane XRDs:

```yaml
# ── Current Terraform → Future Crossplane ──

# helm_release.argocd → Already K8s native (no change needed)
# helm_release.kyverno → Already K8s native (no change needed)
# helm_release.vault → Already K8s native (no change needed)

# If/when cloud resources are added:
# aws_s3_bucket → Crossplane Bucket (provider-aws)
# aws_rds_instance → Crossplane RDSInstance (provider-aws)
# aws_iam_role → Crossplane Role (provider-aws)
# google_container_cluster → Crossplane Cluster (provider-gcp)
```

### Crossplane Composition Example (Future)

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: ai4all-sre-database
spec:
  compositeTypeRef:
    apiVersion: platform.ai4all.io/v1alpha1
    kind: Database
  resources:
    - name: rds-instance
      base:
        apiVersion: rds.aws.crossplane.io/v1alpha1
        kind: DBInstance
        spec:
          forProvider:
            dbInstanceClass: db.t3.medium
            engine: postgres
            engineVersion: "15"
            masterUsername: admin
            allocatedStorage: 20
            tags:
              - key: team
                value: sre
              - key: environment
                value: production
              - key: cost-center
                value: platform-engineering
```

## Consequences

- Terraform remains the IaC tool for all current infrastructure
- No cloud provider credentials are required for the lab
- Crossplane migration is documented and ready for Phase 2
- The existing modular Terraform structure cleanly maps to Crossplane Compositions

## References

- [Crossplane vs Terraform](https://blog.crossplane.io/crossplane-vs-terraform/)
- [Crossplane Compositions](https://docs.crossplane.io/latest/concepts/compositions/)
- [Platform Engineering with Crossplane](https://www.cncf.io/blog/2023/crossplane-platform-engineering/)
