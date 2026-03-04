# Explanation: Zero-Touch Trace Correlation 🕵️

To debug a microservices architecture during a production incident, an SRE must know exactly which hop in a distributed system failed. If a user clicks "Checkout" and the request touches five different microservices (`frontend` -> `cartservice` -> `paymentservice`), any one of those hops could cause a 500 error.

The AI4ALL-SRE Laboratory solves this using **OpenTelemetry (OTel)** and **Distributed Tracing**.

---

## 1. The Concept: Traces and Spans

Imagine a trace as a "receipt" for a single user journey (e.g., clicking "Add to Cart").
*   **Trace**: The full end-to-end journey of that user request.
*   **Span**: A single discrete step in that journey (e.g., "Frontend calling CartService took 40ms").

By stitching spans together, the system visualizes a Waterfall graph showing exactly where a request spent its time. If a purchase takes 5 seconds, OTel identifies exactly which microservice caused the 4.9-second bottleneck.

---

## 2. Auto-Instrumentation (The Applications)

Rather than writing custom tracing wrappers for every API route manually, the microservices (`apps/online-boutique`) rely on modern OpenTelemetry SDKs (for Go, Python, Node.js). 

These SDKs automatically wrap HTTP and gRPC calls. When `frontend` makes a gRPC call to `productcatalogservice`, the SDK dynamically injects a `traceparent` HTTP header (the W3C Trace Context standard). The receiving service reads this header, ensuring both microservices record their spans under the exact same Trace ID.

The `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable is injected via a Kustomize patch to direct the telemetry outward.

---

## 3. The OTel Collector (The Shock-Absorber)

The applications do not push traces directly to the Tempo database. If the database crashes, the applications would hang waiting for a TCP timeout, causing a cascading failure.

Instead, the `observability.tf` configures an `opentelemetry-collector` **DaemonSet**. 
1. The microservices blast their telemetry data (via OTLP over gRPC on port 4317) to the local collector on their specific Node.
2. The Collector instantly acknowledges the receipt, freeing the application thread.
3. It batches the traces in memory and reliably forwards them to the **Grafana Tempo** backend.

---

## 4. Platform Trace Correlation (Derived Fields)

How do we link the Tempo Trace to the Loki Pod Logs?

A common (and fatal) SRE mistake is to configure applications to print their `trace_id` as a searchable index label in Loki. 

**The Cardinality Explosion:** If every single HTTP request generated a unique `trace_id` label, the database index would double in size every minute, eventually OOMKilling the Loki database.

Instead, the lab uses a **Zero-Touch Platform Engineering** approach:
1.  **Promtail Pipelines**: The log scraper (`promtail`) parses the raw JSON logs of the microservices and extracts the `http.req.id` field. It renames it generically to `traceID` in the body text (not as an index label).
2.  **Grafana Derived Fields**: The Loki Datasource is configured (via Terraform) with a regex rule (`matcherRegex`). Whenever Grafana sees the word `traceID` inside the raw log payload, it organically transforms it into a clickable UI button that hyper-links straight to the Tempo waterfall graph.

This delivers perfect Trace-to-Log correlation without risking database combustion and without forcing developers to rewrite their code.
