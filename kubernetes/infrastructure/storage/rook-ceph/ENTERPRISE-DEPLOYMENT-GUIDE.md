# Rook-Ceph Enterprise Deployment Guide for Talos/Proxmox

## Overview
This enterprise-grade Rook-Ceph deployment is optimized for your Talos Linux cluster running on Proxmox VE with Ceph backend storage. The configuration addresses the specific challenges of running Ceph in a virtualized environment with proper failure domain isolation.

## Architecture

### Cluster Topology
- **Physical Hosts**: 2 (homelab, nipogi)
- **Kubernetes Nodes**: 9 total
  - **Control Planes**: 3 (distributed across hosts)
  - **Workers**: 6 (balanced across hosts)
- **Storage Nodes**: 5 dedicated Ceph nodes on nipogi host
- **Failure Domain**: Host-level isolation

### Storage Configuration
- **Ceph Version**: Pacific v18.2.4 (proven stable with Proxmox)
- **Replication**: 3x for critical data, 2x for performance workloads
- **Device**: `/dev/sdb` on each storage node (separate from OS disk)
- **Backend**: Proxmox Ceph cluster (hyperconverged)

## Enterprise Feature Matrix

### ✅ Enabled Production Features

| Feature | Status | Benefit | Performance Impact |
|---------|--------|---------|-------------------|
| **Wire Encryption (msgr2)** | ✅ ENABLED | Encrypts all OSD↔OSD/Mon/Client traffic | -5% CPU |
| **Dashboard SSL (HTTPS)** | ✅ ENABLED | Secure web UI access with TLS | Minimal |
| **Object Storage (RGW)** | ✅ DEPLOYED | S3-compatible API for apps/backups | Minimal |
| **Telemetry Module** | ✅ ENABLED | Advanced cluster health analytics | +50MB RAM |
| **Prometheus Integration** | ✅ CONFIGURED | Dashboard metrics visualization | None |
| **3x Replication** | ✅ ENABLED | Enterprise-grade data durability | Standard |
| **High Availability** | ✅ ENABLED | 3 Monitors, 2 Managers | Standard |
| **Compression (LZ4)** | ✅ ENABLED | Storage space optimization | -10% CPU |
| **pg_autoscaler** | ✅ ENABLED | Automatic PG management | None |
| **Crash Collector** | ✅ ENABLED | Automated crash reporting | Minimal |

### ❌ Intentionally Disabled Features

| Feature | Why NOT Enabled | Impact if Enabled |
|---------|-----------------|-------------------|
| **Encryption at Rest** | ⚠️ -30% performance, requires full data wipe | Only for compliance (HIPAA/PCI-DSS) |
| **KMS Integration (Vault)** | 🔴 Overkill for single-tenant homelab | Complex dependency, multi-tenant only |
| **NFS Gateway** | 🟡 CephFS already provides POSIX filesystem | Redundant functionality |
| **Multi-Site Replication** | 🔴 Requires 2nd cluster in different datacenter | Geo-redundancy, DR across regions |
| **RBD Mirroring** | 🟡 Only useful with 2nd remote cluster | Cross-cluster replication |
| **CephFS Mirroring** | 🟡 Same as RBD - needs remote cluster | Disaster recovery to 2nd site |
| **Stretch Cluster** | 🔴 High complexity, multi-zone deployment | Banking/critical workloads only |
| **Erasure Coding** | ⚠️ -20% write performance | Cold storage/archives only |
| **Cache Tiering** | 🔴 **DEPRECATED** by Ceph upstream | Officially not recommended |
| **Read Affinity** | 🟡 Only useful with multi-zone topology | Requires geo-distributed nodes |

---

## Key Enterprise Features

### 1. Production-Grade Resource Allocation
- **MON**: 2Gi memory, 2 CPU cores (high availability)
- **MGR**: 4Gi memory, 2 CPU cores (management overhead)
- **OSD**: 8Gi memory, 4 CPU cores (performance optimized)

### 2. Advanced Placement Rules
- **MONs**: Control plane nodes only
- **OSDs**: Worker nodes with anti-affinity
- **MGRs**: Control plane with anti-affinity

### 3. Enterprise Storage Classes
- `rook-ceph-block-enterprise`: Default high-performance RBD
- `rook-ceph-block-ssd`: Ultra-high performance (lower replication)
- `rook-cephfs-enterprise`: Shared filesystem storage
- `rook-ceph-backup`: Long-term retention (erasure coded)

### 4. Comprehensive Monitoring
- Prometheus integration with custom alert rules
- Grafana dashboard for cluster health
- Performance metrics and capacity planning

## Deployment Steps

### 1. Pre-Deployment Verification
```bash
# Verify all storage nodes have the sdb device
kubectl apply -f device-preparation.yaml

# Check device preparation logs
kubectl logs -f daemonset/rook-ceph-device-preparation -n rook-ceph
```

### 2. Deploy Rook-Ceph Enterprise
```bash
# Apply the complete enterprise configuration
kubectl apply -k kubernetes/infra/storage/rook-ceph/

# Monitor deployment progress
watch kubectl get pods -n rook-ceph
```

### 3. Verify Cluster Health
```bash
# Wait for all components to be ready
kubectl wait --for=condition=ready pod -l app=rook-ceph-operator -n rook-ceph --timeout=300s

# Check Ceph cluster status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status
```

### 4. Validate Storage Classes
```bash
# List available storage classes
kubectl get storageclass

# Test volume provisioning
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-ceph-block-enterprise
EOF
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. OSD Creation Failures
```bash
# Check OSD preparation logs
kubectl logs -l app=rook-ceph-osd-prepare -n rook-ceph

# Verify device availability
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd tree

# Clean problematic OSDs
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd purge <osd-id> --yes-i-really-mean-it
```

#### 2. MON Quorum Issues
```bash
# Check MON status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph mon stat

# Restart problematic MON
kubectl delete pod -l app=rook-ceph-mon -n rook-ceph
```

#### 3. Performance Issues
```bash
# Check slow operations
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail

# Monitor OSD performance
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd perf
```

#### 4. Storage Full Scenarios
```bash
# Check cluster utilization
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df

# Rebalance data
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph balancer on
```

### Emergency Procedures

#### Complete Cluster Rebuild
If the cluster becomes unrecoverable:

1. **Backup Critical Data**
2. **Clean All OSDs**:
```bash
# Set CLEAN_DEVICE=true in device-preparation.yaml
kubectl patch daemonset rook-ceph-device-preparation -n rook-ceph -p '{"spec":{"template":{"spec":{"containers":[{"name":"device-prep","env":[{"name":"CLEAN_DEVICE","value":"true"}]}]}}}}'
```

3. **Redeploy Cluster**:
```bash
kubectl delete -k kubernetes/infra/storage/rook-ceph/
# Wait for cleanup completion
kubectl apply -k kubernetes/infra/storage/rook-ceph/
```

## Monitoring and Maintenance

### Dashboard Access
- **Ceph Dashboard**: https://ceph.timour-homelab.com
- **Default Credentials**: Check secret `rook-ceph-dashboard-password`

### Regular Maintenance Tasks

#### Weekly
- Check cluster health status
- Review storage utilization
- Validate backup procedures

#### Monthly
- Update Ceph version (test in staging first)
- Review and optimize PG distributions
- Capacity planning assessment

#### Quarterly
- Full disaster recovery testing
- Performance benchmarking
- Security audit and updates

## Performance Tuning

### Optimized Settings Applied
- **BlueStore**: Optimized for virtual environments
- **Compression**: LZ4 for performance balance
- **PG Count**: Calculated for optimal distribution
- **Network**: Host networking for best performance

### Custom Tuning Options
```bash
# Increase OSD memory target (per OSD)
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph config set osd osd_memory_target 8G

# Optimize for SSD performance
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph config set osd bluestore_cache_size_ssd 3G
```

## Security Considerations

- **Network Encryption**: Enabled between Ceph daemons
- **Authentication**: CephX authentication enabled
- **RBAC**: Kubernetes RBAC for Ceph resources
- **Pod Security**: Privileged security context (required for storage)

## Backup and Recovery

The enterprise configuration includes:
- **Velero Integration**: For application-level backups
- **Ceph RBD Snapshots**: For point-in-time recovery
- **Cross-Region Replication**: Mirror to backup pools

## Support and Documentation

- **Rook Documentation**: https://rook.io/docs/rook/v1.15/
- **Ceph Documentation**: https://docs.ceph.com/
- **Troubleshooting**: Check logs in `/var/log/ceph` on Talos nodes
- **Community**: Rook Slack channel and GitHub issues
