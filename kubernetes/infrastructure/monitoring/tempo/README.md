# Grafana Tempo - Distributed Tracing

Production-grade distributed tracing backend with S3 (Ceph RGW) storage.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Tempo Architecture                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Applications → OTel Collector → Tempo Distributor         │
│                                      ↓                       │
│                              Tempo Ingester                  │
│                                      ↓                       │
│                              Ceph S3 (RGW)                   │
│                             tempo-traces                     │
│                                      ↓                       │
│  Grafana ← Tempo Query Frontend ← Tempo Querier            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **S3 Backend**: Traces stored in Ceph RGW (like Loki)
- **Multi-Protocol**: Jaeger, Zipkin, OTLP, OpenCensus receivers
- **30-day Retention**: Same as Loki, automatic cleanup via compactor
- **Grafana Integration**: Auto-configured datasource
- **Metrics Generation**: Service graphs & span metrics to Prometheus
- **Trace Correlation**: Links with Loki logs and Prometheus metrics

## Components

| Component | Replicas | Purpose |
|-----------|----------|---------|
| **Distributor** | 1 | Receives traces, load balances to ingesters |
| **Ingester** | 1 | Buffers traces, writes to S3 |
| **Querier** | 1 | Reads traces from S3 |
| **Query Frontend** | 1 | Caches queries, splits requests |
| **Compactor** | 1 | Compacts blocks, enforces retention |
| **Gateway** | 1 | nginx reverse proxy |

## Prerequisites

1. **S3 Bucket**: `tempo-traces` must exist in Ceph RGW
2. **S3 Credentials**: Same as Loki (shared secret)
3. **Storage Class**: `rook-ceph-block-enterprise` for PVCs

## Setup

### 1. Create S3 Bucket

```bash
# Run the bucket creation script
./create-tempo-bucket.sh
```

### 2. Deploy via ArgoCD

```bash
# Apply ArgoCD Application
kubectl apply -f application.yaml

# Wait for deployment
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=tempo -n monitoring --timeout=300s
```

### 3. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Check services
kubectl get svc -n monitoring -l app.kubernetes.io/name=tempo

# Check Grafana datasource
kubectl get cm grafana-datasource-tempo -n monitoring
```

### 4. Test Trace Ingestion

```bash
# Port-forward to Tempo
kubectl port-forward -n monitoring svc/tempo-distributor 4317:4317

# Send test trace via OTLP (gRPC)
# Use your OTLP-compatible client here
```

## Integration with OpenTelemetry

Configure your OpenTelemetry Collector to send traces to Tempo:

```yaml
exporters:
  otlp/tempo:
    endpoint: tempo-distributor.monitoring.svc:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      exporters: [otlp/tempo]
```

## Grafana Integration

The Tempo datasource is auto-configured in Grafana with:

- **Trace-to-Logs**: Click trace → see Loki logs
- **Trace-to-Metrics**: Click trace → see Prometheus metrics
- **Service Map**: Visualize service dependencies
- **Node Graph**: Visualize trace spans

## Endpoints

| Protocol | Port | Endpoint |
|----------|------|----------|
| **OTLP gRPC** | 4317 | `tempo-distributor.monitoring.svc:4317` |
| **OTLP HTTP** | 4318 | `tempo-distributor.monitoring.svc:4318` |
| **Jaeger gRPC** | 14250 | `tempo-distributor.monitoring.svc:14250` |
| **Jaeger Thrift HTTP** | 14268 | `tempo-distributor.monitoring.svc:14268` |
| **Zipkin** | 9411 | `tempo-distributor.monitoring.svc:9411` |
| **Query** | 3100 | `tempo-query-frontend.monitoring.svc:3100` |

## Retention

- **Traces**: 30 days (720h)
- **Blocks**: Compacted every 2h
- **Old Data**: Automatically deleted by compactor

## Resources

### Per Component

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Distributor | 100m | 256Mi | 500m | 1Gi |
| Ingester | 100m | 512Mi | 1000m | 2Gi |
| Querier | 100m | 512Mi | 1000m | 2Gi |
| Query Frontend | 50m | 256Mi | 500m | 1Gi |
| Compactor | 50m | 256Mi | 500m | 1Gi |
| Gateway | 25m | 32Mi | 250m | 256Mi |

### Total

- **CPU**: ~425m requests, ~3.75 limits
- **Memory**: ~1.8Gi requests, ~5.5Gi limits
- **Storage**: 10Gi PVC (ingester only, traces in S3)

## Monitoring

Tempo exports Prometheus metrics via ServiceMonitor:

```bash
# Check metrics in Prometheus
http://prometheus:9090/targets
# Look for: serviceMonitor/monitoring/tempo-*
```

## Troubleshooting

### Pods not starting

```bash
# Check bucket exists
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin bucket stats --bucket=tempo-traces

# Check S3 credentials
kubectl get secret tempo-s3-credentials -n monitoring -o yaml
```

### Traces not appearing

```bash
# Check distributor logs
kubectl logs -n monitoring deploy/tempo-distributor --tail=50

# Check ingester logs
kubectl logs -n monitoring sts/tempo-ingester --tail=50
```

### High memory usage

```bash
# Reduce ingester memory
# Edit values.yaml: ingester.resources.limits.memory
```

## Migration from Jaeger

To migrate from Jaeger to Tempo:

1. Deploy Tempo (this setup)
2. Configure OTel Collector to send to **both** Jaeger and Tempo
3. Verify traces appear in Grafana (Tempo datasource)
4. Gradually migrate queries from Jaeger to Tempo
5. Decommission Jaeger when ready

## Observability Stack

Tempo completes the observability triad:

```
┌───────────┐   ┌────────────┐   ┌───────────┐
│   Loki    │   │ Prometheus │   │   Tempo   │
│  (Logs)   │   │ (Metrics)  │   │ (Traces)  │
└─────┬─────┘   └──────┬─────┘   └─────┬─────┘
      │                │               │
      └────────────────┴───────────────┘
                       │
                  ┌────▼─────┐
                  │  Grafana │
                  │ Unified  │
                  │   View   │
                  └──────────┘
```

All three use Ceph S3 backend for cost-effective long-term storage!

## References

- [Tempo Docs](https://grafana.com/docs/tempo/latest/)
- [Tempo Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/tempo-distributed)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)

---

**Created**: 2025-10-31
**Version**: tempo-distributed v1.23.3
**Author**: Tim275 + Claude
