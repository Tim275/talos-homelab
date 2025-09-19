# Cluster Expansion Plan

## Current Infrastructure Status

### Node 1: MINISFORUM MS-A2 (msa2proxmox)
- **CPU**: 32 cores (AMD Ryzen 9 9955HX, up to 5.4 GHz)
- **RAM**: 96 GB DDR5
- **Current Usage**: 80.38% RAM 🔴 **CRITICAL**
- **Role**: **AI/ML POWERHOUSE** for Kubeflow

### Node 2: NiPoGi AM21 (nipogi)
- **CPU**: 16 cores (AMD Ryzen 9 6900HX, up to 4.9 GHz)
- **RAM**: Currently 32 GB → **Upgrade to 128 GB**
- **Current Usage**: 79.28% RAM 🔴 **CRITICAL**
- **Role**: **Infrastructure + StatefulSets**

## Problem Analysis

Both nodes are hitting **RAM limits at ~80%**, which causes:
- Resource pressure on StatefulSets (Postgres, MongoDB, Elasticsearch)
- AI/ML workloads competing for memory
- Potential OOMKills and service instability

## Expansion Strategy

### Phase 1: nipogi RAM Upgrade (128 GB)

**Recommended VM Split - Option B (Role-Based):**

#### VM 1: worker-01 (nipogi-infra)
- **Resources**: 48 GB RAM, 6 CPU
- **Role**: Infrastructure & Monitoring
- **Workloads**:
  - ArgoCD, Monitoring, Cilium
  - Infrastructure services
  - Control plane components (if HA setup)
  - System daemonsets

#### VM 2: worker-02 (nipogi-database)
- **Resources**: 80 GB RAM, 10 CPU
- **Role**: StatefulSets & Databases
- **Workloads**:
  - CloudNative PostgreSQL clusters
  - MongoDB, Redis, Elasticsearch
  - Persistent storage workloads
  - Database-intensive applications

#### VM 3-6: worker-3 to worker-6 (msa2-ai)
- **Resources**: 24 GB RAM each, 8 CPU each (96 GB total, 32 CPU total)
- **Role**: AI/ML Compute Powerhouse
- **Workloads**:
  - Kubeflow pipelines and training
  - Jupyter notebooks and ML experiments
  - GPU-accelerated workloads (future)
  - Batch processing and model inference

### Node Taints & Tolerations Strategy

```yaml
# nipogi-infra node (worker-01)
taints:
  - key: "node-role"
    value: "infrastructure"
    effect: "NoSchedule"

# nipogi-database node (worker-02)
taints:
  - key: "node-role"
    value: "database"
    effect: "NoSchedule"

# msa2-ai nodes (worker-3 to worker-6)
taints:
  - key: "node-role"
    value: "ai-compute"
    effect: "NoSchedule"
```

**Pod Placement:**
- **Infrastructure pods**: Tolerate "infrastructure" taint (ArgoCD, Monitoring)
- **Database pods**: Tolerate "database" taint (PostgreSQL, MongoDB, Redis)
- **AI/ML pods**: Tolerate "ai-compute" taint (Kubeflow, Jupyter, Training)
- **General apps**: Schedule on any available node

### Phase 2: Future Expansion (Optional)

#### Additional Specialized Nodes
- **GPU Node**: For CUDA workloads, inference
- **Storage Node**: High-IOPS NVMe for databases
- **Edge Node**: ARM-based for IoT/edge workloads

## Implementation Steps

### 1. Tofu Configuration Updates
```hcl
# Add to tofu/main.tf
resource "proxmox_vm_qemu" "nipogi_infra" {
  name        = "nipogi-infra"
  target_node = "nipogi"
  memory      = 49152  # 48 GB
  cores       = 6
  # ... rest of config
}

resource "proxmox_vm_qemu" "nipogi_workloads" {
  name        = "nipogi-workloads"
  target_node = "nipogi"
  memory      = 81920  # 80 GB
  cores       = 10
  # ... rest of config
}
```

### 2. Talos Node Bootstrap
```bash
# Generate new machine configs
talosctl gen config --with-docs=false talos-homelab https://192.168.68.50:6443

# Apply configs to new VMs
talosctl apply-config --insecure -n 192.168.68.XX -f nipogi-infra.yaml
talosctl apply-config --insecure -n 192.168.68.XX -f nipogi-workloads.yaml

# Bootstrap nodes
talosctl bootstrap -n 192.168.68.XX
```

### 3. Kubernetes Integration
```bash
# Add node labels for nipogi
kubectl label node worker-01 node-role.kubernetes.io/infrastructure=""
kubectl label node worker-02 node-role.kubernetes.io/database=""

# Add node labels for msa2
kubectl label node worker-3 node-role.kubernetes.io/ai-compute=""
kubectl label node worker-4 node-role.kubernetes.io/ai-compute=""
kubectl label node worker-5 node-role.kubernetes.io/ai-compute=""
kubectl label node worker-6 node-role.kubernetes.io/ai-compute=""

# Add taints for workload isolation
kubectl taint node worker-01 node-role=infrastructure:NoSchedule
kubectl taint node worker-02 node-role=database:NoSchedule
kubectl taint node worker-3 node-role=ai-compute:NoSchedule
kubectl taint node worker-4 node-role=ai-compute:NoSchedule
kubectl taint node worker-5 node-role=ai-compute:NoSchedule
kubectl taint node worker-6 node-role=ai-compute:NoSchedule
```

### 4. Workload Migration
- **Drain old nipogi node** gracefully
- **Update Helm values** with node selectors
- **Redeploy StatefulSets** on new compute nodes
- **Migrate AI/ML workloads** to dedicated resources

## Benefits

✅ **Resource Isolation**: Infrastructure vs workloads separation
✅ **Kubeflow Ready**: Dedicated resources for AI/ML
✅ **StatefulSet Stability**: Consistent performance for databases
✅ **Scalability**: Easy to add specialized nodes
✅ **Monitoring**: Better resource attribution and alerting

## Timeline

- **Week 1**: Hardware upgrade (nipogi → 128 GB)
- **Week 2**: Tofu config updates and VM creation
- **Week 3**: Talos bootstrap and cluster integration
- **Week 4**: Workload migration and testing

## Resource Allocation Summary

| Node | Role | RAM | CPU | Primary Workloads |
|------|------|-----|-----|-------------------|
| ctrl-0 (nipogi) | Control Plane | 16 GB | 6 | Kubernetes control plane |
| worker-01 (nipogi) | Infrastructure | 48 GB | 6 | ArgoCD, Monitoring, Cilium |
| worker-02 (nipogi) | Database | 80 GB | 10 | PostgreSQL, MongoDB, Redis |
| worker-3 (msa2) | AI/ML Compute | 24 GB | 8 | Kubeflow, ML Training |
| worker-4 (msa2) | AI/ML Compute | 24 GB | 8 | Jupyter, ML Experiments |
| worker-5 (msa2) | AI/ML Compute | 24 GB | 8 | Model Inference |
| worker-6 (msa2) | AI/ML Compute | 24 GB | 8 | Batch Processing |

**Total Cluster**: 240 GB RAM, 54 CPU cores