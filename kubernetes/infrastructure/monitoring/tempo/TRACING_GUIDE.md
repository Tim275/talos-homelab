# 🔍 Distributed Tracing Guide - Production Best Practices

## Tempo ist jetzt PRODUCTION-READY! 🎉

Tempo empfängt jetzt Traces über:
- **OTLP gRPC** → `tempo-distributor.monitoring.svc:4317`
- **OTLP HTTP** → `tempo-distributor.monitoring.svc:4318`
- **Jaeger gRPC** → `tempo-distributor.monitoring.svc:14250`

## 📊 **Welche Anwendungen sollte ich tracen?**

### ✅ **EMPFOHLEN: Production Business-Critical Apps**

Diese Apps solltest du **definitiv** tracen:

#### 1. **N8N Production** (`n8n-prod`)
- **Warum?**: Workflows = kritische Business-Logik
- **Was tracen?**:
  - Workflow-Ausführungen (Start bis Ende)
  - Webhook-Empfang
  - API-Calls zu externen Services
  - Fehler in Nodes

#### 2. **Jaeger** (bereits integriert!)
- **Warum?**: Jaeger nutzt Tempo als Backend
- **Status**: Schon deployed! Check: `kubectl get pods -n monitoring -l app.kubernetes.io/name=jaeger`

#### 3. **Kubernetes Infrastructure**
- **Was tracen?**:
  - API Server requests (kube-apiserver)
  - etcd operations
  - kubelet operations
- **Nutzen**: Performance-Bottlenecks finden

### 🔄 **OPTIONAL: Dev/Test Apps**

Diese Apps können traces senden, aber mit **höherem Sampling** (1-10% statt 100%):

#### 1. **Audiobookshelf-dev**
- **Nutzen**: Tracen von Media-Streaming-Problemen
- **Sampling**: 10% (jede 10. Request)

#### 2. **N8N Dev**
- **Nutzen**: Workflow-Entwicklung debuggen
- **Sampling**: 100% (alle Requests) - ist ja nur Dev

### ❌ **NICHT EMPFOHLEN**

- **Grafana selbst**: Monitoring das Monitoring = zu meta
- **Prometheus**: Schon genug Metrics, braucht keine Traces
- **Loki**: Log-Aggregator, kein User-Traffic

---

## 🚀 **Wie aktiviere ich Tracing für meine Apps?**

### **Methode 1: OTLP Instrumentation (Beste Methode)**

Für **Node.js Apps** wie N8N:

```javascript
// package.json
{
  "dependencies": {
    "@opentelemetry/sdk-node": "^0.52.0",
    "@opentelemetry/auto-instrumentations-node": "^0.47.0",
    "@opentelemetry/exporter-trace-otlp-grpc": "^0.52.0"
  }
}

// tracing.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  serviceName: 'n8n-prod',
  traceExporter: new OTLPTraceExporter({
    url: 'http://tempo-distributor.monitoring.svc:4317',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

Dann in `deployment.yaml`:
```yaml
spec:
  containers:
    - name: n8n
      image: n8nio/n8n:latest
      env:
        - name: NODE_OPTIONS
          value: "--require /app/tracing.js"
        - name: OTEL_SERVICE_NAME
          value: "n8n-prod"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://tempo-distributor.monitoring.svc:4317"
```

---

### **Methode 2: Jaeger Client Libraries**

Für **Python/Go/Java Apps**:

```python
# Python Example
from jaeger_client import Config

config = Config(
    config={
        'sampler': {'type': 'const', 'param': 1},  # 100% sampling
        'local_agent': {
            'reporting_host': 'tempo-distributor.monitoring.svc',
            'reporting_port': 6831,
        },
    },
    service_name='my-python-app',
)
tracer = config.initialize_tracer()
```

---

### **Methode 3: Service Mesh (Istio/Linkerd)**

**Automatisches Tracing OHNE Code-Änderungen!**

Falls du Istio installierst:
```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      tracing:
        zipkin:
          address: tempo-distributor.monitoring.svc:9411
        sampling: 100.0  # 100% sampling for production
```

**Vorteile:**
- Zero-Code-Change Tracing
- Automatische Service-to-Service Traces
- HTTP + gRPC Support

---

## 📈 **Sampling Strategies - Production Best Practices**

### **Strategie 1: Tail-based Sampling (EMPFOHLEN für Production)**

Nur **Fehler** und **langsame Requests** speichern:

```yaml
# tempo/values.yaml
tempo:
  overrides:
    defaults:
      # Speichere nur Traces die > 1 Sekunde dauern ODER Fehler haben
      ingestion:
        rate_strategy: global
        rate_limit_bytes: 5000000  # 5 MB/s
      metrics_generator:
        processors:
          - service-graphs
          - span-metrics
        # Nur langsame Traces speichern
        filter_policies:
          - name: slow-traces
            spans_per_second: 100
            policies:
              - name: error-traces
                type: string_attribute
                key: error
                value: "true"
              - name: latency-threshold
                type: numeric_attribute
                key: duration_ms
                min_value: 1000  # > 1 second
```

### **Strategie 2: Head-based Sampling (Einfacher)**

**10% aller Requests** tracen:

```javascript
// Node.js
const sdk = new NodeSDK({
  sampler: new TraceIdRatioBasedSampler(0.1),  // 10% sampling
});
```

---

## 🔍 **Wie finde ich Traces in Grafana?**

1. **Öffne Grafana**: `http://grafana.homelab.local:3000` (oder kubectl port-forward)

2. **Gehe zu Explore**:
   - Wähle Datasource: **Tempo**
   - Query Type: **Search**

3. **Beispiel-Queries**:

   **Alle Traces von N8N:**
   ```
   { service.name="n8n-prod" }
   ```

   **Nur Fehler-Traces:**
   ```
   { service.name="n8n-prod" && status=error }
   ```

   **Langsame Traces (> 1s):**
   ```
   { service.name="n8n-prod" && duration>1s }
   ```

4. **Trace-to-Logs Correlation**:
   - Klicke auf einen Trace
   - Unten: "Logs for this trace span" → Springt automatisch zu Loki!

---

## 🎯 **Quick Start: N8N Production Tracing aktivieren**

### Schritt 1: OTLP Library zu N8N hinzufügen

Wenn N8N in Docker läuft, custom Image builden:

```dockerfile
FROM n8nio/n8n:latest

# Install OpenTelemetry
USER root
RUN npm install -g @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-grpc

# Tracing-Config
COPY tracing.js /app/tracing.js

USER node
ENV NODE_OPTIONS="--require /app/tracing.js"
```

### Schritt 2: Deployment mit OTLP Environment Variables

```yaml
# kubernetes/applications/n8n/prod/deployment.yaml
spec:
  containers:
    - name: n8n
      image: your-registry/n8n:tracing
      env:
        - name: OTEL_SERVICE_NAME
          value: "n8n-prod"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://tempo-distributor.monitoring.svc:4317"
        - name: OTEL_TRACES_SAMPLER
          value: "parentbased_traceidratio"
        - name: OTEL_TRACES_SAMPLER_ARG
          value: "1.0"  # 100% sampling for production critical app
```

### Schritt 3: Deploy und Verifizieren

```bash
# Deploy N8N mit Tracing
kubectl apply -f kubernetes/applications/n8n/prod/

# Warte 30 Sekunden und check Traces
kubectl exec -n grafana deployment/grafana-deployment -- \
  curl -s "http://tempo-query-frontend.monitoring.svc:3200/api/search?tags=service.name%3Dn8n-prod&limit=10"
```

**Expected Output:** JSON mit Trace-IDs von N8N!

---

## 📚 **Links & Resources**

- **OpenTelemetry Docs**: https://opentelemetry.io/docs/languages/
- **Grafana Tempo Docs**: https://grafana.com/docs/tempo/latest/
- **N8N Community Tracing**: https://community.n8n.io/t/opentelemetry-tracing/

---

## 🎉 **Das hast du jetzt:**

✅ **Production-Ready Tempo** mit S3 storage
✅ **30-Tage Retention**
✅ **OTLP + Jaeger Receiver** für alle Protokolle
✅ **Trace-to-Logs Correlation** (Tempo → Loki)
✅ **Trace-to-Metrics** (Service Graphs, Span Metrics)
✅ **Grafana Integration** mit Explorer

**Next Step**: Füge OTLP zu deinen Production-Apps hinzu! 🚀
