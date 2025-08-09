# Troubleshooting Guide

## Storage Issues - Grafana & Loki Pods "Not Enough Free Storage"

### Problem
```
Warning  FailedScheduling  0/6 nodes are available: 6 node(s) did not have enough free storage
```

Grafana und Loki Pods können nicht schedulen obwohl Nodes genug Platz haben.

### Root Cause
Kubernetes default eviction thresholds sind für kleine homelab VMs (20GB disk) zu konservativ:
- Default: 15% reserved = 3GB von 20GB nicht nutzbar
- inotify limits zu niedrig → falsche Storage-Fehler

### Solution

#### 1. Talos Configuration Fix
Erstelle `common.yaml.tftpl` mit optimierten Settings:

```yaml
machine:
  kubelet:
    extraArgs:
      # Sehr relaxierte Thresholds für 20GB Disks  
      eviction-hard: "nodefs.available<1%,imagefs.available<1%,memory.available<100Mi"
      eviction-soft: "nodefs.available<2%,imagefs.available<3%,memory.available<300Mi"
      # Aggressive Image GC
      image-gc-high-threshold: "70"
      image-gc-low-threshold: "50"
      # Minimale Logs für Disk Space
      container-log-max-files: "2"
      container-log-max-size: "5Mi"
  sysctls:
    # KRITISCH: inotify Limits erhöhen (Hauptursache!)
    fs.inotify.max_user_watches: 1048576  # 128x Standard
    fs.inotify.max_user_instances: 8192
```

#### 2. Terraform/Tofu Config Update
In `config.tofu` common.yaml für alle Nodes laden:

```hcl
config_patches = [
  # Common config für ALLE Nodes
  templatefile("${path.module}/machine-config/common.yaml.tftpl", {
    hostname     = each.key
    cluster_name = var.cluster.proxmox_cluster
    node_name    = each.value.host_node
  }),
  # Node-spezifische config...
]
```

#### 3. Apply Changes
```bash
tofu apply -auto-approve
```

#### 4. Verification
```bash
# Prüfe eviction thresholds
kubectl get --raw "/api/v1/nodes/work-00/proxy/configz" | jq '.kubeletconfig.evictionHard'

# Should show:
# {
#   "imagefs.available": "1%",
#   "memory.available": "100Mi", 
#   "nodefs.available": "1%"
# }

# Prüfe verfügbaren Storage
kubectl describe node work-00 | grep ephemeral-storage
# Sollte ~19GB Allocatable zeigen
```

#### 5. Restart Stuck Pods
```bash
# Delete stuck pods to trigger recreation
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana
kubectl delete pod -n monitoring -l app.kubernetes.io/name=loki
```

### Results
- **Vor Fix**: 3GB von 20GB reserviert (15%) = 17GB nutzbar
- **Nach Fix**: 200MB von 20GB reserviert (1%) = 19.8GB nutzbar  
- **Gewinn**: +2.8GB verfügbarer Speicher für Pods!

### Node-Specific Issues

#### work-02 InvalidDiskCapacity
```
Warning  InvalidDiskCapacity  kubelet  invalid capacity 0 on image filesystem
```

**Fix**: Node reboot
```bash
talosctl reboot --nodes=192.168.68.105 --talosconfig=talos-config.yaml
```

### Prevention
- Verwende `common.yaml.tftpl` pattern für shared config
- Monitor Node capacity mit `kubectl describe nodes`
- Set alerts auf ephemeral-storage usage > 80%

---

## Prometheus CRD Annotation Size Error

### Problem
```
CustomResourceDefinition.apiextensions.k8s.io "prometheuses.monitoring.coreos.com" is invalid: 
metadata.annotations: Too long: must have at most 262144 bytes
```

ArgoCD kann die Prometheus Operator CRDs nicht deployen wegen zu großen Annotations (>262KB).

### Root Cause
- Prometheus Operator CRDs haben sehr große OpenAPI Schemas
- ArgoCD client-side apply fügt diese als `last-applied-configuration` annotation hinzu
- Kubernetes hat ein 262144 bytes (256KB) Limit für annotations
- Server-side apply und Replace=true helfen nicht bei ArgoCD

### Ultimate Solution
**Disable CRD installation in Helm Chart und install CRDs manually:**

1. **Install CRDs manually outside ArgoCD:**
```bash
# Install the 6 problematic CRDs directly with server-side apply
curl -s https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.76.1/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml | kubectl apply --server-side -f -
curl -s https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.76.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml | kubectl apply --server-side -f -
curl -s https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.76.1/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml | kubectl apply --server-side -f -
curl -s https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.76.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml | kubectl apply --server-side -f -
curl -s https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.76.1/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml | kubectl apply --server-side -f -
curl -s https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.76.1/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml | kubectl apply --server-side -f -
```

2. **Disable CRD creation in Helm Values:**
```yaml
# In your prometheus values.yaml or ArgoCD Application spec:
prometheus-operator:
  prometheusOperator:
    admissionWebhooks:
      enabled: false
    manageCrds: false
  crds:
    enabled: false
```

3. **Alternative: Skip CRDs in syncOptions:**
```bash
kubectl patch application prometheus -n argocd --type='merge' \
  -p='{"spec":{"syncPolicy":{"syncOptions":["SkipDryRunOnMissingResource=true","CreateNamespace=true"]}}}'
```

### Prevention
- Always install large CRDs outside of ArgoCD
- Use Helm pre-install hooks for CRD management
- Consider CRD lifecycle management tools like Helm CRD plugin

### Background
- This is a known limitation when ArgoCD manages large CRDs
- Server-side apply doesn't work because ArgoCD still uses client-side operations
- The issue affects other operators with large schemas (Istio, Cert-Manager, etc.)

---

## General Debugging Commands

```bash
# Node Storage Status
kubectl describe nodes | grep -A 10 -B 5 "ephemeral-storage"

# Pod Scheduling Events  
kubectl describe pod <pod-name> -n <namespace> | tail -10

# Node Actual Disk Usage
kubectl get --raw "/api/v1/nodes/<node>/proxy/stats/summary" | jq '.node.fs'

# Kubelet Config
kubectl get --raw "/api/v1/nodes/<node>/proxy/configz" | jq '.kubeletconfig'
```