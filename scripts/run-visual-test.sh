#!/bin/bash
# A-Z Visual Testing Process for CTO
set -e

echo "Starting E2E Visual Test Process..."
echo "1. Deploying CTO Dashboard ConfigMap to Grafana..."
kubectl apply -f <(terraform output -raw e2e_dashboard_manifest 2>/dev/null || cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: e2e-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  e2e-dashboard.json: |
    {
      "title": "CTO: E2E Visual Testing & Resilience",
      "panels": [
        { "title": "Active Chaos Mesh Experiments", "type": "table", "targets": [{ "expr": "chaos_mesh_experiments{}", "legendFormat": "{{name}}" }], "gridPos": { "h": 10, "w": 12, "x": 0, "y": 0 } },
        { "title": "Frontend Error Rate", "type": "timeseries", "targets": [{ "expr": "sum(rate(grpc_server_handling_seconds_count{job=\"frontend\", grpc_code!=\"OK\"}[1m]))/sum(rate(grpc_server_handling_seconds_count{job=\"frontend\"}[1m])) * 100", "legendFormat": "Error Rate %" }], "gridPos": { "h": 10, "w": 12, "x": 12, "y": 0 } },
        { "title": "Active Prom Alerts", "type": "table", "targets": [{ "expr": "ALERTS{alertstate=\"firing\"}" }], "gridPos": { "h": 10, "w": 24, "x": 0, "y": 10 } }
      ]
    }
EOF
)

echo "✅ CTO E2E Dashboard deployed! Open Grafana to view it."

echo "2. Triggering Chaos Experiment (Recruiter Showcase)..."
kubectl patch workflow recruiter-first-disaster -n chaos-testing --type merge -p '{"spec":{"suspend":false}}' || kubectl apply -f <(cat <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: recruiter-first-disaster
  namespace: chaos-testing
spec:
  entry: the-showcase
  templates:
    - name: the-showcase
      templateType: Serial
      children: ["intro-delay", "visual-cpu-spike"]
    - name: intro-delay
      templateType: NetworkChaos
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces: ["online-boutique"]
          labelSelectors: { "app": "productcatalogservice" }
        delay: { latency: "1000ms" }
    - name: visual-cpu-spike
      templateType: StressChaos
      stressChaos:
        mode: all
        selector:
          namespaces: ["online-boutique"]
          labelSelectors: { "app": "frontend" }
        stressors: { cpu: { workers: 2, load: 80 } }
EOF
)
echo "✅ Active workflow triggered."

echo "3. Monitor GoAlert via the Dashboard for Alerts triggered by Chaos Mesh."
echo "Workflow initialized correctly. You can watch the full A-Z process loop now in Grafana & GoAlert."
