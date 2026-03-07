# SLO Standards: Online Boutique

This document defines the **Service Level Objectives (SLOs)** and **Service Level Indicators (SLIs)** for the `online-boutique` application.

## 🎯 Global Reliability Targets
| Service | SLO | SLI | Error Budget (Monthly) |
| :--- | :--- | :--- | :--- |
| **All Services** | **99.9% Availability** | Successful request percentage (non-5xx) | ~43 mins downtime |
| **Frontend** | **99.0% Latency < 500ms** | P99 of request duration | ~7.2 hours slow requests |

## 📊 Detailed SLIs by Component

### 🌐 Frontend (Ingress)
- **Target**: 99.9% availability.
- **Measurement**: `sum(rate(http_requests_total{code!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`
- **Criticality**: High. Failure here blocks all user traffic.

### 💾 Checkout Service
- **Target**: 99.99% successful transaction rate.
- **Measurement**: `sum(rate(checkout_processed_total{status="success"}[5m])) / sum(rate(checkout_processed_total[5m]))`
- **Criticality**: Critical. Directly impacts revenue.

### ⚙️ Product Catalog
- **Target**: 99.5% availability.
- **Measurement**: `sum(rate(grpc_server_handled_total{grpc_code="OK", grpc_service="ProductCatalogService"}[5m])) / sum(rate(grpc_server_handled_total{grpc_service="ProductCatalogService"}[5m]))`
- **Criticality**: Medium. Users can still browse cached products if partially down.

## 🛡️ Error Budget Policy
When an Error Budget is **80% consumed**:
1. **Freeze**: All non-emergency production changes are frozen.
2. **Prioritization**: Engineering effort shifts 100% to reliability and technical debt.
3. **Review**: Mandatory Post-Mortem and RCA required to identify systemic issues.

## 🚨 Alerting Thresholds
- **Warning**: Error budget consumption rate > 2x for 1 hour.
- **Critical**: Error budget consumption rate > 10x for 15 minutes.
