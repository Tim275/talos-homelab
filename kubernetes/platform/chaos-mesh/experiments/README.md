# 🔥 Chaos Engineering Experiments

This directory contains chaos experiments to test system resilience.

## 🎯 **What is Chaos Engineering?**

**Definition**: "Discipline of experimenting on a system to build confidence in its capability to withstand turbulent conditions in production."

**Origin**: Netflix's Chaos Monkey (kills random production instances daily!)

**Goal**: Find weaknesses BEFORE they cause outages!

---

## 📋 **Available Experiments**

### 1. **Pod Kill Chaos** (`pod-kill-n8n-dev.yaml`)
**What**: Randomly kills N8N pods every 5 minutes
**Why**: Test if N8N recovers automatically
**Expected**: Pod restarts, no data loss, workflow continues

### 2. **Network Delay** (`network-delay-postgres.yaml`)
**What**: Adds 100ms latency to Postgres connections
**Why**: Test if apps handle slow database
**Expected**: Queries slower but no errors

### 3. **Network Partition** (`network-partition-kafka.yaml`)
**What**: Isolates Kafka broker from network
**Why**: Test if Kafka cluster handles split-brain
**Expected**: Kafka fails over to other brokers

### 4. **CPU Stress** (`cpu-stress-n8n.yaml`)
**What**: Max out CPU on N8N pod
**Why**: Test if autoscaling kicks in
**Expected**: HPA creates more replicas

### 5. **Memory Stress** (`memory-stress-boutique.yaml`)
**What**: Fill memory until OOMKilled
**Why**: Test if service recovers from OOM
**Expected**: Pod restarts, LoadBalancer routes to healthy pods

### 6. **IO Chaos** (`io-delay-ceph.yaml`)
**What**: Slow down Ceph RBD disk I/O
**Why**: Test if apps handle slow storage
**Expected**: Longer save times but no crashes

### 7. **DNS Chaos** (`dns-failure-external.yaml`)
**What**: Break DNS for external APIs (api.openai.com)
**Why**: Test if N8N handles DNS failures
**Expected**: N8N workflows fail gracefully with error messages

---

## 🚀 **How to Run Experiments**

### **Option 1: Manual One-Time Test**
```bash
# Apply experiment
kubectl apply -f experiments/pod-kill-n8n-dev.yaml

# Watch chaos happen
kubectl get podchaos -n chaos-mesh --watch

# Check N8N recovery
kubectl get pods -n n8n-dev --watch

# Delete experiment when done
kubectl delete -f experiments/pod-kill-n8n-dev.yaml
```

### **Option 2: Scheduled Chaos (Production!)**
```yaml
# Edit experiment to add schedule
spec:
  scheduler:
    cron: "@every 1h"  # Run every hour!
```

### **Option 3: Chaos Dashboard UI**
```bash
# Port-forward dashboard
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333

# Open: http://localhost:2333
# Create experiments via UI!
```

---

## 📊 **Experiment Lifecycle**

1. **Inject** → Chaos Mesh injects failure
2. **Monitor** → Prometheus + Grafana show impact
3. **Recover** → System should auto-heal
4. **Learn** → Document what broke (if anything!)

---

## 🔧 **Safety Guidelines**

### ✅ **Safe to Run:**
- Pod kill in **dev** namespaces (`n8n-dev`, `boutique-dev`)
- Network delays < 500ms
- CPU stress < 80%

### ⚠️ **Be Careful:**
- Pod kill in **prod** namespaces (test backup/restore!)
- Network partitions (can cause split-brain!)
- Disk failures (test Velero backups!)

### 🚨 **NEVER DO:**
- Kill all replicas at once (use `mode: one`)
- Permanent failures without timeout (always set `duration: 2m`)
- Chaos in `kube-system` or `istio-system`

---

## 📈 **Monitoring Chaos**

### **Grafana Dashboards:**
```
- Pod Restart Count: kubernetes/k8s-views-pods
- Network Latency: istio/istio-performance
- CPU/Memory: kubernetes/k8s-views-nodes
```

### **Prometheus Queries:**
```promql
# Pod restarts during chaos
increase(kube_pod_container_status_restarts_total{namespace="n8n-dev"}[5m])

# Network latency
histogram_quantile(0.99, http_request_duration_seconds_bucket)

# CPU usage during stress test
rate(container_cpu_usage_seconds_total{namespace="n8n-dev"}[5m])
```

### **Alerts (Robusta):**
- Check Discord for crash alerts
- Check Keep UI for pod failures

---

## 🎓 **Learning Outcomes**

After running these experiments, you'll know:
- ✅ Does N8N handle pod kills gracefully?
- ✅ Can Kafka survive broker failures?
- ✅ Do apps timeout correctly with slow database?
- ✅ Does HPA autoscale under CPU stress?
- ✅ Can Velero restore after disk failure?
- ✅ Do workflows fail gracefully with external API down?

---

## 🏆 **Advanced Chaos Patterns**

### **1. Chaos Schedule (GameDay)**
```bash
# Every Friday 10 AM = Chaos Hour!
spec:
  scheduler:
    cron: "0 10 * * FRI"
```

### **2. Blast Radius Control**
```yaml
# Only affect 10% of pods
spec:
  mode: fixed-percent
  value: "10"
```

### **3. Conditional Chaos (only if healthy)**
```yaml
# Only run chaos if no alerts firing
spec:
  conditions:
    - type: AlertsQuiet
      threshold: 0
```

---

## 📚 **Resources**

- [Chaos Mesh Docs](https://chaos-mesh.org/docs/)
- [Netflix Chaos Engineering](https://netflixtechblog.com/tagged/chaos-engineering)
- [Principles of Chaos](https://principlesofchaos.org/)
- [CNCF Chaos Engineering Landscape](https://landscape.cncf.io/card-mode?category=chaos-engineering)

---

**Remember**: "Hope is not a strategy" - Test failures BEFORE production! 🔥
