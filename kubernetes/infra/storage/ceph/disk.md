# Ceph OSD Disk Configuration Guide

## 🔧 AKTUELLER ZUSTAND (Broken)

```
┌─────────────────┬─────────────────┬─────────────────┐
│   work-01       │   work-02       │   work-03       │
├─────────────────┼─────────────────┼─────────────────┤
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │
│ │scsi0 (40GB) │ │ │scsi0 (40GB) │ │ │scsi0 (40GB) │ │
│ │Talos OS     │ │ │Talos OS     │ │ │Talos OS     │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │
│                 │                 │                 │
│ ❌ Keine OSD    │ ❌ Keine OSD    │ ❌ Keine OSD    │
└─────────────────┴─────────────────┴─────────────────┘
```

**Resultat:**
```
Ceph Cluster Status: ❌ NO OSDs
├── MON Pods: ✅ Running  
├── MGR Pods: ✅ Running  
├── OSD Pods: ❌ NONE     
└── Storage Pools: ❌ Progressing/Failed

Kafka PVCs: ❌ Pending (No storage available!)
```

## 🚀 NACH DISK HINZUFÜGUNG (Working)

```
┌─────────────────┬─────────────────┬─────────────────┐
│   work-01       │   work-02       │   work-03       │
├─────────────────┼─────────────────┼─────────────────┤
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │
│ │scsi0 (40GB) │ │ │scsi0 (40GB) │ │ │scsi0 (40GB) │ │
│ │Talos OS     │ │ │Talos OS     │ │ │Talos OS     │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │
│                 │                 │                 │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │
│ │scsi1 (50GB) │ │ │scsi1 (50GB) │ │ │scsi1 (50GB) │ │
│ │Ceph OSD     │ │ │Ceph OSD     │ │ │Ceph OSD     │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │
│                 │                 │                 │
│ ✅ OSD Pod     │ ✅ OSD Pod     │ ✅ OSD Pod     │
└─────────────────┴─────────────────┴─────────────────┘
```

**Resultat:**
```
Ceph Cluster Status: ✅ HEALTHY
├── MON Pods: ✅ Running  
├── MGR Pods: ✅ Running  
├── OSD Pods: ✅ 6x Running (6 workers × 1 OSD each)
└── Storage Pools: ✅ Ready

Kafka PVCs: ✅ Bound (Storage available!)
```

## 💾 WAS IST EIN CEPH OSD?

**OSD = Object Storage Daemon**

```
┌───────────────────────────────────────┐
│              CEPH CLUSTER             │
├───────────────────────────────────────┤
│                                       │
│  ┌─────┐    ┌─────┐    ┌─────┐       │
│  │ MON │    │ MON │    │ MON │       │ ← Koordinieren
│  └─────┘    └─────┘    └─────┘       │
│                                       │
│  ┌─────┐    ┌─────┐                  │
│  │ MGR │    │ MGR │                  │ ← Management
│  └─────┘    └─────┘                  │
│                                       │
│  ┌─────┐    ┌─────┐    ┌─────┐       │
│  │ OSD │    │ OSD │    │ OSD │       │ ← Speichern Daten!
│  │Disk1│    │Disk2│    │Disk3│       │
│  └─────┘    └─────┘    └─────┘       │
│                                       │
└───────────────────────────────────────┘
```

## 🔄 DATENFLUSS: Kafka PVC → Ceph

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Kafka     │ →  │ PVC Request │ →  │ Ceph Pool   │
│   Pod       │    │ (5GB)       │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
                           │                    │
                           ▼                    ▼
                    ┌─────────────┐    ┌─────────────┐
                    │Storage Class│    │ OSD Daemon │
                    │rook-ceph-*  │    │ (auf Disk)  │
                    └─────────────┘    └─────────────┘
```

**OHNE OSD:** PVC bleibt `Pending` - keine Disks verfügbar!  
**MIT OSD:** PVC wird `Bound` - Daten werden gespeichert!

## ⚡ WARUM SEPARATE DISKS?

**Talos Design:**
- **scsi0**: System (OS, Boot, Config) - **RESERVIERT**
- **scsi1**: User Data (Ceph) - **VERFÜGBAR**

**Ceph Regel:**
- 1 OSD = 1 komplette Disk
- Kann nicht OS-Disk nutzen
- Braucht "rohe" unformatierte Disks

## 📊 HARDWARE ANALYSIS

### Current Infrastructure:
- **homelab**: 48GB RAM (Control Planes only)
- **nipogi**: 80GB RAM (6 Worker Nodes)
- **Datastore**: `local-zfs` (ZFS Storage)

### Proposed OSD Disk Configuration:

#### Option A: Conservative (Recommended)
- **Disk Size**: 100GB per OSD
- **Total**: 6 workers × 100GB = 600GB
- **Replication**: 3x (effective 200GB usable)
- **Use Case**: Kafka, Apps, Databases

#### Option B: Aggressive  
- **Disk Size**: 200GB per OSD
- **Total**: 6 workers × 200GB = 1.2TB
- **Replication**: 3x (effective 400GB usable)
- **Use Case**: Heavy data workloads, ML

#### Option C: Minimal (Testing)
- **Disk Size**: 50GB per OSD
- **Total**: 6 workers × 50GB = 300GB
- **Replication**: 3x (effective 100GB usable)
- **Use Case**: Development, Testing

## 🏗️ STORAGE LOCATION ANALYSIS

### VM Storage vs Host Storage

**Current Setup: VM Storage (local-zfs)**
- ✅ **Pros**: 
  - Isolated per VM
  - Easy backup/migration
  - ZFS benefits (compression, dedup)
  - Simple Terraform management
- ❌ **Cons**: 
  - Layer of abstraction
  - Potential performance overhead
  - Limited by host disk I/O

**Alternative: Host Pass-through**
- ✅ **Pros**: 
  - Direct hardware access
  - Maximum performance
  - No virtualization overhead
- ❌ **Cons**: 
  - Complex setup
  - Hardware dependency
  - Difficult migration

### Recommendation: VM Storage (Current Approach)

**Why VM Storage is Better:**
1. **Simplicity**: Works with existing Terraform
2. **Flexibility**: Easy to resize/migrate
3. **Reliability**: ZFS provides data integrity
4. **Management**: Consistent with current architecture

## 📏 OPTIMAL DISK SIZE CALCULATION

### Workload Analysis:
```
Expected Usage:
├── Kafka (Event Streaming): 20-50GB
├── MongoDB (Platform Data): 30-100GB  
├── PostgreSQL (App Data): 20-50GB
├── General App Storage: 50-100GB
├── Growth Buffer (1 year): 2x
└── Ceph Overhead: 20%

Total Raw Need: ~400-800GB
With 3x Replication: ~1200-2400GB total
Per OSD (6 nodes): ~200-400GB each
```

### **Final Recommendation: 150GB per OSD**

**Reasoning:**
- **Total Raw**: 6 × 150GB = 900GB
- **Effective (3x repl)**: 300GB usable
- **Buffer**: 50% growth headroom
- **Performance**: Good balance size/speed
- **Cost**: Reasonable disk usage

## 🔧 TERRAFORM IMPLEMENTATION

### Required Changes in `virtual-machines.tofu`:

```hcl
# Add after existing OS disk
dynamic "disk" {
  for_each = each.value.machine_type == "worker" ? [1] : []
  content {
    datastore_id = each.value.datastore_id
    interface    = "scsi1"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    size         = 150  # 150GB for Ceph OSD
  }
}
```

### Impact:
- **Workers Only**: Control planes don't need OSD disks
- **Automatic Discovery**: Rook will auto-detect new disks
- **Zero Config**: No manual intervention needed

## 🚀 DEPLOYMENT PROCESS

### Step 1: Apply Infrastructure
```bash
cd tofu/
tofu apply  # Adds 150GB disk to all 6 workers
```

### Step 2: Verify Disk Detection
```bash
kubectl get pods -n rook-ceph | grep osd
# Should show 6 OSD pods after ~5 minutes
```

### Step 3: Check Storage Pools
```bash
kubectl get cephblockpool -n rook-ceph
# Should show pools as "Ready"
```

### Step 4: Test with Kafka
```bash
kubectl get pvc -n kafka
# Should show "Bound" status
```

## 📈 MONITORING

### Health Checks:
```bash
# Ceph cluster status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status

# OSD status  
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd tree

# Storage usage
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df
```

### Expected Results:
- **Health**: `HEALTH_OK`
- **OSDs**: `6 up, 6 in`
- **PGs**: `active+clean`
- **Usage**: `<5% initially`

## 🎯 CONCLUSION

**Recommended Configuration:**
- ✅ **150GB OSD disks** on all 6 worker nodes
- ✅ **VM storage** (local-zfs) for simplicity  
- ✅ **Automatic discovery** by Rook operator
- ✅ **~300GB usable** for all Kubernetes workloads

This provides a robust, scalable storage foundation for the entire homelab Kubernetes cluster while maintaining operational simplicity.