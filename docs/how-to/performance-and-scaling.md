# ⚡ How-To: Performance and Scaling the SRE-MAS
> **Tier-1 Engineering Standard: v4.2.0**

This guide provides technical benchmarks and scaling strategies for the **Autonomous SRE Multi-Agent System (MAS)** as it graduates from laboratory testing to industrial-scale workloads.

---

## 🏎️ Hardware Benchmarking (Ollama)

Inference latency is the primary constraint for MTTR. The following benchmarks are based on the **Llama 3 8B (q4_k_m)** model specialized for SRE tasks.

| Hardware Tier | GPU VRAM | Tokens/Sec | Consensus Latency (Avg) |
| :--- | :--- | :--- | :--- |
| **Edge (Laboratory)** | RTX 3060 (12GB) | ~35 t/s | 35-42 seconds |
| **Industrial Node** | RTX 4090 (24GB) | ~90 t/s | 12-18 seconds |
| **Cloud A100** | A100 (40GB) | ~150 t/s | < 8 seconds |

### 💡 Optimization Tips:
- **KV Cache Quantization**: Enable 8-bit KV caching in Ollama configurations to reduce VRAM pressure by 25%.
- **Num_GPU tuning**: Ensure `num_gpu` is set to utilize all available layers in the Tensor core.

---

## 📈 Scaling the MAS Swarm

As the frequency of cluster events increases, the singleton AI Agent may become a bottleneck. We utilize a **Director-Replica** pattern for scaling.

### 1. Vertical Scaling (Concurrency)
Modify the `ai_agent.py` environment variables to increase worker threads if the GPU has overhead:
```bash
# Increase concurrent specialist threads
export AGENT_THREADS=8
```

### 2. Horizontal Scaling (Load Balancing)
Deploy multiple instances of the AI SRE Agent with a shared persistence layer (Redis/PostgreSQL) to avoid duplicate remediations.

```yaml
# Kubernetes Scaling Example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-sre-agent
spec:
  replicas: 3 # Scaled for high-alert clusters
```

---

## 📊 Monitoring Scaling Health

Use the following Prometheus queries to determine when to scale your inference tier:

- **GPU Utilization**: `sum(container_gpu_utilization) by (pod)` - scale if > 85% sustained.
- **Webhook Queue Depth**: `fastapi_queue_size` - scale if avg queue > 5.
- **Consensus Wait Time**: `ai_agent_consensus_duration_seconds` - alert if > 60s.

---

## 🚀 Predictive Scaling for Model Inference

For Tier-1 infrastructures, we recommend implementing **KEDA (Kubernetes Event-driven Autoscaling)** to scale Ollama pods based on the `prometheus-alert-firing` metric.

```yaml
# KEDA ScaledObject Snippet
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ollama-autoscaler
spec:
  scaleTargetRef:
    name: ollama
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus.observability.svc
      query: sum(ALERTS{alertstate="firing"})
      threshold: '2'
```

---
*Operational Engineering: AI4ALL-SRE Laboratory*
