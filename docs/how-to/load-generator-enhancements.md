# How-To: Enhanced Load Generator with Chaos Engineering

> **Operational Guide: v5.1.0**

This guide explains how to use the enhanced load generator with Prometheus metrics, chaos injection, and realistic traffic simulation.

## Overview

The enhanced load generator (`behavioral_loadgen.py`) provides:
- **Prometheus Metrics**: Real-time performance monitoring
- **Chaos Injection**: Simulate HTTP 500s, timeouts, slow responses
- **Multiple Traffic Patterns**: NORMAL, FLASH_SALE, BOT_ATTACK, CHAOS_TEST
- **Realistic Simulation**: Think times, session-based behavior

## Quick Start

### Basic Usage

```bash
# Run with default settings
python3 components/loadgen/behavioral_loadgen.py

# Run with Prometheus metrics
export METRICS_PORT=9090
python3 components/loadgen/behavioral_loadgen.py
```

### Docker Usage

```bash
# Build the load generator
docker build -t ai4all-loadgen -f components/loadgen/Dockerfile.loadgen .

# Run with metrics
docker run -p 9090:9090 \
  -e FRONTEND_ADDR=frontend.online-boutique:80 \
  -e METRICS_PORT=9090 \
  ai4all-loadgen
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FRONTEND_ADDR` | frontend:80 | Frontend service address |
| `METRICS_PORT` | 9090 | Prometheus metrics port |
| `CHAOS_ENABLED` | false | Enable chaos injection |
| `CHAOS_PROBABILITY` | 0.1 | Probability of chaos injection (0.0-1.0) |

### Traffic Patterns

The load generator supports four traffic patterns:

| Mode | Description | Think Time | Concurrency |
|------|-------------|------------|-------------|
| **NORMAL** | Typical user behavior | 0.5-2.0s | 1 user |
| **FLASH_SALE** | High traffic events | 0.1-0.5s | 5 users |
| **BOT_ATTACK** | Automated attacks | 0.01-0.05s | 1 user |
| **CHAOS_TEST** | Resilience testing | 0.5-1.0s | 1 user |

## Prometheus Metrics

### Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `loadgen_requests_total` | Counter | mode, status | Total requests count |
| `loadgen_request_duration_seconds` | Histogram | mode | Request latency |
| `loadgen_active_users` | Gauge | - | Active simulated users |
| `loadgen_error_rate` | Gauge | mode | Error rate percentage |

### Accessing Metrics

```bash
# View raw metrics
curl http://localhost:9090/metrics

# Example output:
# loadgen_requests_total{mode="NORMAL",status="success"} 42
# loadgen_requests_total{mode="NORMAL",status="failure"} 3
# loadgen_request_duration_seconds_bucket{mode="NORMAL",le="0.1"} 10
# loadgen_request_duration_seconds_sum{mode="NORMAL"} 15.5
# loadgen_request_duration_seconds_count{mode="NORMAL"} 42
```

### Grafana Dashboard

Import the load generator dashboard:

```json
{
  "title": "Load Generator Metrics",
  "panels": [
    {
      "title": "Request Rate",
      "targets": [
        "rate(loadgen_requests_total[1m])"
      ]
    },
    {
      "title": "Error Rate",
      "targets": [
        "loadgen_error_rate"
      ]
    },
    {
      "title": "Latency P95",
      "targets": [
        "histogram_quantile(0.95, rate(loadgen_request_duration_seconds_bucket[5m]))"
      ]
    }
  ]
}
```

## Chaos Engineering

### Enable Chaos Injection

```bash
# Enable chaos with 10% probability
export CHAOS_ENABLED=true
export CHAOS_PROBABILITY=0.1

python3 components/loadgen/behavioral_loadgen.py
```

### Chaos Types

The load generator can inject the following chaos:

| Type | Effect | Use Case |
|------|--------|----------|
| `http_500` | Simulate server error | Test error handling |
| `timeout` | 10-second delay | Test timeout handling |
| `slow_response` | 1-3 second delay | Test performance degradation |
| `connection_error` | Connection refused | Test network failures |

### Chaos Testing Workflow

1. **Deploy application** with normal traffic
2. **Enable chaos injection** gradually
3. **Monitor AI Agent response** via metrics
4. **Verify remediation** in logs and dashboards
5. **Analyze results** and adjust thresholds

### Example: Resilience Test

```bash
# 1. Start with normal traffic
python3 components/loadgen/behavioral_loadgen.py &

# 2. Enable chaos after 2 minutes
sleep 120
export CHAOS_ENABLED=true
export CHAOS_PROBABILITY=0.3

# 3. Monitor for 5 minutes
sleep 300

# 4. Check metrics
curl http://localhost:9090/metrics | grep loadgen_error_rate

# 5. Stop load generator
pkill -f behavioral_loadgen.py
```

## Advanced Usage

### Custom User Journey

Modify `simulate_user()` function for custom behavior:

```python
def simulate_custom_user():
    """Custom user journey for specific testing"""
    # 1. Homepage
    requests.get(f"{BASE_URL}/")
    
    # 2. Search products
    requests.get(f"{BASE_URL}/search?q=product")
    
    # 3. Add multiple items to cart
    for product_id in ["P001", "P002", "P003"]:
        requests.post(f"{BASE_URL}/cart", data={"product_id": product_id})
    
    # 4. Apply coupon
    requests.post(f"{BASE_URL}/cart/coupon", data={"code": "SAVE20"})
    
    # 5. Checkout
    requests.post(f"{BASE_URL}/checkout", json={"payment": "card"})
```

### Integration with Chaos Mesh

Combine load generator with Chaos Mesh for advanced chaos:

```yaml
# chaos/loadgen-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: loadgen-cpu-stress
spec:
  mode: one
  selector:
    labelSelectors:
      app: loadgen
  stressors:
    cpu:
      workers: 2
      load: 80
  duration: '5m'
```

### Distributed Load Generation

Run multiple load generators for high-scale testing:

```bash
# Start 3 load generators on different ports
for i in 1 2 3; do
  METRICS_PORT=$((9090 + i)) \
  python3 components/loadgen/behavioral_loadgen.py &
done
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Error Rate**: Should be < 5% under normal conditions
2. **Latency P95**: Should be < 500ms for normal traffic
3. **Throughput**: Requests per second
4. **AI Agent Response Time**: Time to detect and remediate

### Alert Rules

```yaml
# prometheus/alerts.yml
groups:
  - name: loadgen_alerts
    rules:
      - alert: HighErrorRate
        expr: loadgen_error_rate > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Load generator error rate high"
      
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(loadgen_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Request latency exceeds 1s P95"
```

## Testing the AI Agent

### Automated Testing

Use the integration test script:

```bash
# Run full autonomous loop test
./tests/integration/test_autonomous_loop.sh
```

### Manual Testing

1. **Start load generator** in CHAOS_TEST mode
2. **Monitor AI Agent** via `/health` endpoint
3. **Inject specific failures** via kubectl
4. **Verify remediation** in ArgoCD and K8s

### Example Test Scenario

```bash
# 1. Deploy test application
kubectl apply -f tests/integration/test-deployment.yaml

# 2. Start load generator in chaos mode
CHAOS_ENABLED=true CHAOS_PROBABILITY=0.5 \
  python3 components/loadgen/behavioral_loadgen.py &

# 3. Monitor AI agent logs
kubectl logs -f deployment/ai-agent -n observability

# 4. Check circuit breaker state
curl http://localhost:8000/health | jq '.circuit_breakers'

# 5. Verify post-mortem was created
ls -la post-mortems/
```

## Troubleshooting

### Load Generator Not Starting

**Symptoms**: Python script fails to run

**Solutions**:
1. Install dependencies: `pip install requests prometheus_client`
2. Check frontend address: `echo $FRONTEND_ADDR`
3. Verify network connectivity: `curl http://$FRONTEND_ADDR`

### Prometheus Metrics Not Available

**Symptoms**: Cannot access metrics endpoint

**Solutions**:
1. Check port is not in use: `netstat -tlnp | grep 9090`
2. Verify metrics server started: Check logs for "Prometheus metrics server started"
3. Test endpoint: `curl http://localhost:9090/metrics`

### Chaos Injection Not Working

**Symptoms**: No errors being injected

**Solutions**:
1. Verify chaos is enabled: `echo $CHAOS_ENABLED`
2. Check probability: `echo $CHAOS_PROBABILITY` (should be > 0)
3. Run in CHAOS_TEST mode: Check logs for "CHAOS_TEST" mode
4. Monitor for chaos events in logs

## Best Practices

### 1. Start Small
- Begin with low traffic and no chaos
- Gradually increase load and chaos probability
- Monitor application and AI Agent behavior

### 2. Use Realistic Patterns
- Match production traffic patterns
- Include think times between requests
- Simulate real user journeys

### 3. Monitor Everything
- Use Prometheus metrics
- Set up alerting rules
- Review logs after tests

### 4. Clean Up Resources
- Stop load generators after tests
- Clean up test deployments
- Reset chaos configurations

### 5. Document Results
- Record metrics before/after
- Note any failures or issues
- Update runbooks with learnings

## References

- [Source Code: behavioral_loadgen.py](../../components/loadgen/behavioral_loadgen.py)
- [Chaos Mesh Documentation](https://chaos-mesh.org/)
- [Prometheus Metrics](https://prometheus.io/docs/concepts/metric_types/)