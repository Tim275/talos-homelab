# Observability Stack - Production Readiness TODO

**Total Effort:** ~3.5 hours | **Status:** 0/11 completed

---

## 🔴 CRITICAL (Priority 1) - ~1.5 hours

**Must complete BEFORE production deployment!**

### ☐ Scale Kibana to 2 replicas for HA
- **File:** `kubernetes/infrastructure/observability/elasticsearch/cluster/kibana.yaml:8`
- **Change:** `count: 1` → `count: 2`
- **Time:** 5 min
- **Impact:** Single point of failure - no log access during pod restart

### ☐ Delete plain secret from git (SECURITY!)
- **File:** `kubernetes/infrastructure/observability/fluentd/elasticsearch-credentials-secret.yaml`
- **Action:** Delete file or convert to SealedSecret
- **Time:** 10 min
- **Impact:** Password exposed in git: `04h26K03zEMhI7I9DRbk5AT5`

### ☐ Create Elasticsearch PodDisruptionBudget
- **File:** New file in `kubernetes/infrastructure/observability/elasticsearch/`
- **Spec:** `minAvailable: 2`
- **Time:** 15 min
- **Impact:** All 3 ES nodes could be evicted during maintenance

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: production-cluster-es-pdb
  namespace: elastic-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      elasticsearch.k8s.elastic.co/cluster-name: production-cluster
```

### ☐ Create Vector Aggregator PodDisruptionBudget
- **File:** New file in `kubernetes/infrastructure/observability/vector/`
- **Spec:** `minAvailable: 1`
- **Time:** 15 min
- **Impact:** Both aggregators could be evicted simultaneously

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vector-aggregator-pdb
  namespace: elastic-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vector
      app.kubernetes.io/component: aggregator
```

### ☐ Create Kibana PodDisruptionBudget
- **File:** New file in `kubernetes/infrastructure/observability/elasticsearch/`
- **Spec:** `minAvailable: 1`
- **Time:** 15 min
- **Impact:** Kibana unavailable during maintenance
- **Note:** Requires Kibana scaled to 2 replicas first!

### ☐ Change Elasticsearch anti-affinity to requiredDuringScheduling
- **File:** `kubernetes/infrastructure/observability/elasticsearch/cluster/elasticsearch-cluster.yaml:59`
- **Change:** `preferredDuringSchedulingIgnoredDuringExecution` → `requiredDuringSchedulingIgnoredDuringExecution`
- **Time:** 10 min
- **Impact:** All 3 ES nodes could land on same physical host

### ☐ Increase Elasticsearch storage from 10Gi to 50Gi per node
- **File:** `kubernetes/infrastructure/observability/elasticsearch/cluster/elasticsearch-cluster.yaml:78`
- **Change:** `storage: 10Gi` → `storage: 50Gi`
- **Time:** 1 hour (includes testing)
- **Impact:** Will run out of space in weeks with production load

---

## 🟡 HIGH (Priority 2) - ~2 hours

**Complete within first month of production**

### ☐ Add NetworkPolicy for Elasticsearch
- **File:** New file in `kubernetes/infrastructure/observability/elasticsearch/`
- **Time:** 30 min
- **Impact:** Elasticsearch exposed to all pods in cluster
- **Allow:** Vector, Kibana, monitoring namespace only

### ☐ Add NetworkPolicy for Vector
- **File:** New file in `kubernetes/infrastructure/observability/vector/`
- **Time:** 30 min
- **Impact:** Vector accessible from any pod
- **Allow:** Monitoring namespace + authorized sources only

### ☐ Add NetworkPolicy for Kibana
- **File:** New file in `kubernetes/infrastructure/observability/elasticsearch/`
- **Time:** 20 min
- **Impact:** Kibana accessible from any pod
- **Allow:** Ingress gateway + operators only

### ☐ Add anti-affinity to Vector Aggregator deployment
- **File:** `kubernetes/infrastructure/observability/vector/vector-aggregator.yaml`
- **Time:** 15 min
- **Impact:** Both aggregator pods could run on same node

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: vector
            app.kubernetes.io/component: aggregator
        topologyKey: kubernetes.io/hostname
```

---

## 📊 Progress Tracking

- **Critical:** 0/7 completed
- **High:** 0/4 completed
- **Total:** 0/11 completed

---

## 📝 Notes

- Vector Agent :nightly tag already fixed in commit "recycle jaeger/opentelemtry"
- Fluentd and Fluent-bit are disabled (correct - no redundancy)
- Backups configured but restore testing missing (medium priority)
- Cert-manager integration for ES TLS (medium priority)

**Last Updated:** 2025-11-19
