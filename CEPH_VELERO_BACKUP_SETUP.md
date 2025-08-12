# Ceph RGW + Velero Backup Setup

Complete guide for setting up Kubernetes backups using Rook-Ceph Object Gateway (RGW) and Velero.

## 🎯 Overview

This setup provides enterprise-grade backup solution using:
- **Rook-Ceph Object Gateway (RGW)** - S3-compatible object storage
- **Velero** - Kubernetes backup/restore tool  
- **SealedSecrets** - Encrypted credential management

## 📋 Prerequisites

- Kubernetes cluster with Rook-Ceph installed
- `kubeseal` CLI tool for SealedSecrets
- `kubectl` access to cluster

## 🚀 Step 1: Deploy Ceph Object Gateway (RGW)

### 1.1 Create CephObjectStore

```yaml
# kubernetes/infra/storage/rook-ceph-rgw/ceph-object-store.yaml
apiVersion: ceph.rook.io/v1
kind: CephObjectStore
metadata:
  name: homelab-objectstore
  namespace: rook-ceph
spec:
  metadataPool:
    replicated:
      size: 3
  dataPool:
    replicated:
      size: 3
  preservePoolsOnDelete: false
  gateway:
    port: 80
    instances: 2
    resources:
      limits:
        cpu: "2000m"
        memory: "2Gi"
      requests:
        cpu: "1000m"
        memory: "1Gi"
```

### 1.2 Create Admin User

```yaml
# kubernetes/infra/storage/rook-ceph-rgw/ceph-object-store-user.yaml
apiVersion: ceph.rook.io/v1
kind: CephObjectStoreUser
metadata:
  name: s3-admin
  namespace: rook-ceph
spec:
  store: homelab-objectstore
  displayName: "S3 Admin User"
  capabilities:
    user: "*"
    bucket: "*"
```

### 1.3 Deploy RGW

```bash
kubectl apply -k kubernetes/infra/storage/rook-ceph-rgw/
```

Verify deployment:
```bash
kubectl get cephobjectstore -n rook-ceph
kubectl get pods -n rook-ceph | grep rgw
```

## 🪣 Step 2: Create S3 Bucket

### 2.1 Get Admin Credentials

```bash
# Get access key
kubectl get secret rook-ceph-object-user-homelab-objectstore-s3-admin -n rook-ceph -o jsonpath='{.data.AccessKey}' | base64 -d

# Get secret key  
kubectl get secret rook-ceph-object-user-homelab-objectstore-s3-admin -n rook-ceph -o jsonpath='{.data.SecretKey}' | base64 -d
```

### 2.2 Create Velero Bucket

```yaml
# Create pod to make bucket
apiVersion: v1
kind: Pod
metadata:
  name: create-bucket
  namespace: rook-ceph
spec:
  restartPolicy: Never
  containers:
  - name: aws
    image: amazon/aws-cli:latest
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    env:
    - name: AWS_ACCESS_KEY_ID
      value: "YOUR_ACCESS_KEY"
    - name: AWS_SECRET_ACCESS_KEY
      value: "YOUR_SECRET_KEY"
    command:
    - /bin/sh
    - -c
    - |
      aws s3 mb s3://velero-backups --endpoint-url http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 --region us-east-1
      aws s3 ls --endpoint-url http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
```

Apply and check:
```bash
kubectl apply -f create-bucket.yaml
kubectl logs create-bucket -n rook-ceph
```

## 🔐 Step 3: Configure Velero Credentials

### 3.1 Create Plain Credentials File

```bash
# /tmp/velero-creds.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id = YOUR_ACCESS_KEY
    aws_secret_access_key = YOUR_SECRET_KEY
```

### 3.2 Seal Credentials

```bash
kubeseal --cert bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
  --format yaml < /tmp/velero-creds.yaml > kubernetes/infra/backup/velero/cloud-credentials.yaml

# Clean up plain text
rm /tmp/velero-creds.yaml
```

## ⚡ Step 4: Deploy Velero

### 4.1 Create Velero Namespace

```yaml
# kubernetes/infra/backup/velero/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: velero
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
```

### 4.2 Configure Velero Values

```yaml
# kubernetes/infra/backup/velero/values-ceph.yaml
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.12.1
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

configuration:
  features: EnableCSI
  backupStorageLocation:
    - provider: aws
      bucket: velero-backups
      config:
        region: us-east-1
        s3ForcePathStyle: true
        s3Url: http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc.cluster.local:80

credentials:
  existingSecret: cloud-credentials

snapshotsEnabled: false

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

schedules:
  daily-backup:
    schedule: "0 4 * * *"  # 4 AM daily
    template:
      ttl: "720h"  # 30 days retention
      storageLocation: default
      includedNamespaces:
        - "*"  # All namespaces
      excludedResources:
        - pods
        - replicasets
```

### 4.3 Create Kustomization

```yaml
# kubernetes/infra/backup/velero/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: velero

resources:
  - ns.yaml
  - volumesnapshotclass.yaml
  - cloud-credentials.yaml

helmCharts:
  - name: velero
    repo: https://vmware-tanzu.github.io/helm-charts
    version: 8.2.0
    releaseName: velero
    includeCRDs: true
    valuesFile: values-ceph.yaml
```

### 4.4 Deploy Velero

```bash
# Via ArgoCD (recommended)
kubectl apply -k kubernetes/infra/backup/velero/

# Or direct kubectl
kubectl apply -k kubernetes/infra/backup/velero/
```

## 🧪 Step 5: Test Backup

### 5.1 Verify Setup

```bash
# Check Velero pods
kubectl get pods -n velero

# Check backup storage location
kubectl get backupstoragelocation -n velero
# Should show: Available
```

### 5.2 Create Test Backup

```yaml
# test-backup.yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: test-backup
  namespace: velero
spec:
  storageLocation: default
  ttl: 24h0m0s
  includedNamespaces:
    - minio  # or any namespace you want to test
```

```bash
kubectl apply -f test-backup.yaml

# Check status
kubectl get backup test-backup -n velero
kubectl describe backup test-backup -n velero
```

### 5.3 Verify in Ceph

```bash
# List backups in bucket
kubectl run -i --rm aws-test --image=amazon/aws-cli:latest --restart=Never -- \
  aws s3 ls s3://velero-backups --endpoint-url http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
```

## 📊 Step 6: Monitoring & Management

### 6.1 Check Backup Schedule

```bash
kubectl get schedule -n velero
kubectl describe schedule daily-backup -n velero
```

### 6.2 Manual Backup Commands

```bash
# Backup specific namespace
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M)
  namespace: velero
spec:
  storageLocation: default
  ttl: 168h  # 7 days
  includedNamespaces:
    - production
EOF

# List all backups
kubectl get backups -n velero

# Get backup logs
kubectl logs deployment/velero -n velero
```

## 🔄 Step 7: Restore Process

### 7.1 List Available Backups

```bash
kubectl get backups -n velero
```

### 7.2 Create Restore

```yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: test-restore
  namespace: velero
spec:
  backupName: test-backup
  # Optional: restore to different namespace
  # namespaceMapping:
  #   source-ns: target-ns
```

```bash
kubectl apply -f restore.yaml
kubectl get restore -n velero
kubectl describe restore test-restore -n velero
```

## 🎛️ Step 8: Web UI Management (Future)

Once setup is complete, create individual users via Ceph Dashboard:

1. Access Ceph Dashboard: `https://your-cluster/ceph-dashboard`
2. Navigate to **Object Gateway** → **Users**
3. Create application-specific users with limited bucket permissions
4. Use these users instead of admin credentials for production apps

## 🐛 Troubleshooting

### Common Issues

**Backup fails with "NoSuchBucket":**
```bash
# Verify bucket exists
kubectl logs create-bucket -n rook-ceph
```

**403 Forbidden errors:**
```bash
# Check credentials are correct
kubectl get secret cloud-credentials -n velero -o yaml
echo "BASE64_STRING" | base64 -d  # decode to verify
```

**BackupStorageLocation Unavailable:**
```bash
# Check Velero logs
kubectl logs deployment/velero -n velero

# Restart Velero
kubectl rollout restart deployment velero -n velero
```

**RGW pods not starting:**
```bash
# Check Ceph cluster health
kubectl get cephcluster -n rook-ceph
kubectl -n rook-ceph get pod -l app=rook-ceph-rgw
```

## 📈 Production Considerations

1. **Resource Limits**: Adjust RGW gateway resources based on backup size
2. **Retention Policy**: Configure appropriate backup retention (720h = 30 days)
3. **Storage Class**: Ensure CSI volume snapshots work with your storage
4. **Monitoring**: Set up alerts for backup failures
5. **Security**: Create dedicated users instead of using admin credentials
6. **Network**: Consider using HTTPS endpoints for production

## 🎯 Success Criteria

- ✅ CephObjectStore shows `Ready` phase
- ✅ BackupStorageLocation shows `Available` 
- ✅ Test backup completes with `Completed` or `PartiallyFailed` status
- ✅ Backup files visible in Ceph RGW bucket
- ✅ Scheduled backups running automatically

**Congratulations! You now have enterprise-grade Kubernetes backups running on Ceph! 🚀**