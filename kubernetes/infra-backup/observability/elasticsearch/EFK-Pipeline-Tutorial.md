# EFK Pipeline Tutorial: Creating New Indices and Testing Data Pipeline

## Overview
This tutorial explains how to work with the Talos homelab EFK (Elasticsearch, FluentBit, Fluentd, Kibana) logging stack, create new log indices, and test the data pipeline.

## Architecture
```
FluentBit (DaemonSet) → Fluentd (Deployment) → Elasticsearch → Kibana
      ↓                      ↓                    ↓            ↓
Container logs from     Microservice-aware    Index routing   Visualization
/var/log/containers/    log routing based     based on        & search
                       on namespace          namespace
```

## Current Index Routing Strategy

### 1. Infrastructure Services
- **Namespaces**: `argocd`, `cert-manager`, `sealed-secrets`, `cnpg-system`, `rook-ceph`
- **Index**: `infrastructure-logs-YYYY.MM.DD`
- **Use case**: GitOps, secrets management, storage, databases

### 2. Monitoring & Observability
- **Namespaces**: `monitoring`, `elastic-system`, `observability`
- **Index**: `monitoring-logs-YYYY.MM.DD`
- **Use case**: Prometheus, Grafana, EFK stack itself

### 3. Service Ownership (Microservices)
- **N8N Dev**: `n8n-dev-logs-YYYY.MM.DD`
- **N8N Prod**: `n8n-prod-logs-YYYY.MM.DD`
- **Audiobookshelf Dev**: `audiobookshelf-dev-logs-YYYY.MM.DD`
- **Audiobookshelf Prod**: `audiobookshelf-prod-logs-YYYY.MM.DD`

### 4. Domain-Based Fallbacks
- **Dev Applications**: `applications-dev-logs-YYYY.MM.DD`
- **Prod Applications**: `applications-prod-logs-YYYY.MM.DD`

### 5. Platform Services
- **Namespaces**: `kafka`, `cloudflared`, `cloudbeaver`, `gateway`
- **Index**: `platform-logs-YYYY.MM.DD`

### 6. Catch-All
- **Other Kubernetes logs**: `kubernetes-other-logs-YYYY.MM.DD`
- **Talos host logs**: `talos-logs-YYYY.MM` (monthly rotation)

## How to Add a New Index Route

### Step 1: Edit Fluentd Configuration
Edit `/kubernetes/infra/observability/fluentd/values.yaml`:

```yaml
# Add new route BEFORE existing catch-all routes
# Route X: Your New Service
<match kube.var.log.containers.**_your-namespace_**>
  @type elasticsearch
  @log_level info
  include_tag_key true
  host "#{ENV['ELASTICSEARCH_HOST']}"
  port "#{ENV['ELASTICSEARCH_PORT']}"
  scheme "#{ENV['ELASTICSEARCH_SCHEME']}"
  ssl_verify "#{ENV['ELASTICSEARCH_SSL_VERIFY']}"
  user "#{ENV['ELASTICSEARCH_USERNAME']}"
  password "#{ENV['ELASTICSEARCH_PASSWORD']}"
  reload_connections false
  reconnect_on_error true
  reload_on_failure true
  logstash_format true
  logstash_prefix your-service-logs
  logstash_dateformat %Y.%m.%d
  <buffer>
    @type file
    path /var/log/fluentd-buffers/your-service.buffer
    flush_mode interval
    flush_interval 5s
    chunk_limit_size 2M
    total_limit_size 1G
    overflow_action block
    retry_forever true
    retry_max_interval 30
  </buffer>
</match>
```

### Step 2: Deploy Changes
```bash
# Commit changes
git add kubernetes/infra/observability/fluentd/values.yaml
git commit -m "feat: Add new index routing for your-service"
git push

# ArgoCD will auto-sync or manually sync:
# ArgoCD UI → Applications → observability-fluentd → Sync
```

### Step 3: Verify Deployment
```bash
# Check if Fluentd pods restarted with new config
kubectl get pods -n elastic-system -l app.kubernetes.io/name=fluentd

# Check Fluentd logs for configuration reload
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluentd --tail=20
```

## Testing the Data Pipeline

### Test 1: Generate Test Logs
```bash
# Test logs for your namespace
kubectl run test-your-service --image=busybox --rm -i --restart=Never --namespace=your-namespace -- sh -c "for i in 1 2 3 4 5; do echo 'TEST LOG \$i: Should go to your-service-logs-* index'; sleep 2; done"
```

### Test 2: Verify Index Creation
```bash
# Check if new index was created
kubectl run es-check-your-index --image=curlimages/curl --rm -i --restart=Never -- curl -k -u "elastic:PASSWORD" "https://production-cluster-es-http.elastic-system:9200/_cat/indices/your-service-logs*?v"
```

### Test 3: Search for Your Logs
```bash
# Search for your test logs
kubectl run es-search-your-logs --image=curlimages/curl --rm -i --restart=Never -- curl -k -u "elastic:PASSWORD" "https://production-cluster-es-http.elastic-system:9200/your-service-logs-*/_search?q=TEST&size=5&sort=@timestamp:desc&pretty"
```

### Test 4: Verify in Kibana
1. Access Kibana: `kubectl port-forward svc/production-kibana-kb-http -n elastic-system 5601:5601`
2. Open browser: `https://localhost:5601`
3. Login with `elastic` user and password
4. Go to **Stack Management** → **Index Patterns**
5. Create new index pattern: `your-service-logs-*`
6. Go to **Discover** and view your logs

## Elasticsearch Credentials

### Get Password
```bash
# Get Elasticsearch password
kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d
```

### Environment Variables (for Fluentd)
The pipeline uses these environment variables from the `elasticsearch-credentials` secret:
- `ELASTICSEARCH_HOST`: `production-cluster-es-http.elastic-system`
- `ELASTICSEARCH_PORT`: `9200`
- `ELASTICSEARCH_SCHEME`: `https`
- `ELASTICSEARCH_SSL_VERIFY`: `false`
- `ELASTICSEARCH_USERNAME`: `elastic`
- `ELASTICSEARCH_PASSWORD`: (from ECK operator)

## Common Index Patterns

### By Environment
- `*-dev-logs-*` - All development logs
- `*-prod-logs-*` - All production logs
- `*-staging-logs-*` - All staging logs

### By Service Type
- `infrastructure-logs-*` - Core infrastructure
- `monitoring-logs-*` - Observability stack
- `platform-logs-*` - Platform services
- `application-logs-*` - Application services

### By Team/Domain
- `team-backend-logs-*` - Backend team services
- `team-frontend-logs-*` - Frontend team services
- `team-data-logs-*` - Data team services

## Troubleshooting

### Fluentd Not Receiving Logs
```bash
# Check FluentBit is forwarding to Fluentd
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluent-bit -c fluent-bit --tail=20

# Check Fluentd is listening on port 24224
kubectl run test-fluentd-connection --image=nicolaka/netshoot --rm -i --restart=Never -- nc -zv fluentd.elastic-system.svc.cluster.local 24224
```

### Index Not Created
```bash
# Check Fluentd buffer status
kubectl exec -n elastic-system deployment/fluentd -- ls -la /var/log/fluentd-buffers/

# Check for Elasticsearch connection errors
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluentd --tail=50 | grep ERROR
```

### Wrong Index Routing
```bash
# Verify match patterns are in correct order (most specific first)
kubectl get configmap fluentd-config -n elastic-system -o yaml

# Check if your logs match expected pattern
kubectl logs -n your-namespace your-pod --tail=10
```

## Performance Optimization

### Buffer Tuning
For high-volume services, adjust buffer settings:
```yaml
<buffer>
  @type file
  path /var/log/fluentd-buffers/high-volume-service.buffer
  flush_mode interval
  flush_interval 1s          # Faster flush for real-time
  chunk_limit_size 8M        # Larger chunks
  total_limit_size 5G        # More buffer space
  flush_thread_count 4       # More flush threads
  retry_forever true
  retry_max_interval 30
</buffer>
```

### Index Management
```bash
# Check index sizes
kubectl run es-check-index-sizes --image=curlimages/curl --rm -i --restart=Never -- curl -k -u "elastic:PASSWORD" "https://production-cluster-es-http.elastic-system:9200/_cat/indices?v&s=store.size:desc"

# Set up index lifecycle policies via Kibana
# Stack Management → Index Lifecycle Policies
```

## Best Practices

1. **Namespace Strategy**: Use clear namespace naming (`service-env` pattern)
2. **Index Naming**: Follow consistent patterns (`service-logs-YYYY.MM.DD`)
3. **Route Ordering**: Most specific routes first, catch-all routes last
4. **Buffer Management**: Separate buffers for different log volumes
5. **Monitoring**: Monitor Fluentd metrics and Elasticsearch cluster health
6. **Retention**: Set up index lifecycle management for log retention

## Example: Adding New Microservice

For a new service called "payment-service":

1. **Deploy to namespace**: `payment-prod` and `payment-dev`
2. **Add routes** in `values.yaml`:
   ```yaml
   <match kube.var.log.containers.**_payment-dev_**>
     logstash_prefix payment-dev-logs
   </match>
   <match kube.var.log.containers.**_payment-prod_**>
     logstash_prefix payment-prod-logs
   </match>
   ```
3. **Test with**: `kubectl run test-payment --namespace=payment-dev ...`
4. **Verify indices**: `payment-dev-logs-*` and `payment-prod-logs-*`
5. **Create Kibana dashboards** for payment service logs

This completes the EFK pipeline tutorial for creating new indices and testing the data pipeline in your Talos homelab.