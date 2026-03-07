# Karpenter Node Scaling Guide

This guide describes how the AI4ALL-SRE platform leverages **Karpenter** for dynamic, just-in-time node provisioning.

## 🏗️ Overview
Unlike the standard Cluster Autoscaler (CAS) which scales node groups, **Karpenter** talks directly to the EC2 API to provision exactly the hardware needed for pending pods.

## ⚙️ Configuration

### 1. Provisioner
The `Provisioner` CRD defines the constraints for Karpenter's node selection.

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: "karpenter.sh/capacity-type"
      operator: In
      values: ["on-demand", "spot"]
    - key: "kubernetes.io/arch"
      operator: In
      values: ["amd64"]
    - key: "node.kubernetes.io/instance-type"
      operator: In
      values: ["m5.large", "m5.xlarge", "t3.medium"]
  limits:
    resources:
      cpu: 1000
  providerRef:
    name: default
  ttlSecondsAfterEmpty: 30
```

### 2. NodeTemplate
Defines the infrastructure-specific configuration (Subnets, Security Groups, AMIs).

```yaml
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  subnetSelector:
    karpenter.sh/discovery: ai4all-sre
  securityGroupSelector:
    karpenter.sh/discovery: ai4all-sre
```

## 🚀 Operation
- **Just-in-Time**: Nodes are provisioned in < 60s from pod pending state.
- **Consolidation**: Karpenter automatically moves pods to cheaper nodes to save costs.
- **Interruption Handling**: Automatically handles Spot instance interruptions.

## 🤖 AI Agent Integration
The SRE Agent can trigger "Predictive Scaling" by increasing the replica count of a deployment, which in turn signals Karpenter to provision more hardware if the cluster is saturated.
