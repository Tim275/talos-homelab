# CSI Snapshot Infrastructure - Cluster-Wide Setup

## Overview

Kubernetes CSI (Container Storage Interface) snapshot infrastructure provides vendor-neutral volume snapshot capabilities for ALL CSI drivers in the cluster.

**Key Principle:** ONE snapshot-controller manages snapshots for ALL CSI drivers (Rook Ceph, Proxmox CSI, Longhorn, etc.)

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│              CSI SNAPSHOT ARCHITECTURE                         │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────────────────────────────────────────┐     │
│  │   Snapshot Controller (kube-system)                 │     │
│  │   - Watches VolumeSnapshot resources                │     │
│  │   - Coordinates with CSI drivers                    │     │
│  │   - Creates VolumeSnapshotContents                  │     │
│  └─────────────────────────────────────────────────────┘     │
│                          │                                     │
│                          ├─────────────┬──────────────┐       │
│                          ▼             ▼              ▼       │
│              ┌─────────────────┐  ┌─────────┐  ┌──────────┐  │
│              │  Rook Ceph RBD  │  │ CephFS  │  │ Proxmox  │  │
│              │  CSI Driver     │  │ Driver  │  │ CSI      │  │
│              └─────────────────┘  └─────────┘  └──────────┘  │
│                          │             │              │       │
│                          ▼             ▼              ▼       │
│              ┌─────────────────┐  ┌─────────┐  ┌──────────┐  │
│              │  Ceph RBD Pool  │  │ CephFS  │  │ Proxmox  │  │
│              │  (Snapshots)    │  │ (Snaps) │  │ Storage  │  │
│              └─────────────────┘  └─────────┘  └──────────┘  │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

## Components

### 1. VolumeSnapshot CRDs (v8.2.0)

**Source:** kubernetes-csi/external-snapshotter

**CRDs Installed:**
- `volumesnapshotclasses.snapshot.storage.k8s.io`
- `volumesnapshotcontents.snapshot.storage.k8s.io`
- `volumesnapshots.snapshot.storage.k8s.io`

**Purpose:**
- Define snapshot.storage.k8s.io API group
- Enable snapshot resources cluster-wide
- Required by ALL CSI drivers for snapshot support

**Installation:**
```yaml
# kustomization.yaml
resources:
  - https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
  - https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
  - https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
```

### 2. Snapshot Controller (v8.2.1)

**Location:** `snapshot-controller.yaml`

**Deployment Details:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: snapshot-controller
  namespace: kube-system
spec:
  replicas: 2  # High availability
  template:
    spec:
      containers:
        - name: snapshot-controller
          image: registry.k8s.io/sig-storage/snapshot-controller:v8.2.1
          args:
            - "--v=5"
            - "--leader-election=true"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

**Key Features:**
- **Leader Election:** Only one active controller (HA setup)
- **Cluster-Wide:** Manages snapshots for ALL CSI drivers
- **Kyverno Compliant:** Resource limits required by policy engine

**Why Custom YAML?**
The upstream GitHub deployment lacks resource limits, violating Kyverno policies. Our local version adds compliance while maintaining functionality.

### 3. VolumeSnapshotClasses

**Rook Ceph RBD (Block Storage):**
```yaml
# rook-ceph-block-snapclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-rbdplugin-snapclass
  labels:
    velero.io/csi-volumesnapshot-class: "true"  # Velero auto-discovery
driver: rook-ceph.rbd.csi.ceph.com
deletionPolicy: Delete
parameters:
  clusterID: rook-ceph
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph
```

**Rook Ceph CephFS (Filesystem):**
```yaml
# rook-ceph-fs-snapclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-cephfs-snapclass
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: rook-ceph.cephfs.csi.ceph.com
deletionPolicy: Delete
parameters:
  clusterID: rook-ceph
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph
```

**Deletion Policies:**
- `Delete` - Snapshot deleted when VolumeSnapshot is deleted (default)
- `Retain` - Snapshot preserved after VolumeSnapshot deletion (disaster recovery)

## Integration with Storage Drivers

### Rook Ceph Integration

**Prerequisites:**
1. Rook Ceph Operator deployed (`rook-ceph` namespace)
2. CephCluster healthy
3. StorageClasses created:
   - `rook-ceph-block-enterprise` (RBD)
   - `rook-ceph-filesystem-enterprise` (CephFS)

**CSI Drivers:**
- **RBD:** `rook-ceph.rbd.csi.ceph.com`
- **CephFS:** `rook-ceph.cephfs.csi.ceph.com`

**Snapshot Storage:**
- RBD snapshots → Ceph RBD pool
- CephFS snapshots → CephFS subvolume snapshots

### Proxmox CSI Integration (Future)

**VolumeSnapshotClass Template:**
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: proxmox-csi-snapclass
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: csi.proxmox.sinextra.dev
deletionPolicy: Retain
parameters:
  # Proxmox-specific parameters
```

**Storage Backend:**
- Proxmox VE ZFS pools
- LVM-Thin volumes
- Ceph RBD (if Proxmox uses external Ceph)

**Deployment Steps:**
1. Install Proxmox CSI driver
2. Create VolumeSnapshotClass for Proxmox driver
3. Test snapshot creation/restore
4. Configure Velero backup schedules

## Usage Examples

### Manual VolumeSnapshot Creation

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-data-snapshot
  namespace: production
spec:
  volumeSnapshotClassName: csi-rbdplugin-snapclass
  source:
    persistentVolumeClaimName: postgres-data
```

**Verify:**
```bash
kubectl get volumesnapshot postgres-data-snapshot -n production
kubectl get volumesnapshotcontent
```

### Restore from Snapshot

**1. Create PVC from Snapshot:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-restored
  namespace: production
spec:
  storageClassName: rook-ceph-block-enterprise
  dataSource:
    name: postgres-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**2. Use Restored PVC:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: postgres-restore-test
spec:
  containers:
    - name: postgres
      image: postgres:15
      volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: postgres-data-restored
```

### Velero Integration

**Automatic Snapshot Creation:**
Velero automatically detects VolumeSnapshotClasses with label:
```yaml
labels:
  velero.io/csi-volumesnapshot-class: "true"
```

**Backup with CSI Snapshots:**
```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: app-backup
spec:
  includedNamespaces:
    - production
  snapshotVolumes: true
  defaultVolumesToFsBackup: false  # Use CSI, not file-level backup
```

## Monitoring & Verification

### Check Snapshot Controller Health

```bash
# Controller status
kubectl get deployment snapshot-controller -n kube-system

# Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=snapshot-controller

# Verify leader election
kubectl get lease -n kube-system | grep snapshot
```

### List Available VolumeSnapshotClasses

```bash
kubectl get volumesnapshotclasses

# Expected output:
# NAME                     DRIVER                        DELETIONPOLICY   AGE
# csi-rbdplugin-snapclass  rook-ceph.rbd.csi.ceph.com   Delete          5d
# csi-cephfs-snapclass     rook-ceph.cephfs.csi.ceph.com Delete         5d
```

### Inspect VolumeSnapshotContents

```bash
# List all snapshot contents
kubectl get volumesnapshotcontents

# Detailed view
kubectl describe volumesnapshotcontent <name>
```

**Key Fields:**
- `Status.ReadyToUse: true` - Snapshot is ready for restore
- `Spec.DeletionPolicy` - What happens when VolumeSnapshot is deleted
- `Status.SnapshotHandle` - Backend storage snapshot ID (Ceph RBD ID)

### Verify CSI Driver Support

```bash
# List CSI drivers
kubectl get csidrivers

# Check driver capabilities
kubectl describe csidriver rook-ceph.rbd.csi.ceph.com
```

## Troubleshooting

### Snapshot Controller Not Starting

**Symptoms:**
- Pods in `CrashLoopBackOff`
- Logs show "failed to create client"

**Check:**
```bash
# 1. Verify CRDs are installed
kubectl get crd | grep snapshot.storage.k8s.io

# 2. Check RBAC permissions
kubectl get clusterrolebinding | grep snapshot-controller

# 3. Check resource limits (Kyverno)
kubectl get deployment snapshot-controller -n kube-system -o yaml | grep -A 5 resources
```

### VolumeSnapshot Stuck in "Pending"

**Symptoms:**
```
NAME                    READYTOUSE   SOURCEPVC     VOLUMESNAPSHOTCLASS      AGE
postgres-snapshot       false        postgres-pvc  csi-rbdplugin-snapclass  5m
```

**Troubleshoot:**
```bash
# 1. Check VolumeSnapshot events
kubectl describe volumesnapshot postgres-snapshot

# 2. Verify VolumeSnapshotClass exists
kubectl get volumesnapshotclass csi-rbdplugin-snapclass

# 3. Check CSI driver logs
kubectl logs -n rook-ceph -l app=csi-rbdplugin --tail=50

# 4. Verify Ceph cluster health
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status
```

### VolumeSnapshotContent Not Created

**Symptoms:**
- VolumeSnapshot exists but no VolumeSnapshotContent
- Snapshot controller logs show errors

**Common Causes:**
1. **Missing CSI driver:** Driver not deployed in cluster
2. **Wrong driver name:** VolumeSnapshotClass driver doesn't match CSI driver
3. **RBAC issues:** CSI driver lacks snapshot permissions
4. **Storage backend full:** Ceph pool at capacity

**Fix:**
```bash
# 1. Verify CSI driver is running
kubectl get pods -n rook-ceph | grep csi-rbdplugin

# 2. Check driver name matches
kubectl get volumesnapshotclass csi-rbdplugin-snapclass -o yaml | grep driver
kubectl get csidriver | grep rook-ceph

# 3. Check Ceph pool capacity
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  ceph df
```

## Disaster Recovery Scenarios

### Scenario 1: Accidental PVC Deletion

**Before Deletion:**
```bash
# Create snapshot
kubectl create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: emergency-backup
  namespace: production
spec:
  volumeSnapshotClassName: csi-rbdplugin-snapclass
  source:
    persistentVolumeClaimName: critical-data
EOF

# Wait for ready
kubectl wait --for=condition=ReadyToUse volumesnapshot/emergency-backup -n production
```

**After Deletion:**
```bash
# Restore from snapshot
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: critical-data-restored
  namespace: production
spec:
  storageClassName: rook-ceph-block-enterprise
  dataSource:
    name: emergency-backup
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi
EOF
```

### Scenario 2: Pre-Upgrade Snapshots

**Best Practice:** Always snapshot stateful workloads before cluster upgrades.

```bash
# Automated snapshot script
for ns in production staging; do
  for pvc in $(kubectl get pvc -n $ns -o name); do
    pvc_name=$(echo $pvc | cut -d/ -f2)
    kubectl create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pre-upgrade-${pvc_name}
  namespace: $ns
spec:
  volumeSnapshotClassName: csi-rbdplugin-snapclass
  source:
    persistentVolumeClaimName: ${pvc_name}
EOF
  done
done
```

## Best Practices

### 1. Retention Policies

**Production (Retain):**
```yaml
deletionPolicy: Retain
```
- Snapshots survive VolumeSnapshot deletion
- Manual cleanup required
- Use for critical data

**Dev/Test (Delete):**
```yaml
deletionPolicy: Delete
```
- Auto-cleanup when VolumeSnapshot deleted
- Prevents snapshot sprawl
- Use for temporary snapshots

### 2. Snapshot Naming Convention

```
<workload>-<type>-<timestamp>
postgres-prod-manual-20251005
kafka-prod-scheduled-weekly
```

### 3. Storage Quota Management

Monitor Ceph pool usage:
```bash
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  rbd du replicapool
```

Set snapshot limits in VolumeSnapshotClass (future feature).

### 4. Snapshot Testing

**Monthly drill:** Restore production snapshots to staging and verify data integrity.

```bash
# Test restore pipeline
kubectl create ns snapshot-test
kubectl create -f restore-test.yaml
kubectl exec -n snapshot-test test-pod -- verify-data.sh
kubectl delete ns snapshot-test
```

## Integration with Other Tools

### Velero
- Auto-discovers VolumeSnapshotClasses
- Creates VolumeSnapshots during backups
- Stores snapshot metadata in S3
- Restores snapshots on different clusters

### Argo Workflows
- Automate snapshot creation before deployments
- Rollback workflows using snapshot restores
- Snapshot validation pipelines

### Prometheus Monitoring
```yaml
# Alert on snapshot failures
- alert: VolumeSnapshotFailed
  expr: kube_volumesnapshot_status_ready_to_use == 0
  for: 5m
  annotations:
    summary: "VolumeSnapshot {{ $labels.namespace }}/{{ $labels.volumesnapshot }} failed"
```

## Upgrade Path

### Upgrading Snapshot Controller

**Current:** v8.2.1
**Next:** v8.3.0 (when available)

**Steps:**
1. Review release notes
2. Update CRDs first:
   ```bash
   kubectl apply -f new-crds.yaml
   ```
3. Update snapshot-controller image
4. Restart deployment
5. Verify existing snapshots still work

**Rollback:**
Keep previous version YAML in Git for quick rollback if needed.

## Additional Resources

- **Official Docs:** https://kubernetes-csi.github.io/docs/snapshot-controller.html
- **Rook Ceph Snapshots:** https://rook.io/docs/rook/latest/Storage-Configuration/Ceph-CSI/ceph-csi-snapshot/
- **CSI Spec:** https://github.com/container-storage-interface/spec/blob/master/spec.md

## Maintenance

**Regular Tasks:**
- Monthly: Review snapshot storage usage
- Quarterly: Test snapshot restore procedures
- Annually: Snapshot controller version upgrade

**Maintainer:** Homelab Infrastructure Team
**Last Updated:** 2025-10-05
**Snapshot Controller Version:** v8.2.1
**CRD Version:** v8.2.0
