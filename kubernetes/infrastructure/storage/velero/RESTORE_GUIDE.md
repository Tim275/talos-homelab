# 🔄 Velero Disaster Recovery & Restore Guide

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Disaster Scenarios](#disaster-scenarios)
3. [N8N Production Restore](#n8n-production-restore)
4. [Full Cluster Restore](#full-cluster-restore)
5. [Manual S3 Access](#manual-s3-access)
6. [Troubleshooting](#troubleshooting)

---

## 🔑 Prerequisites

### Required Credentials
Store these **SECURELY** outside the cluster (password manager, encrypted USB, etc.):

```bash
# Ceph RGW S3 Credentials
AWS_ACCESS_KEY_ID=P93KPZRN166HLMX0CLJ8
AWS_SECRET_ACCESS_KEY=BXoOZwWTIS3AthNB2cFW1IORxrqRmZRjkaSU5QF8

# S3 Endpoint & Bucket
S3_ENDPOINT=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
BUCKET=velero-backups
REGION=us-east-1
```

### Required Tools
- `kubectl` with cluster access
- `velero` CLI (optional, but recommended)
- `aws` CLI (for manual S3 access)

---

## 🚨 Disaster Scenarios

### Scenario 1: Single Application Loss (N8N)
**Timeline**: 15-30 minutes
**Data Loss**: None (if backup < 24h old)

### Scenario 2: Namespace Corruption
**Timeline**: 30-60 minutes
**Data Loss**: Minimal (depends on backup frequency)

### Scenario 3: Complete Cluster Loss
**Timeline**: 2-4 hours (hardware rebuild) + 1-2 hours (restore)
**Data Loss**: Last 24 hours (Tier 0 backup frequency)

### Scenario 4: Complete Hardware Loss
**Timeline**: 27 hours (hardware replacement) + 2-4 hours (restore)
**Data Loss**: Last 24 hours

---

## 🔄 N8N Production Restore

### Step 1: Verify Backup Exists

```bash
# List available backups
kubectl get backups -n velero

# Check specific backup status
kubectl describe backup n8n-prod-manual-test -n velero
```

**Expected Output:**
```
NAME                   AGE   STATUS
n8n-prod-manual-test   2h    PartiallyFailed (51/51 items backed up)
```

### Step 2: Create Restore Job

```bash
# Create restore from backup
cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: n8n-prod-restore-$(date +%Y%m%d-%H%M)
  namespace: velero
spec:
  backupName: n8n-prod-manual-test
  includedNamespaces:
    - n8n-prod
  restorePVs: true
EOF
```

### Step 3: Monitor Restore Progress

```bash
# Watch restore status
kubectl get restore -n velero -w

# Check detailed status
kubectl describe restore n8n-prod-restore-XXXXXX -n velero

# Check restored pods
kubectl get pods -n n8n-prod
```

### Step 4: Verify Data Integrity

```bash
# Check PostgreSQL is running
kubectl get clusters.postgresql.cnpg.io -n n8n-prod

# Check PVCs are bound
kubectl get pvc -n n8n-prod

# Test N8N application
kubectl port-forward -n n8n-prod svc/n8n 5678:80
# Open: http://localhost:5678
```

---

## 🌐 Full Cluster Restore

### Prerequisites
- **New Kubernetes cluster** running (Talos or any K8s)
- **Velero installed** on new cluster
- **Same S3 credentials** configured

### Step 1: Install Velero on New Cluster

```bash
# Install Velero with same configuration
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.backupStorageLocation[0].name=default \
  --set configuration.backupStorageLocation[0].provider=aws \
  --set configuration.backupStorageLocation[0].bucket=velero-backups \
  --set configuration.backupStorageLocation[0].config.region=us-east-1 \
  --set configuration.backupStorageLocation[0].config.s3ForcePathStyle=true \
  --set configuration.backupStorageLocation[0].config.s3Url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 \
  --set credentials.useSecret=true \
  --set credentials.secretContents.cloud="[default]\naws_access_key_id=P93KPZRN166HLMX0CLJ8\naws_secret_access_key=BXoOZwWTIS3AthNB2cFW1IORxrqRmZRjkaSU5QF8"
```

### Step 2: Verify S3 Connection

```bash
# Check BackupStorageLocation
kubectl get backupstoragelocation -n velero

# Should show: Available
```

### Step 3: List Available Backups

```bash
# Velero syncs backups from S3 automatically
kubectl get backups -n velero

# You should see all historical backups
```

### Step 4: Restore Critical Namespaces (Tier 0)

```bash
# Restore Identity Platform (LLDAP, Authelia)
velero restore create tier0-identity-restore \
  --from-backup tier2-platform-weekly-YYYYMMDD \
  --include-namespaces lldap,authelia

# Restore N8N Production
velero restore create tier0-n8n-restore \
  --from-backup tier0-databases-24h-YYYYMMDD \
  --include-namespaces n8n-prod

# Restore PostgreSQL Operator
velero restore create tier0-postgres-restore \
  --from-backup tier0-databases-24h-YYYYMMDD \
  --include-namespaces postgres-operator
```

### Step 5: Restore Platform Services (Tier 1-2)

```bash
# Restore Grafana
velero restore create tier1-grafana-restore \
  --from-backup tier1-stateful-apps-daily-YYYYMMDD \
  --include-namespaces grafana

# Restore ArgoCD
velero restore create tier1-argocd-restore \
  --from-backup tier1-stateful-apps-daily-YYYYMMDD \
  --include-namespaces argocd
```

### Step 6: Restore Infrastructure (Tier 2)

```bash
# Restore cert-manager
velero restore create tier2-cert-manager-restore \
  --from-backup tier2-platform-weekly-YYYYMMDD \
  --include-namespaces cert-manager

# Restore sealed-secrets
velero restore create tier2-sealed-secrets-restore \
  --from-backup tier2-platform-weekly-YYYYMMDD \
  --include-namespaces sealed-secrets
```

---

## 💾 Manual S3 Access

### Download Backup Manually (Emergency)

If Velero is unavailable, you can download backups directly from S3:

```bash
# Configure AWS CLI
export AWS_ACCESS_KEY_ID=P93KPZRN166HLMX0CLJ8
export AWS_SECRET_ACCESS_KEY=BXoOZwWTIS3AthNB2cFW1IORxrqRmZRjkaSU5QF8

# List all backups
aws s3 ls s3://velero-backups/backups/ \
  --endpoint-url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 \
  --region=us-east-1

# Download specific backup
aws s3 sync s3://velero-backups/backups/n8n-prod-manual-test/ ./n8n-backup/ \
  --endpoint-url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 \
  --region=us-east-1
```

### Backup Structure

```
backups/
└── n8n-prod-manual-test/
    ├── velero-backup.json          # Backup metadata
    ├── n8n-prod-manual-test.tar.gz # Kubernetes resources
    ├── n8n-prod-manual-test-logs.gz
    ├── n8n-prod-manual-test-podvolumes.json.gz
    └── n8n-prod-manual-test-volumesnapshots.json.gz
```

### Manual Restore from Downloaded Backup

```bash
# Extract Kubernetes resources
tar -xzf n8n-prod-manual-test.tar.gz

# Resources are in YAML format
cd resources/
kubectl apply -f namespaces/n8n-prod/
kubectl apply -f persistentvolumeclaims/n8n-prod/
kubectl apply -f deployments/n8n-prod/
# etc...
```

---

## 🔍 Troubleshooting

### Issue 1: Restore Stuck in "InProgress"

**Symptoms:**
```bash
kubectl get restore -n velero
NAME              BACKUP                  STATUS
n8n-restore-123   n8n-prod-manual-test   InProgress
```

**Solution:**
```bash
# Check Velero logs
kubectl logs -n velero deployment/velero -f

# Common issues:
# - PV provisioning slow (wait 5-10 min)
# - Storage class not available (check StorageClass)
# - Network issues (check S3 connectivity)
```

### Issue 2: "BackupStorageLocation Unavailable"

**Symptoms:**
```bash
kubectl get backupstoragelocation -n velero
NAME      PHASE
default   Unavailable
```

**Solution:**
```bash
# Check S3 credentials
kubectl get secret velero-s3-credentials -n velero -o yaml

# Test S3 connection manually
kubectl run test-s3 --rm -it --restart=Never \
  --image=amazon/aws-cli:2.15.0 \
  --env="AWS_ACCESS_KEY_ID=P93KPZRN166HLMX0CLJ8" \
  --env="AWS_SECRET_ACCESS_KEY=BXoOZwWTIS3AthNB2cFW1IORxrqRmZRjkaSU5QF8" \
  -- s3 ls s3://velero-backups/ \
  --endpoint-url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 \
  --region=us-east-1
```

### Issue 3: PostgreSQL Not Starting After Restore

**Symptoms:**
```bash
kubectl get pods -n n8n-prod
NAME              READY   STATUS
n8n-postgres-1    0/1     Error
```

**Solution:**
```bash
# Check PostgreSQL logs
kubectl logs -n n8n-prod n8n-postgres-1

# Common fix: Delete PVC and restore again
kubectl delete pvc n8n-postgres-1 -n n8n-prod
velero restore create n8n-restore-retry --from-backup n8n-prod-manual-test
```

### Issue 4: "No Backups Found"

**Symptoms:**
```bash
kubectl get backups -n velero
No resources found in velero namespace.
```

**Solution:**
```bash
# Velero syncs backups every 60s from S3
# Wait 2 minutes, then check again

# Force sync
kubectl delete pod -n velero -l app.kubernetes.io/name=velero

# Verify S3 bucket has backups
aws s3 ls s3://velero-backups/backups/ \
  --endpoint-url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 \
  --region=us-east-1
```

---

## 🎯 Recovery Time Objectives (RTO)

| Scenario | RTO | RPO | Data Loss |
|----------|-----|-----|-----------|
| Single app restore (N8N) | 15-30 min | 24h | Last backup |
| Namespace corruption | 30-60 min | 24h | Last backup |
| Cluster rebuild | 2-4 hours | 24h | Last backup |
| Complete hardware loss | 27+ hours | 24h | Last backup |

**RPO (Recovery Point Objective):** How much data can you lose?
- Tier 0: 24 hours (daily backups)
- Tier 1: 24 hours (daily backups)
- Tier 2: 7 days (weekly backups)
- Tier 3: 30 days (monthly backups)
- Tier 4: 4 hours (config backups)

**RTO (Recovery Time Objective):** How long does recovery take?
- Application restore: 15-30 minutes
- Full namespace: 30-60 minutes
- Complete cluster: 2-4 hours (+ hardware time)

---

## 🔐 Security Best Practices

### 1. Store Credentials Securely
```bash
# Use password manager (1Password, Bitwarden, etc.)
# Or encrypted file:
echo "AWS_ACCESS_KEY_ID=P93KPZRN166HLMX0CLJ8" > credentials.txt
echo "AWS_SECRET_ACCESS_KEY=BXoOZwWTIS3AthNB2cFW1IORxrqRmZRjkaSU5QF8" >> credentials.txt

# Encrypt
gpg -c credentials.txt

# Store credentials.txt.gpg in safe location
# Delete plaintext: rm credentials.txt
```

### 2. Test Restores Regularly
```bash
# Monthly restore test to separate namespace
velero restore create test-restore-$(date +%Y%m) \
  --from-backup tier0-databases-24h-latest \
  --namespace-mappings n8n-prod:n8n-restore-test
```

### 3. Offsite Backup Copy
```bash
# Sync backups to local machine monthly
aws s3 sync s3://velero-backups/ ./local-backup/ \
  --endpoint-url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80 \
  --region=us-east-1

# Store on external HDD/NAS
```

---

## 📊 Backup Verification Checklist

- [ ] Backup completed without errors (`kubectl get backup`)
- [ ] Backup visible in S3 bucket (`aws s3 ls`)
- [ ] Backup size is reasonable (> 0 bytes)
- [ ] Test restore to different namespace works
- [ ] Application starts correctly after restore
- [ ] Data integrity verified (spot-check database)

---

## 🚀 Quick Reference Commands

```bash
# List backups
kubectl get backups -n velero

# Create restore
velero restore create RESTORE_NAME --from-backup BACKUP_NAME

# Monitor restore
kubectl get restore -n velero -w

# Check Velero status
kubectl get backupstoragelocation -n velero

# Force backup sync from S3
kubectl delete pod -n velero -l app.kubernetes.io/name=velero

# Download backup manually
aws s3 sync s3://velero-backups/backups/BACKUP_NAME/ ./local/ \
  --endpoint-url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
```

---

## 📚 Additional Resources

- [Velero Documentation](https://velero.io/docs/)
- [Velero Restore Reference](https://velero.io/docs/main/restore-reference/)
- [Disaster Recovery Best Practices](https://velero.io/docs/main/disaster-case/)
- [CNPG Backup & Recovery](https://cloudnative-pg.io/documentation/current/backup_recovery/)

---

**Last Updated:** 2025-10-05
**Author:** Homelab Infrastructure Team
**Version:** 1.0
