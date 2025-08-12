# 🚀 Hardware Upgrade Plan - Horizontal Scaling

## 🎯 Current State → Future State

### **Current Setup (Single Server)**
```
HP EliteDesk 800 G5 Mini (i5-9500T, 48GB)
├── 3x Control Planes (ctrl-00, ctrl-01, ctrl-02)
├── 3x Worker Nodes (work-00, work-01, work-02)
└── Bootstrap Issues: 6C/6T struggles with heavy workloads
```

### **Future Setup (Dual Server Cluster)**
```
Server 1: HP EliteDesk G5 (i5-9500T, 48GB)    Server 2: HP EliteDesk G5 (i7-9700T, 32GB)
├── ctrl-00 (6GB, 2vCPU)                       ├── work-03 (6GB, 2vCPU)
├── ctrl-01 (6GB, 2vCPU)                       ├── work-04 (6GB, 2vCPU)
├── ctrl-02 (6GB, 2vCPU)                       ├── work-05 (6GB, 2vCPU)
├── work-00 (8GB, 2vCPU)                       ├── work-06 (6GB, 2vCPU)
├── work-01 (8GB, 2vCPU)                       └── Proxmox Host: 8GB
└── work-02 (8GB, 2vCPU)
    Proxmox Host: 6GB

Total: 48GB RAM, 6C/6T                         Total: 32GB RAM, 8C/8T
```

## 📦 Hardware Purchase

### **New Server Specs**
- **Model**: HP EliteDesk 800 G5 Mini PC
- **CPU**: Intel Core i7-9700T (8C/8T)
- **RAM**: 16GB DDR4 → Upgrade to 32GB
- **Storage**: 512GB NVMe SSD
- **Price**: €388.30 (Amazon)
- **Status**: ✅ Ready to purchase

### **RAM Upgrade Required**
- **Add**: 1x 16GB DDR4 SO-DIMM (~€40-50)
- **Total**: 32GB (16GB + 16GB)
- **Search**: "16GB DDR4 SO-DIMM 2666MHz"

## 🌐 Network & Infrastructure

### **Proxmox Cluster Setup**
```bash
# On current server (192.168.68.51):
pvecm create homelab-cluster

# On new server (192.168.68.52):
pvecm add 192.168.68.51
```

### **IP Address Allocation**
```
Current IPs:                    New IPs:
├── ctrl-00: 192.168.68.100    ├── work-03: 192.168.68.106
├── ctrl-01: 192.168.68.101    ├── work-04: 192.168.68.107  
├── ctrl-02: 192.168.68.102    ├── work-05: 192.168.68.108
├── work-00: 192.168.68.103    ├── work-06: 192.168.68.109
├── work-01: 192.168.68.104    └── Proxmox: 192.168.68.52
└── work-02: 192.168.68.105
    Proxmox: 192.168.68.51
```

## 🔧 Implementation Steps

### **Phase 1: Hardware Setup**
1. ✅ Purchase HP EliteDesk G5 i7-9700T
2. ⏳ Upgrade RAM to 32GB
3. ⏳ Install Proxmox on new server
4. ⏳ Join Proxmox cluster

### **Phase 2: OpenTofu Configuration**
```hcl
# Add new workers to tofu configuration
resource "proxmox_vm_qemu" "work-03" {
  target_node = "pve-02"  # New server
  vmid        = 106
  # ... rest of config
}

# Extend for work-04, work-05, work-06
```

### **Phase 3: Talos Deployment**
```bash
# Generate new machine configs
talosctl gen config homelab-cluster https://192.168.68.100:6443 \
  --with-cluster-discovery=false

# Apply configs to new worker nodes
talosctl apply-config --nodes 192.168.68.106 --file worker.yaml
talosctl apply-config --nodes 192.168.68.107 --file worker.yaml
talosctl apply-config --nodes 192.168.68.108 --file worker.yaml  
talosctl apply-config --nodes 192.168.68.109 --file worker.yaml
```

### **Phase 4: Workload Distribution**
```yaml
# Example pod placement for better distribution
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
```

## 🎯 Benefits After Upgrade

### **Performance Improvements**
- ✅ **Bootstrap Time**: 15+ min → <5 min
- ✅ **Total Cores**: 6C/6T → 14C/14T  
- ✅ **Total RAM**: 48GB → 80GB
- ✅ **Worker Capacity**: 3 nodes → 6 nodes

### **Operational Benefits**
- ✅ **High Availability**: Control planes isolated from heavy workloads
- ✅ **Rolling Updates**: More nodes for seamless updates
- ✅ **Resource Isolation**: Better workload distribution
- ✅ **Scaling**: Room for more applications

### **Enterprise Features**
- ✅ **Live Migration**: VMs can move between servers
- ✅ **Maintenance**: Zero-downtime hardware maintenance
- ✅ **Redundancy**: Cluster survives single server failure
- ✅ **Load Distribution**: Optimal resource utilization

## 📊 Cost Analysis

```
Hardware Investment:
├── New Server: €388.30
├── RAM Upgrade: €45.00
├── Shipping: €0.00 (FREE)
└── Total: €433.30

ROI:
├── Performance: 2.3x more CPU cores
├── Reliability: Server redundancy
├── Scalability: 2x worker nodes
└── Learning: Enterprise Kubernetes patterns
```

## 🚀 Timeline

- **Week 1**: Hardware purchase and delivery
- **Week 2**: Proxmox setup and cluster join
- **Week 3**: VM creation and Talos deployment  
- **Week 4**: Application migration and optimization

---

**Status**: 🟡 Planning Phase
**Next Action**: Purchase HP EliteDesk G5 i7-9700T
**Expected Completion**: End of August 2025