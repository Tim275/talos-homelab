# 💾 Talos Homelab Disk Architecture

**Last Updated**: 2025-10-04
**Status**: Conservative sizing implemented
**Philosophy**: Incremental growth - start reasonable, scale when needed

---

## 📊 Current Disk Configuration

### **Hardware Overview**

| Host | Model | CPU | RAM | Total Storage |
|------|-------|-----|-----|---------------|
| **nipogi** | NiPoGi AM21 | AMD Ryzen 9 6900HX (8C/16T @ 4.9GHz) | 32GB DDR5 | 1TB NVMe SSD |
| **msa2proxmox** | MINISFORUM MS-A2 | AMD Ryzen 9 9955HX (16C/32T @ 5.4GHz) | 96GB DDR5 | 2TB SSD |

### **VM Disk Allocation**

#### **Control Plane (ctrl-0)**
```yaml
Host: nipogi
OS Disk (scsi0):    50GB  # Talos OS + /var/lib/rook monitors
Ceph OSD (scsi1):   None  # Control plane has no Ceph OSD
```

#### **Workers 1-2 (nipogi)**
```yaml
Host: nipogi (1TB total storage)
Per Worker:
  OS Disk (scsi0):    50GB   # Talos OS + /var/lib/rook monitors
  Ceph OSD (scsi1):   200GB  # Block storage for PVCs

Total per Worker: 250GB
2 Workers Total:  500GB (leaving ~500GB free on host)
```

#### **Workers 3-6 (msa2proxmox)**
```yaml
Host: msa2proxmox (2TB total storage)
Per Worker:
  OS Disk (scsi0):    50GB   # Talos OS + /var/lib/rook monitors
  Ceph OSD (scsi1):   200GB  # Block storage for PVCs

Total per Worker: 250GB
4 Workers Total:  1TB (leaving ~1TB free on host)
```

---

## 🎯 Disk Usage Breakdown

### **OS Disk (scsi0) - 50GB**

**Purpose**: Operating system, container runtime, Ceph monitor metadata

| Component | Size | Description |
|-----------|------|-------------|
| Talos OS | ~5GB | Minimal Linux OS for Kubernetes |
| Container Images | ~20-30GB | Cached container images |
| /var/lib/rook | ~5-10GB | Ceph monitor metadata (mon-a, mon-b, mon-c) |
| Logs & Temp | ~5GB | System logs, temporary files |
| **Reserve** | ~10GB | Growth buffer |

**Why 50GB?**
- ✅ Fixes MON_DISK_LOW warning (was 18GB, 78% full)
- ✅ Plenty of room for container image cache
- ✅ Not overly aggressive (can increase later if needed)

### **Ceph OSD Disk (scsi1) - 200GB per Worker**

**Purpose**: Distributed block storage for Kubernetes PVCs

| Component | Description |
|-----------|-------------|
| **Raw Storage** | 6 workers × 200GB = 1.2TB total raw |
| **Replication** | 3x replication for high availability |
| **Usable Storage** | 1.2TB ÷ 3 = **~400GB usable** |

**Current Usage** (~280GB of 400GB usable):
```
Elasticsearch:     3 × 10GB = 30GB
Kafka:             3 × 5GB  = 15GB
N8N (prod+dev):    ~15GB
Audiobookshelf:    ~120GB
Prometheus:        19GB
PostgreSQL DBs:    ~20GB
InfluxDB:          20GB
Loki:              10GB
Keep:              10GB
Other Apps:        ~20GB
─────────────────────────────
Total Used:        ~280GB
Available:         ~120GB (30% free)
```

---

## 🏗️ Rook-Ceph Architecture

### **Cluster Topology**

```
┌─────────────────────────────────────────────────────────┐
│ TALOS CLUSTER - 7 Nodes                                 │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Control Plane (ctrl-0):                                 │
│  ├─ OS Disk: 50GB                                        │
│  ├─ Ceph Monitor: Yes (uses /var/lib/rook on OS disk)   │
│  └─ Ceph OSD: No                                         │
│                                                           │
│  Workers (6x):                                           │
│  ├─ OS Disk: 50GB                                        │
│  ├─ Ceph Monitor: Distributed (mon-a, mon-b, mon-c)     │
│  └─ Ceph OSD: Yes (200GB dedicated /dev/sdb disk)       │
│                                                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ CEPH DAEMONS - Distribution                             │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Monitors (3):         mon-a, mon-b, mon-c               │
│  ├─ Storage:           /var/lib/rook (on OS disk)        │
│  └─ Anti-affinity:     1 per node (different nodes)      │
│                                                           │
│  Managers (2):         mgr-a, mgr-b                      │
│  └─ Modules:           pg_autoscaler, balancer, prometheus│
│                                                           │
│  OSDs (6):             osd-0 through osd-5               │
│  ├─ 1 OSD per worker:  /dev/sdb (scsi1)                  │
│  ├─ Store Type:        BlueStore                         │
│  └─ Size:              200GB each                        │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### **Storage Classes**

| Storage Class | Use Case | Replication | Performance |
|--------------|----------|-------------|-------------|
| `rook-ceph-block-enterprise` | PVCs for databases, apps | 3x | High (NVMe/SSD) |

---

## 📈 Capacity Planning & Growth

### **Current Capacity (Conservative Start)**

```
OS Disks:
├─ ctrl-0:     50GB   (control plane)
├─ worker-1:   50GB   (nipogi)
├─ worker-2:   50GB   (nipogi)
├─ worker-3:   50GB   (msa2proxmox)
├─ worker-4:   50GB   (msa2proxmox)
├─ worker-5:   50GB   (msa2proxmox)
└─ worker-6:   50GB   (msa2proxmox)
Total:         350GB

Ceph OSDs:
├─ worker-1:   200GB  (nipogi)
├─ worker-2:   200GB  (nipogi)
├─ worker-3:   200GB  (msa2proxmox)
├─ worker-4:   200GB  (msa2proxmox)
├─ worker-5:   200GB  (msa2proxmox)
└─ worker-6:   200GB  (msa2proxmox)
Total Raw:     1.2TB
Usable (3x):   ~400GB
```

### **Future Growth Path (When Needed)**

**Option 1: Moderate Growth**
```
OS Disk:       50GB → 100GB   (2x increase)
Ceph OSD:      200GB → 400GB  (2x increase)
Total Usable:  400GB → 800GB  (2x increase)
```

**Option 2: Aggressive Growth (Use Full Hardware)**
```
nipogi workers:
  OS Disk:     50GB → 100GB
  Ceph OSD:    200GB → 400GB  (leaves 500GB free per worker on 1TB host)

msa2proxmox workers:
  OS Disk:     50GB → 100GB
  Ceph OSD:    200GB → 450GB  (leaves ~1TB free per worker on 2TB host)

Total Usable:  400GB → ~1TB
```

### **When to Grow?**

Monitor these metrics:

**OS Disk Warning Signs:**
- `df -h /` shows >80% usage
- MON_DISK_LOW alerts return
- Container image cache eviction

**Ceph OSD Warning Signs:**
- Ceph status shows >70% full
- PVC provisioning failures
- HEALTH_WARN with "nearfull" status

---

## 🔧 Infrastructure as Code

### **Terraform Configuration**

Location: `tofu/talos_nodes.auto.tfvars`

```hcl
# Per-node disk sizing
"worker-1" = {
  host_node      = "nipogi"
  os_disk_size   = 50    # OS + /var/lib/rook monitors
  ceph_disk_size = 200   # Ceph OSD
}
```

### **Proxmox VM Disk Layout**

```
VM ID 1001 (worker-1):
├─ scsi0: 50GB   (Talos OS disk, bootable)
│  ├─ Format:        raw
│  ├─ Cache:         writethrough
│  ├─ Discard:       on
│  └─ Mounted as:    / (root filesystem)
│
└─ scsi1: 200GB  (Ceph OSD disk, raw block device)
   ├─ Format:        raw
   ├─ Cache:         none (direct I/O for Ceph)
   ├─ Discard:       on
   └─ Managed by:    Rook-Ceph operator (/dev/sdb)
```

### **Rook-Ceph Configuration**

Location: `kubernetes/infrastructure/storage/rook-ceph/cluster.yaml`

```yaml
spec:
  dataDirHostPath: /var/lib/rook  # Monitor metadata on OS disk

  mon:
    count: 3                       # HA with odd number
    allowMultiplePerNode: false    # Anti-affinity
    # Uses dataDirHostPath (no PVC for bootstrap simplicity)

  storage:
    useAllNodes: false
    useAllDevices: false           # Explicit device selection
    nodes:
      - name: "worker-1"
        devices:
          - name: "/dev/sdb"       # scsi1 - 200GB Ceph OSD
```

---

## 🚨 Troubleshooting

### **MON_DISK_LOW Warning**

**Symptom:**
```
HEALTH_WARN: mon b is low on available space
```

**Root Cause:**
- Ceph monitors use `/var/lib/rook` on OS disk (scsi0)
- OS disk was too small (20GB → 78% full)

**Solution:**
- ✅ Increased OS disk to 50GB
- ✅ Provides 30GB+ free space for monitors

### **Verifying Disk Sizes**

**Check OS disk space:**
```bash
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
OS-DISK:.status.capacity.ephemeral-storage
```

**Check Ceph cluster capacity:**
```bash
kubectl get cephcluster -n rook-ceph rook-ceph \
  -o jsonpath='{.status.ceph.capacity}' | jq
```

**Check Ceph health:**
```bash
kubectl get cephcluster -n rook-ceph rook-ceph \
  -o jsonpath='{.status.ceph.health}'
# Expected: HEALTH_OK
```

---

## 📚 Best Practices Applied

### **Ceph Official Recommendations**

✅ **1 OSD per disk** - Not multiple OSDs on single disk
✅ **Odd number of monitors** - 3 monitors for HA
✅ **Minimum OSD size** - 1TB recommended (we: 200GB acceptable for homelab)
✅ **Separate monitor storage** - Monitors on fast storage (/var/lib/rook on OS disk)
✅ **BlueStore backend** - Modern Ceph storage engine
✅ **3x replication** - High availability with data safety

### **Homelab Optimizations**

✅ **Conservative sizing** - Start small, grow when needed
✅ **Per-node flexibility** - Different hosts, different sizes (future-ready)
✅ **Cost efficiency** - Don't over-allocate, leave room for host OS
✅ **Easy scaling** - Disk resize is non-destructive (grow only)

---

## 🎯 Migration & Resize Guide

### **How to Resize Disks (Future)**

**1. Update Terraform:**
```bash
cd tofu/
# Edit talos_nodes.auto.tfvars
# Change os_disk_size or ceph_disk_size

tofu plan   # Review changes
tofu apply  # Apply disk resize
```

**2. Resize OS Disk (Automatic):**
```bash
# Talos automatically expands root filesystem on boot
# No manual intervention needed
```

**3. Resize Ceph OSD (Requires Rebuild):**
```bash
# Ceph OSDs cannot be resized in-place
# Must destroy and recreate with larger disk

# 1. Scale down OSD (gracefully)
kubectl -n rook-ceph delete deployment rook-ceph-osd-X

# 2. Wait for Ceph to rebalance (may take time)
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# 3. Apply Terraform change (larger disk)
tofu apply

# 4. Rook operator will recreate OSD with new size
kubectl -n rook-ceph get pods -l app=rook-ceph-osd
```

**⚠️ Important**: Resize one OSD at a time, wait for HEALTH_OK between each!

---

## 📊 Monitoring & Alerts

### **Key Metrics to Watch**

**Ceph Health:**
```bash
# Should always be HEALTH_OK
kubectl get cephcluster -n rook-ceph rook-ceph \
  -o jsonpath='{.status.ceph.health}'
```

**Ceph Capacity:**
```bash
kubectl get cephcluster -n rook-ceph rook-ceph \
  -o jsonpath='{.status.ceph.capacity}' | jq
```

**OS Disk Usage:**
```bash
# Check from inside pods or nodes
df -h /var/lib/rook
```

### **Prometheus Alerts**

Located in: `kubernetes/infrastructure/monitoring/kube-prometheus-stack/`

- `CephClusterErrorState` - Ceph cluster in ERROR state
- `CephMonDiskLow` - Monitor disk <15% free (previously triggered!)
- `CephOSDDiskFull` - OSD >85% full
- `CephClusterNearFull` - Cluster >75% capacity

---

## 🔗 References

- [Rook Ceph Documentation](https://rook.io/docs/rook/latest/)
- [Ceph Hardware Recommendations](https://docs.ceph.com/en/latest/start/hardware-recommendations/)
- [Talos Linux Storage](https://www.talos.dev/latest/talos-guides/configuration/storage/)

---

**Maintained by**: Talos Homelab Team
**Last Review**: 2025-10-04
**Next Review**: When approaching 70% capacity or adding new nodes
