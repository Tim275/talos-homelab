# 🎯 Pragmatic Velero Backup Strategy for Homelab

**Philosophy**: Only backup what **CANNOT be restored from Git/ArgoCD Bootstrap**.

---

## 🤔 **The "Cluster Destroyed by Bomb" Scenario**

### **What happens if cluster is completely gone?**

```bash
# Step 1: Rebuild Talos Cluster (1 hour)
tofu apply

# Step 2: Bootstrap ArgoCD (5 minutes)
kubectl apply -k kubernetes/bootstrap/

# Step 3: ArgoCD deploys everything from Git (30 minutes)
# ✅ All infrastructure: Cert-Manager, Gateway, Cilium, Rook-Ceph
# ✅ All platform: Operators, Monitoring, Observability
# ✅ All apps: N8N deployment, Redis, Kafka

# Step 4: Restore ONLY databases from Velero (15 minutes)
velero restore create --from-backup tier0-databases-latest

# ✅ DONE - Cluster fully restored!
```

**Total Recovery Time: ~2 hours**

---

## 🔴 **TIER-0: Databases Only (Cannot Recreate)**

### **What we backup:**

**1. N8N PostgreSQL Database**
```yaml
Why backup:
├── Workflows (your automation logic) ← UNIQUE DATA
├── Credentials (API keys, secrets) ← CANNOT RECREATE
├── Execution history (audit logs) ← HISTORICAL DATA
└── User settings (your account) ← CANNOT RECREATE

If lost:
└── 🔴 CRITICAL: All workflows gone, must rebuild from memory
```

**2. Authelia PostgreSQL (when deployed)**
```yaml
Why backup:
├── User sessions (active logins) ← STATEFUL
├── 2FA secrets (TOTP keys) ← CANNOT RECREATE
├── Login history (audit trail) ← HISTORICAL
└── OAuth tokens (active sessions) ← STATEFUL

If lost:
└── 🔴 CRITICAL: All users locked out, 2FA reset needed
```

**3. LLDAP Database (when deployed)**
```yaml
Why backup:
├── User accounts (tim275, etc.) ← UNIQUE DATA
├── Passwords (hashed) ← CANNOT RECREATE
├── Groups (admins, developers) ← CONFIGURATION
└── Group memberships (who is where) ← CONFIGURATION

If lost:
└── 🔴 CRITICAL: Identity system destroyed, all users gone
```

### **Backup Schedule:**
```yaml
Schedule: Every 6 hours (00:00, 06:00, 12:00, 18:00)
Retention: 7 days (28 backups total)
RPO: 6 hours max data loss
RTO: 15 minutes recovery time
Storage: ~2GB per backup = 56GB total
```

---

## ❌ **TIER-1/2/3: SKIP - Everything Else is in Git**

### **What we DON'T backup (and why):**

**1. Infrastructure (Operators, Controllers)**
```yaml
Examples:
├── ArgoCD (deployed from bootstrap/)
├── Cert-Manager (deployed from infrastructure/)
├── Sealed Secrets (deployed from infrastructure/)
├── Cilium CNI (deployed from infrastructure/)
├── Rook-Ceph (deployed from infrastructure/)
└── Gateway API (deployed from infrastructure/)

Why SKIP:
└── ✅ All YAML in Git
└── ✅ ArgoCD re-deploys automatically
└── ✅ Recovery time: 30 minutes (automatic)
```

**2. Platform Services (Databases, Messaging)**
```yaml
Examples:
├── CloudNativePG Operator (deployed from platform/)
├── Kafka Operator (deployed from platform/)
├── Redis (deployed from platform/)
└── InfluxDB (deployed from platform/)

Why SKIP:
└── ✅ All YAML in Git
└── ✅ ArgoCD re-deploys automatically
└── ✅ Only DATABASE DATA needs backup (Tier-0)
```

**3. Monitoring & Observability**
```yaml
Examples:
├── Prometheus (deployed from infrastructure/)
├── Grafana Dashboards (deployed from infrastructure/)
├── AlertManager (deployed from infrastructure/)
├── Loki (deployed from infrastructure/)
└── Jaeger (deployed from infrastructure/)

Why SKIP:
└── ✅ All dashboards in Git as GrafanaDashboard CRDs
└── ✅ ArgoCD re-deploys automatically
└── ✅ Historical metrics NOT critical (can rebuild)
```

**4. Configuration (Certs, Routes, Secrets)**
```yaml
Examples:
├── Certificate CRDs (cert-manager re-issues)
├── HTTPRoute CRDs (in Git)
├── SealedSecret CRDs (in Git, encrypted)
└── NetworkPolicy CRDs (in Git)

Why SKIP:
└── ✅ Cert-Manager re-issues certificates (1 hour)
└── ✅ All routes in Git
└── ✅ Sealed Secrets controller decrypts from Git
```

**5. Application Deployments**
```yaml
Examples:
├── N8N Deployment manifest (in Git)
├── N8N Service manifest (in Git)
├── N8N ConfigMaps (in Git)
└── N8N HTTPRoute (in Git)

Why SKIP:
└── ✅ ArgoCD re-deploys from apps/ directory
└── ✅ Only N8N DATABASE needs backup (Tier-0)
```

**6. Stateful App State (Redis, Kafka)**
```yaml
Examples:
├── Redis cache data (ephemeral)
├── Kafka topics (can rebuild)
└── InfluxDB metrics (historical, not critical)

Why SKIP:
└── ✅ Redis = cache, can rebuild
└── ✅ Kafka = message queue, can reprocess
└── ✅ InfluxDB = metrics, not critical for recovery
```

---

## 📊 **Backup Architecture**

```
┌─────────────────────────────────────────────────────────┐
│ DISASTER SCENARIO: Cluster Destroyed                    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 1: Rebuild Talos Cluster (1h)                      │
│ └── tofu apply                                          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 2: Bootstrap ArgoCD (5min)                         │
│ └── kubectl apply -k kubernetes/bootstrap/              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 3: ArgoCD GitOps Deployment (30min)                │
│ ├── Infrastructure layer (controllers, network, etc.)   │
│ ├── Platform layer (databases, messaging)               │
│ └── Apps layer (n8n, authelia, lldap)                   │
│                                                          │
│ ✅ Result: Everything deployed EXCEPT database data     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 4: Restore Tier-0 Databases (15min)                │
│ ├── velero restore create --from-backup tier0-latest    │
│ ├── N8N PostgreSQL data restored                        │
│ ├── Authelia PostgreSQL data restored                   │
│ └── LLDAP database restored                             │
│                                                          │
│ ✅ Result: ALL unique data restored                     │
└─────────────────────────────────────────────────────────┘
                          ↓
                    ✅ CLUSTER FULLY OPERATIONAL
```

---

## 🎯 **Current Implementation**

### **Deployed Schedules:**

**1. tier0-databases-6h** (Primary Schedule)
```yaml
File: kubernetes/infrastructure/storage/velero/tier0-databases-6h-schedule.yaml
Schedule: "0 */6 * * *" (every 6 hours)
Includes:
  - n8n-prod namespace (PostgreSQL + Redis + App)
  - authelia namespace (when deployed)
  - lldap namespace (when deployed)
Retention: 7 days (168h)
Label: backup.tier=tier0
```

**Cron Schedule Explained:**
```
00:00 → Backup #1 (midnight)
06:00 → Backup #2 (morning)
12:00 → Backup #3 (noon)
18:00 → Backup #4 (evening)

= 4 backups per day × 7 days = 28 backups total
```

---

## 💾 **Storage Calculation**

```
N8N PostgreSQL: ~500MB per backup
Authelia PostgreSQL: ~100MB per backup
LLDAP Database: ~50MB per backup
App manifests (K8s YAML): ~50MB per backup
────────────────────────────────────────
Total per backup: ~700MB

4 backups/day × 7 days = 28 backups
28 × 700MB = ~20GB total storage

Ceph RGW S3 Bucket: 100GB reserved ✅
Utilization: 20% (plenty of headroom)
```

---

## 🔧 **PostgreSQL Consistency Hooks**

All database backups use pre-backup hooks for consistency:

```yaml
Pre-Backup Hook:
  Command: psql -U postgres -c "CHECKPOINT;"
  Purpose: Flush WAL (Write-Ahead Log) to disk
  Timeout: 30s
  OnError: Continue (don't fail backup if hook fails)

Why needed:
└── Ensures PostgreSQL data is fully written to disk
└── Prevents corruption in restored backup
└── Industry best practice for database backups
```

---

## 🚨 **Disaster Recovery Procedures**

### **Scenario 1: Single Database Corruption**

```bash
# 1. Identify corrupted database
kubectl get pods -n n8n-prod
# Output: n8n-postgres-1 CrashLoopBackOff

# 2. List available backups
velero backup get --selector backup.tier=tier0
# Pick latest successful backup

# 3. Stop application (prevent writes during restore)
kubectl scale deployment -n n8n-prod n8n-main --replicas=0

# 4. Restore database
velero restore create n8n-emergency-restore \
  --from-backup tier0-databases-6h-20251010120000 \
  --include-namespaces n8n-prod

# 5. Wait for restore completion
velero restore describe n8n-emergency-restore

# 6. Verify database health
kubectl exec -n n8n-prod n8n-postgres-1 -- \
  psql -U postgres -c "SELECT COUNT(*) FROM workflows;"

# 7. Restart application
kubectl scale deployment -n n8n-prod n8n-main --replicas=1

# 8. Verify application health
kubectl get pods -n n8n-prod -w
```

**Expected Recovery Time: 15-20 minutes**

---

### **Scenario 2: Complete Cluster Loss**

```bash
# 1. Rebuild Talos cluster
cd tofu/
tofu apply
# Wait: ~45 minutes

# 2. Verify cluster access
export KUBECONFIG=tofu/output/kube-config.yaml
kubectl get nodes
# Expected: 7 nodes ready

# 3. Bootstrap ArgoCD
kubectl apply -k kubernetes/bootstrap/
# Wait: ~5 minutes

# 4. Wait for GitOps deployment
kubectl get applications -n argocd -w
# Wait until all applications "Healthy & Synced": ~30 minutes

# 5. Configure Velero CLI for S3 access
# (Velero is deployed by ArgoCD, but needs S3 credentials)
export AWS_ACCESS_KEY_ID=<from sealed-secret>
export AWS_SECRET_ACCESS_KEY=<from sealed-secret>

# 6. List available backups
velero backup get
# Should see backups from before cluster loss

# 7. Restore all Tier-0 databases
velero restore create cluster-disaster-recovery \
  --from-backup tier0-databases-6h-<latest> \
  --wait

# 8. Verify database restoration
kubectl get pods -n n8n-prod
kubectl get pods -n authelia
kubectl get pods -n lldap

# 9. Verify application functionality
# Test N8N login, Authelia login, LLDAP queries

# 10. Monitor for issues
kubectl get events -A --sort-by='.lastTimestamp'
```

**Expected Recovery Time: ~2 hours**

---

## 📊 **Monitoring & Alerting**

### **Prometheus Metrics to Monitor:**

```promql
# Backup age (should be < 6h for Tier-0)
time() - velero_backup_last_successful_timestamp{schedule="tier0-databases-6h"}

# Backup failures (should be 0)
velero_backup_failure_total

# Backup duration (should be < 5min)
velero_backup_duration_seconds{schedule="tier0-databases-6h"}
```

### **Recommended Alerts:**

```yaml
- alert: VeleroTier0BackupFailed
  expr: velero_backup_failure_total{schedule="tier0-databases-6h"} > 0
  for: 15m
  annotations:
    summary: "CRITICAL: Tier-0 database backup failed!"
    description: "Last backup failed {{ $value }} times"

- alert: VeleroTier0BackupTooOld
  expr: time() - velero_backup_last_successful_timestamp{schedule="tier0-databases-6h"} > 21600
  annotations:
    summary: "WARNING: No Tier-0 backup in 6+ hours"
    description: "Last successful backup was {{ $value }}s ago"
```

---

## 🔐 **Security & Compliance**

### **Encryption:**
```yaml
✅ S3 Server-Side Encryption (SSE-S3) - Ceph RGW
✅ TLS in transit (HTTPS to S3 endpoint)
✅ RBAC for Velero ServiceAccount
✅ Sealed Secrets encrypted at rest
```

### **Access Control:**
```yaml
Velero RBAC:
├── ServiceAccount: velero (namespace: velero)
├── ClusterRole: cluster-admin (full backup/restore access)
└── S3 Credentials: Sealed Secret (not in Git)
```

### **Ransomware Protection:**
```yaml
✅ S3 Versioning enabled (can recover from encryption attacks)
✅ 7-day retention (28 versions per database)
✅ Off-cluster storage (Ceph RGW on separate storage nodes)
⚠️  Optional: MFA Delete (extra S3 bucket protection)
```

---

## 📚 **References**

- [Velero Best Practices](https://velero.io/docs/main/best-practices/)
- [Kubernetes Backup Strategies](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [PostgreSQL Backup Hooks](https://velero.io/docs/main/backup-hooks/)
- [GitLab Disaster Recovery Postmortem](https://about.gitlab.com/blog/2017/02/01/gitlab-dot-com-database-incident/)

---

**Last Updated:** 2025-10-10
**Maintained By:** Tim275 (Homelab Infrastructure)
**Review Cycle:** Quarterly (or after major incidents)
