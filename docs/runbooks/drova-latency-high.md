# Runbook: Drova p99 Latency High

**Severity:** Warning (P2)
**Trigger:** `DrovaLatencyP99High` — p99 latency >500ms for 5min

## Was ist passiert

Ein Drova-Service braucht für 99% der Requests >500ms. Das deutet auf:
- Slow database queries
- Cache miss spike
- Resource saturation (CPU/Memory)
- External dependency slow

## Sofort-Diagnose

### 1. Latency-Distribution prüfen

```promql
# Welche endpoints sind langsam?
histogram_quantile(0.99,
  sum by (service_name, http_route, le) (
    rate(http_server_request_duration_seconds_bucket{service_name="<SERVICE>"}[5m])
  )
)
```

### 2. Trace-Analyse via Tempo/Jaeger

Jaeger UI → Search → Service → filter `duration > 500ms`
→ Spans mit höchster latency → identify slow downstream call

```promql
# In Grafana via TraceQL:
{ span.service.name = "<SERVICE>" && span.duration > 500ms }
```

### 3. Resource saturation check

```bash
kubectl top pods -n drova --sort-by=cpu
kubectl top pods -n drova --sort-by=memory
```

## Root Causes (häufigste)

### A) Slow DB query
```bash
# CNPG slow-query log
kubectl exec -n drova drova-postgres-1 -- \
  psql -U postgres -c "SELECT query, mean_exec_time, calls FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```
**Fix:** Add index, optimize query, increase connection pool.

### B) Redis cache miss
```bash
# Hit-rate via redis-exporter:
# Grafana → Redis dashboard → "Cache Hit Rate" panel
# If <90%: app-side cache key strategy needs review
```
**Fix:** Review TTL, check eviction policy, increase memory.

### C) Kafka consumer lag (cascade slowdown)
```bash
# Kafka exporter consumer lag panel in Grafana
```
**Fix:** Increase consumer parallelism, scale broker resources.

### D) CPU saturation
```bash
kubectl get pod <pod> -n drova -o jsonpath='{.spec.containers[0].resources.limits}'
# If CPU usage near limit → throttling
kubectl exec <pod> -n drova -- cat /sys/fs/cgroup/cpu.stat | grep throttled
```
**Fix:** Increase CPU limit OR scale replicas horizontally.

### E) External dependency (Stripe API, OpenAI)
- Check Stripe status: https://status.stripe.com
- Tracing-Spans für external HTTP calls

## Verwandte Dashboards

- [Drova Service Detail](https://grafana.timourhomelab.org/d/drova-service-detail)
- [Drova Dependencies](https://grafana.timourhomelab.org/d/drova-dependencies)
- [Tempo Service Performance](https://grafana.timourhomelab.org/explore?orgId=1&left=%5B%22now-1h%22,%22now%22,%22tempo%22)
