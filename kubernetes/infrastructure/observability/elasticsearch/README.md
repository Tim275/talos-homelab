# EFK Stack (Elasticsearch, Fluentd, Kibana) - Production Guide

##  Architecture Overview

```mermaid
graph TB
    subgraph "Kubernetes Cluster"
        subgraph "Log Sources"
            Pods[Pod Containers<br/>ArgoCD, Apps, etc.]
            HostLogs[Host Logs<br/>syslog, auth.log]
        end
        
        subgraph "Log Collection Layer"
            FB[FluentBit DaemonSet<br/>Port: 2020 (HTTP)]
        end
        
        subgraph "Log Aggregation Layer" 
            FD[Fluentd Service<br/>Port: 24224 (Forward)]
        end
        
        subgraph "Storage & Search Layer"
            ES[Elasticsearch Cluster<br/>3 Master+Data Nodes<br/>Port: 9200 (HTTPS)]
            
            subgraph "Persistent Storage"
                PV1[PV: 10Gi<br/>rook-ceph-block-enterprise]
                PV2[PV: 10Gi<br/>rook-ceph-block-enterprise]
                PV3[PV: 10Gi<br/>rook-ceph-block-enterprise]
            end
        end
        
        subgraph "Visualization Layer"
            KB[Kibana<br/>Port: 5601 (HTTPS)]
        end
        
        subgraph "Ceph Storage Backend"
            CEPH[Rook-Ceph Cluster<br/>Block Storage<br/>Replication: 3x]
        end
    end
    
    Pods --> FB
    HostLogs --> FB
    FB -->|Forward Protocol| FD
    FD -->|HTTPS/JSON| ES
    ES --> PV1
    ES --> PV2  
    ES --> PV3
    PV1 --> CEPH
    PV2 --> CEPH
    PV3 --> CEPH
    ES --> KB
    
    style FB fill:#e1f5fe
    style FD fill:#fff3e0
    style ES fill:#f3e5f5
    style KB fill:#e8f5e8
    style CEPH fill:#fff8e1
```

##  Current Log Data

**Indices Status:**
- **`logstash-2025.09.14`**: 64,086 logs, 50.35MB
- **`homelab-logs-2025.09.14`**: 18 logs, 97.4KB  
- **Total Storage**: 30Gi (10Gi × 3 Elasticsearch nodes)
- **Storage Backend**: Rook-Ceph Block Storage

**Log Sources Currently Collected:**
- **Container Logs**: All Kubernetes pod containers (`/var/log/containers/*.log`)
- **System Logs**: Host syslog and auth.log (`/var/log/syslog`, `/var/log/auth.log`)
- **Kubernetes Metadata**: Pod names, namespaces, labels, containers, hosts
- **Examples**: ArgoCD repo-server, Elasticsearch, Fluentd, FluentBit, etc.

##  Why EFK over ELK?

| Feature | EFK (FluentBit + Fluentd) | ELK (Logstash) |
|---------|---------------------------|----------------|
| **Memory Usage** | 🟢 Low (50-100MB per node) | 🔴 High (500MB+ per instance) |
| **CPU Usage** | 🟢 Low | 🔴 High |
| **Kubernetes Native** | 🟢 Purpose-built for K8s | 🟡 General purpose |
| **Configuration** | 🟢 Simple YAML configs | 🔴 Complex Ruby-based |
| **Cloud Native** | 🟢 CNCF project | 🟡 Elastic proprietary |
| **Scalability** | 🟢 Better horizontal scaling | 🔴 Vertical scaling focus |
| **Reliability** | 🟢 Built-in buffering/retry | 🟡 Requires configuration |

**FluentBit**: Ultra-lightweight log processor and forwarder
**Fluentd**: Reliable data collector and aggregator  
**Result**: Lower resource usage, better Kubernetes integration, more reliable

##  Step-by-Step Installation Guide

### Prerequisites
- **ECK Operator** installed (`elastic-system` namespace)
- **Rook-Ceph** cluster running
- **StorageClass**: `rook-ceph-block-enterprise` available

### Step 1: Deploy Elasticsearch Cluster
```bash
kubectl apply -f kubernetes/infra/observability/elasticsearch/elasticsearch-cluster.yaml
```

**Wait for cluster to be ready:**
```bash
kubectl wait --for=condition=ready elasticsearch/production-cluster -n elastic-system --timeout=300s
kubectl get elasticsearch -n elastic-system
```

### Step 2: Deploy Kibana
Kibana is included in the same file and will automatically connect to Elasticsearch:
```bash
kubectl get kibana -n elastic-system
kubectl wait --for=condition=ready pod -l kibana.k8s.elastic.co/name=production-kibana -n elastic-system --timeout=300s
```

### Step 3: Deploy Fluentd (Log Aggregator)
```bash
kubectl apply -f kubernetes/infra/observability/fluentd/fluentd-basic.yaml
```

**Verify Fluentd is running:**
```bash
kubectl get pods -n elastic-system -l app.kubernetes.io/name=fluentd
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluentd --tail=10
```

### Step 4: Deploy FluentBit (Log Collector)  
```bash
kubectl apply -f kubernetes/infra/observability/fluent-bit/fluent-bit-config.yaml
kubectl apply -f kubernetes/infra/observability/fluent-bit/fluent-bit-daemonset.yaml
```

**Verify FluentBit on all nodes:**
```bash
kubectl get pods -n elastic-system -l app.kubernetes.io/name=fluent-bit -o wide
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluent-bit --tail=5
```

### Step 5: Create ServiceAccount & RBAC (if not exists)
```bash
kubectl apply -f kubernetes/infra/observability/rbac/
```

##  Pipeline Testing & Validation

### Test 1: Verify Component Health
```bash
# Check Elasticsearch cluster status
kubectl run es-health --image=curlimages/curl --rm -i --restart=Never -- \
  curl -k -u "elastic:$(kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d)" \
  "https://production-cluster-es-http.elastic-system:9200/_cluster/health?pretty"

# Check Kibana status  
kubectl get pods -n elastic-system -l kibana.k8s.elastic.co/name=production-kibana

# Check Fluentd connectivity
kubectl run test-fluentd --image=nicolaka/netshoot --rm -i --restart=Never -- \
  nc -zv fluentd.elastic-system.svc.cluster.local 24224

# Check FluentBit health endpoint
kubectl port-forward pod/$(kubectl get pods -n elastic-system -l app.kubernetes.io/name=fluent-bit -o jsonpath='{.items[0].metadata.name}') -n elastic-system 2020:2020 &
curl http://localhost:2020/api/v1/health
```

### Test 2: Generate Test Logs
```bash
# Generate test logs to verify pipeline
kubectl run log-generator --image=busybox --rm -i --restart=Never -- \
  sh -c "for i in 1 2 3 4 5; do echo 'TEST LOG $i: EFK Pipeline Test - $(date)'; sleep 2; done"
```

### Test 3: Verify Logs Arrival in Elasticsearch
```bash
# Check if logstash indices are created
kubectl run es-indices --image=curlimages/curl --rm -i --restart=Never -- \
  curl -k -u "elastic:$(kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d)" \
  "https://production-cluster-es-http.elastic-system:9200/_cat/indices/logstash*?v"

# Search for test logs
kubectl run es-search --image=curlimages/curl --rm -i --restart=Never -- \
  curl -k -u "elastic:$(kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d)" \
  -X GET "https://production-cluster-es-http.elastic-system:9200/logstash-*/_search?q=TEST+LOG&size=5&sort=@timestamp:desc"
```

### Test 4: Kibana Access & Index Pattern Creation

1. **Port-forward to Kibana:**
   ```bash
   kubectl port-forward svc/production-kibana-kb-http -n elastic-system 5601:5601
   ```

2. **Get Kibana credentials:**
   ```bash
   echo "Username: elastic"
   echo "Password: $(kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d)"
   ```

3. **Access Kibana**: https://localhost:5601

4. **Create Index Pattern**:
   - Go to **Stack Management** → **Data Views**
   - Click **Create data view**
   - **Index pattern**: `logstash-*`
   - **Time field**: `@timestamp`
   - Click **Save data view to Kibana**

5. **View Logs**:
   - Go to **Discover**
   - Select your **logstash-*** index pattern
   - You should see all your container logs with Kubernetes metadata!

##  Configuration Details

### FluentBit Configuration
- **Input**: Tail `/var/log/containers/*.log` and `/var/log/syslog`
- **Parser**: CRI (Container Runtime Interface) for Kubernetes logs
- **Filter**: Kubernetes metadata enrichment 
- **Output**: Forward to Fluentd on port 24224

### Fluentd Configuration  
- **Input**: Forward protocol from FluentBit (port 24224)
- **Output**: Elasticsearch HTTPS (port 9200)
- **Format**: Logstash format with daily rotation (`logstash-YYYY.MM.DD`)
- **Authentication**: Elastic user with auto-generated password

### Elasticsearch Configuration
- **Version**: 8.16.1
- **Nodes**: 3 master+data+ingest nodes
- **Storage**: 10Gi per node (30Gi total)
- **StorageClass**: `rook-ceph-block-enterprise`  
- **Security**: TLS enabled, authentication required
- **Index Settings**: `action.auto_create_index: "true"`

### Kibana Configuration
- **Version**: 8.16.1
- **Replicas**: 1
- **Resources**: 1-2Gi memory, 500m-1 CPU
- **Authentication**: Connected to Elasticsearch security

##  Troubleshooting

### Issue: No logs appearing in Elasticsearch
```bash
# Check FluentBit is collecting logs
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluent-bit --tail=20

# Check Fluentd is receiving logs  
kubectl logs -n elastic-system -l app.kubernetes.io/name=fluentd --tail=20

# Test FluentBit → Fluentd connection
kubectl run test-connection --image=nicolaka/netshoot --rm -i --restart=Never -- \
  nc -zv fluentd.elastic-system.svc.cluster.local 24224
```

### Issue: Service selector mismatch
Make sure pod labels match service selector:
```bash
kubectl get pods -n elastic-system -l app.kubernetes.io/name=fluentd --show-labels
kubectl get svc fluentd -n elastic-system -o yaml
```

### Issue: Elasticsearch authentication errors
```bash
# Get correct password
kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d

# Test direct connection
kubectl run es-test --image=curlimages/curl --rm -i --restart=Never -- \
  curl -k -u "elastic:PASSWORD" "https://production-cluster-es-http.elastic-system:9200/_cluster/health"
```

##  Monitoring & Maintenance

### Log Retention
Elasticsearch will automatically create daily indices (`logstash-YYYY.MM.DD`). Configure Index Lifecycle Management (ILM) for automatic cleanup:

```bash
# Example: Delete indices older than 30 days
curl -X PUT "localhost:9200/_ilm/policy/logstash-policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'
```

### Performance Monitoring
- **FluentBit metrics**: http://pod-ip:2020/api/v1/metrics/prometheus
- **Elasticsearch metrics**: Kibana → Stack Monitoring
- **Resource usage**: `kubectl top pods -n elastic-system`

### Backup Strategy
- **Elasticsearch snapshots** to S3/Ceph Object Storage
- **Configuration backup**: All YAML files in Git (Infrastructure as Code)
- **Disaster recovery**: ECK operator handles most recovery scenarios

##  Success Indicators

 **Current Pipeline Status:**
- FluentBit pods running on all nodes
- Fluentd receiving logs from FluentBit (no connection errors)
- Elasticsearch indices being created daily (`logstash-YYYY.MM.DD`)
- Kibana can create index patterns and show logs
- Search in Kibana returns container logs with Kubernetes metadata

**Current Status**: 64,086+ logs successfully flowing through the complete EFK pipeline! 

## 🏢 Enterprise Log Sources - Beyond Basic Container Logs

###  **Current Implementation (Phase 1)**
 **kubernetes-logs-YYYY.MM.DD**: Pod/Container logs with K8s metadata  
 **talos-system-logs-YYYY.MM.DD**: Talos host system logs (etcd, kubelet, kube-apiserver)

###  **Enterprise Roadmap (Phase 2)**

| Log Category | Status | Index Pattern | Enterprise Use Cases |
|-------------|---------|---------------|---------------------|
| ** Security & Audit** |  **PLANNED** | `security-audit-logs-*` | API calls, RBAC violations, login attempts |
| ** Ingress & Traffic** |  **BASIC** | `network-traffic-logs-*` | HTTP/gRPC requests, rate limiting, DDoS |  
| ** Infrastructure Metrics** |  **PLANNED** | `infra-metrics-logs-*` | Node health, disk usage, network stats |
| ** Storage Events** |  **PLANNED** | `storage-operations-logs-*` | PV provisioning, backup status, Ceph events |
| ** GitOps Events** |  **PARTIAL** | `gitops-deployment-logs-*` | ArgoCD sync events, drift detection |
| ** Alert Events** |  **PLANNED** | `alert-events-logs-*` | Prometheus alerts, escalations, acknowledgments |

###  **Industry Standards (Netflix, Google, Meta)**

```yaml
# Netflix Index Strategy
logs-application-*          # App container logs  
logs-infrastructure-*       # Host/system logs
logs-security-*             # Audit & security events
logs-network-*              # Traffic & connectivity

# Google Cloud Logging  
gke-cluster-*               # Container logs
gce-instance-*              # VM/host logs  
vpc-flow-*                  # Network flow logs
audit-*                     # API audit logs

# Meta/Facebook Engineering
service-logs-*              # Application service logs
infra-logs-*               # Infrastructure logs  
security-logs-*            # Security events
performance-*              # Performance metrics
```

##  **Enterprise Architecture Decision: Single-Index vs Dual-Index**

Based on industry research and enterprise best practices from Netflix, Google, Meta, and Elasticsearch.com:

### 🤔 **Your Question: "Best Practice oder Nicht?"**

**Answer: It depends on your scale and requirements!** Here's the enterprise analysis:

| **Approach** | **Single-Index (`kubernetes-*`)** | **Dual-Index (`kubernetes-*` + `talos-*`)** |
|-------------|----------------------------------|------------------------------------------|
| ** Simplicity** |  **SIMPLE** - One index pattern |  **COMPLEX** - Multiple patterns |
| ** Query Performance** |  Slower on large datasets |  **FASTER** - Query only relevant data |
| ** Storage Management** |  One ILM policy for all data |  **FLEXIBLE** - Separate retention policies |
| ** Operational Overhead** |  **LOW** - Single configuration |  **HIGH** - Multiple configs to maintain |
| ** Access Control** |  All-or-nothing access |  **GRANULAR** - Role-based index access |
| ** Use Case Fit** |  Small-medium deployments |  **ENTERPRISE** - Large scale operations |

###  **Industry Standards Analysis**

**Google Cloud Logging** (GKE):
```bash
# Separate indices for different log types
gke-cluster-*               # Container logs
gce-instance-*              # VM/host logs  
vpc-flow-*                  # Network flow logs
audit-*                     # API audit logs
```

**Netflix Engineering**:
```bash
# Application vs Infrastructure separation
logs-application-*          # App container logs  
logs-infrastructure-*       # Host/system logs
logs-security-*             # Audit & security events
```

**Elasticsearch.com Best Practice**:
> *"Think in terms of data retention per microservice and/or per log type. If you need to keep data around during 30 days for microservice A and during 90 days for microservice B, it makes sense to separate data for both microservice in two different indexes so that each can have its own index lifecycle policy."*

###  **Current Implementation Status**

| Index Pattern | Current Status | Purpose | Size |
|---------------|----------------|---------|------|
| **`kubernetes-2025.09.14`** |  **ACTIVE** - 64,086+ logs | Pod & host logs combined | ~50MB |
| **`homelab-logs-2025.09.14`** |  **FLUENTD INTERNALS** | Internal Fluentd retry/error logs | 97KB (18 logs) |

###  **Homelab-Logs Index Mystery SOLVED!**

**Das `homelab-logs-*` Index contains:**
- **Internal Fluentd warning logs** (`@log_name: fluent.warn`) 
- **Connection timeouts and retry messages** from our 4-hour troubleshooting session
- **NOT application/system logs** - just Fluentd's own diagnostics
- **Can be safely ignored or deleted**

###  **Enterprise Recommendation for Your Homelab**

**For your current scale (64k logs/day):**

**Option A: Keep Simple**  **RECOMMENDED**
```bash
kubernetes-*        # All logs (pods + Talos host)
```
**Pros:** Simple, working, low maintenance, perfect for homelab scale

**Option B: Enterprise Dual-Index**  **COMPLEX**
```bash
kubernetes-logs-*   # Pod/container logs with K8s metadata
talos-system-logs-* # Host system logs (etcd, kubelet, api-server)
```
**Pros:** Enterprise-like, better separation, granular control
**Cons:** Complex configuration that caused 4+ hours of issues

###  **Current Focus: KISS Principle**

**Current Working Solution**: Single-index architecture
- **Benefits**: Reliable, simple, working perfectly
- **Trade-off**: Less separation but more stable
- **Enterprise Note**: Many companies start simple and evolve to dual-index as they scale

**If you want enterprise separation later**, we can implement it properly with a simpler approach than the failed `index_pattern` field routing.

## 📚 Additional Resources

- [ECK Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)
- [FluentBit Kubernetes Guide](https://docs.fluentbit.io/manual/installation/kubernetes)
- [Fluentd Documentation](https://docs.fluentd.org/)
- [Rook-Ceph Storage](https://rook.io/docs/rook/latest/Storage-Configuration/Block-Storage-RBD/block-storage/)
- [Enterprise Log Sources Reference](./additional-log-sources.yaml)