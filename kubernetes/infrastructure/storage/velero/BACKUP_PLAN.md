# 🛡️ Enterprise Disaster Recovery & Backup Strategy

**Projekt**: Talos Homelab Kubernetes Cluster
**Ziel**: Zero Data Loss bei Hardware-Ausfall, Blitz, Brand, Einbruch
**Standard**: 3-2-1-1-0 Rule (Enterprise Best Practice)

---

## 🔥 DISASTER RECOVERY SZENARIO

### **Katastrophe: Blitz zerstört alle Server**

**Was überlebt?**
- ❌ Production Data (Ceph RBD) → VERLOREN
- ❌ Local Backups (Ceph RGW) → VERLOREN
- ✅ **Offsite Backup (Cloudflare R2)** → ÜBERLEBT!
- ✅ **Offline Backup (Externe HDD)** → ÜBERLEBT!

---

## 📋 3-2-1-1-0 BACKUP RULE

### **Was bedeutet das?**
- **3** Kopien deiner Daten (1 Production + 2 Backups)
- **2** verschiedene Medien (z.B. SSD Cluster + Cloud Storage)
- **1** Offsite Backup (außerhalb des Clusters/Gebäudes)
- **1** Offline/Air-Gapped Backup (kein Netzwerkzugriff)
- **0** Fehler bei Backup-Verifikation (regelmäßige Restore-Tests!)

### **Aktuelle Implementierung:**
```
┌─────────────────────────────────────────────────┐
│  BACKUP STRATEGIE (3-2-1-1-0)                  │
├─────────────────────────────────────────────────┤
│  3 Kopien:                                      │
│    1. Production (Ceph RBD PVCs)               │
│    2. Local Backup (Ceph RGW S3)               │
│    3. Offsite (Cloudflare R2) → TODO           │
│                                                  │
│  2 Medien:                                      │
│    - SSD (Ceph Cluster)                        │
│    - Cloud (R2 Object Storage) → TODO          │
│                                                  │
│  1 Offsite:                                     │
│    - Cloudflare R2 → TODO                      │
│                                                  │
│  1 Offline:                                     │
│    - Externe HDD (Monthly) → TODO              │
└─────────────────────────────────────────────────┘
```

---

## 🎯 MULTI-TIER BACKUP STRATEGIE

### **Tier 0: Critical Databases** ⭐ HOMELAB OPTIMIERT
- **Frequency**: Every 24h (3 AM)
- **What**: PostgreSQL, Redis, LLDAP, Auth secrets
- **Namespaces**: n8n-prod, n8n-dev, lldap, authelia
- **Retention**: 7 days
- **RPO**: 24h max data loss
- **Why 24h?**: Homelab = weniger kritisch als Production, spart Storage

### **Tier 1: Stateful Applications**
- **Frequency**: Daily (2 AM)
- **What**: N8N workflows, Grafana dashboards, ArgoCD config
- **Retention**: 14 days
- **Includes**: PVC snapshots via CSI

### **Tier 2: Platform Services**
- **Frequency**: Weekly (Sunday 3 AM)
- **What**: Identity platform, Cert-Manager, Sealed Secrets
- **Retention**: 30 days

### **Tier 3: Full Cluster Backup** 💎
- **Frequency**: Monthly (1st day, 4 AM)
- **What**: Complete cluster state
- **Retention**: 90 days
- **Special**: Pre-backup hooks (N8N workflow export)

### **Tier 4: Configuration**
- **Frequency**: Every 4h
- **What**: ArgoCD apps, Kyverno policies, NetworkPolicies
- **Retention**: 3 days (lightweight, no PVs)

---

## 🔄 COMPLETE DISASTER RECOVERY WORKFLOW

### **Phase 1: Hardware Loss (Blitz/Brand/Einbruch)**

#### **Schritt 1: Neue Hardware + Cluster Bootstrap (25h)**
```bash
# 1. Neue Server bestellen/kaufen (24h delivery)
# 2. Talos Kubernetes deployen (1h)
cd tofu/
tofu apply -target=module.talos

# 3. Verify cluster
kubectl get nodes
# All nodes should be Ready
```

#### **Schritt 2: Infrastructure Bootstrap (30min)**
```bash
# Deploy ArgoCD + Core infrastructure
kubectl apply -k kubernetes/bootstrap/

# Wait for infrastructure
kubectl get applications -n argocd
# infrastructure, platform, apps should all be Synced
```

**Status**: ✅ Cluster running, Apps deploying - **ABER: Keine Daten!**

---

### **Phase 2: Velero Restore Setup (30min)**

#### **Schritt 3: Velero mit Offsite Backend konfigurieren**
```yaml
# kubernetes/infrastructure/storage/velero/values.yaml
configuration:
  backupStorageLocation:
    - name: cloudflare-r2-restore
      provider: aws
      bucket: talos-homelab-backups
      config:
        region: auto
        s3ForcePathStyle: "true"
        s3Url: https://<account-id>.r2.cloudflarestorage.com

credentials:
  useSecret: true
  existingSecret: r2-credentials  # Cloudflare R2 access key
```

#### **Schritt 4: Liste verfügbare Backups**
```bash
# Velero scannt automatisch R2 bucket
velero backup get

# Expected output:
# NAME                                  STATUS      CREATED                 EXPIRES
# tier3-full-cluster-monthly-20251001   Completed   2025-10-01 04:00:00     2025-12-30
# tier1-stateful-apps-daily-20251004    Completed   2025-10-04 02:00:00     2025-10-18
# tier0-databases-24h-20251005          Completed   2025-10-05 03:00:00     2025-10-12
```

---

### **Phase 3: Data Restore (30min)**

#### **Option A: Selective Restore (Einzelne App)**
```bash
# Restore nur N8N (schneller)
velero restore create n8n-restore \
  --from-backup tier0-databases-24h-20251005 \
  --include-namespaces n8n-prod \
  --wait

# Verify N8N data
kubectl exec -n n8n-prod deploy/n8n -- n8n list:workflow
```

#### **Option B: Full Cluster Restore (Komplett)**
```bash
# Restore gesamten Cluster state
velero restore create full-disaster-recovery \
  --from-backup tier3-full-cluster-monthly-20251001 \
  --exclude-namespaces kube-system,kube-public \
  --wait

# Monitor restore
velero restore describe full-disaster-recovery --details
```

---

### **Phase 4: Verification (30min)**

#### **Schritt 5: Data Integrity Checks**
```bash
# 1. PostgreSQL Databases
kubectl exec -n n8n-prod n8n-postgres-1 -- \
  psql -U n8n -c "SELECT COUNT(*) FROM workflow_entity"

# 2. N8N Workflows
kubectl exec -n n8n-prod deploy/n8n -- \
  n8n list:workflow

# 3. PVCs restored
kubectl get pvc -n n8n-prod
# n8n-data         Bound   pvc-xxx   2Gi    (restored)
# n8n-postgres-1   Bound   pvc-xxx   8Gi    (restored)

# 4. Secrets restored
kubectl get secrets -n n8n-prod
# n8n-db-creds, n8n-secrets should exist
```

---

## 📊 WAS VELERO WIEDERHERSTELLT

### **Kubernetes Resources** ✅
- Deployments, StatefulSets, DaemonSets
- Services, Ingresses, HTTPRoutes
- ConfigMaps, Secrets (encrypted at rest!)
- Custom Resource Definitions (CRDs)
- CloudNativePG Clusters, Kafka clusters

### **Persistent Data** ✅
- PostgreSQL databases (via CSI snapshots)
- N8N workflow files (via PVC snapshots)
- Grafana dashboards (via PVC snapshots)
- Elasticsearch indices (via PVC snapshots)

### **Was NICHT wiederhergestellt wird** ❌
- Pods (werden neu erstellt von Deployments)
- Nodes (neue Hardware, neue IPs)
- Running containers (werden von Kubelet neu gestartet)
- Prometheus metrics (ephemeral data)
- Loki logs (retention policy stattdessen)

---

## ⏱️ DISASTER RECOVERY TIMELINE

```
T+0h:     ⚡ Blitz zerstört alle Server
T+1h:     📦 Neue Server bestellen
T+24h:    🚚 Server ankommen
T+25h:    🔧 Talos Cluster deployen (1h)
T+25.5h:  🚀 Infrastructure bootstrap (30min)
T+26h:    💾 Velero R2 restore (30min)
T+26.5h:  ✅ Data verification (30min)
───────────────────────────────────────
TOTAL:    27 Stunden bis Full Recovery
RPO:      24h max data loss (Tier 0)
RTO:      27h max downtime
```

---

## 🏢 ENTERPRISE vs HOMELAB COMPARISON

### **Enterprise Production (Netflix/Spotify)**
- **RPO**: 1-6h (max data loss acceptable)
- **RTO**: < 1h (max downtime acceptable)
- **Backup Frequency**: Every 1-6h
- **Cost**: $10,000-50,000/month
- **Setup**: Active-Active Multi-Region, Real-time replication
- **Storage**: 3+ geographic regions
- **Compliance**: SOC2, ISO27001, GDPR

### **Dein Homelab (Optimiert)**
- **RPO**: 24h (Tier 0 daily backup)
- **RTO**: 24-48h (hardware replacement time)
- **Backup Frequency**: Daily/Weekly/Monthly
- **Cost**: < $5/month (Cloudflare R2)
- **Setup**: Single cluster + offsite backup
- **Storage**: Local + Cloud
- **Compliance**: Personal data protection

**Warum 24h statt 6h?**
- ✅ Homelab = nicht geschäftskritisch
- ✅ Spart 4x Storage (weniger snapshots)
- ✅ Weniger I/O load auf Ceph
- ✅ 24h data loss = akzeptabel für private Workflows

---

## 📦 N8N BACKUP DETAILS

### **Was wird bei N8N gebackupt?**

#### **1. PostgreSQL Database** ⭐ KRITISCH
- **PVC**: `n8n-postgres-1` (8Gi)
- **Content**:
  - Workflows (workflow_entity table)
  - Credentials (encrypted)
  - Execution history
  - Tags, variables
- **Backup Method**: CSI snapshot + CloudNativePG WAL archiving

#### **2. N8N Application Data**
- **PVC**: `n8n-data` (2Gi)
- **Content**:
  - Custom nodes
  - SSL certificates
  - Local files
- **Backup Method**: CSI snapshot

#### **3. Kubernetes Resources**
- Deployment: `n8n`
- Services: `n8n`, `n8n-postgres-rw`, `n8n-postgres-ro`
- Secrets: `n8n-db-creds`, `n8n-secrets`, `n8n-postgres-credentials`
- CloudNativePG Cluster: `n8n-postgres`

### **N8N Restore Prozess**
```bash
# 1. Restore PostgreSQL cluster + PVCs
velero restore create n8n-db \
  --from-backup tier0-databases-24h-latest \
  --include-namespaces n8n-prod \
  --include-resources clusters.postgresql.cnpg.io,persistentvolumeclaims

# 2. Wait for PostgreSQL ready
kubectl wait --for=condition=Ready pod/n8n-postgres-1 -n n8n-prod --timeout=300s

# 3. Restore N8N deployment
velero restore create n8n-app \
  --from-backup tier1-stateful-apps-daily-latest \
  --include-namespaces n8n-prod \
  --include-resources deployments,services,secrets

# 4. Verify workflows
kubectl exec -n n8n-prod deploy/n8n -- n8n list:workflow
```

---

## 🚀 TODO: COMPLETE DR SETUP

### **Phase 1: Local Backup (DONE ✅)**
- ✅ Velero installed
- ✅ Ceph RGW S3 backend configured
- ✅ Multi-tier backup schedules
- ✅ CSI snapshots enabled

### **Phase 2: Offsite Backup (TODO ⏳)**
- ⏳ Cloudflare R2 account setup
- ⏳ R2 bucket creation (`talos-homelab-backups`)
- ⏳ Velero backup sync to R2
- ⏳ Credentials management

### **Phase 3: Offline/Air-Gapped (TODO ⏳)**
- ⏳ Monthly backup export script
- ⏳ Encryption setup (GPG)
- ⏳ External HDD rotation (Bank safe deposit)

### **Phase 4: Verification (TODO ⏳)**
- ⏳ Quarterly restore test
- ⏳ RTO/RPO validation
- ⏳ Runbook documentation
- ⏳ Disaster recovery drill

---

## 🔐 BACKUP SECURITY

### **Encryption at Rest**
- **Ceph RBD**: Native LUKS encryption (optional)
- **Velero**: CSI snapshots encrypted via storage class
- **Offsite**: Client-side encryption before upload to R2

### **Encryption in Transit**
- **Ceph RGW → S3**: TLS 1.3
- **Cloudflare R2**: TLS 1.3
- **NAS Sync**: SSH/rsync over TLS

### **Secret Management**
- **Velero Credentials**: SealedSecret (encrypted in git)
- **S3 Access Keys**: Rotated every 90 days
- **Backup Passphrase**: Stored in separate KMS/password manager

---

## 📈 MONITORING & ALERTING

### **Prometheus Metrics**
```yaml
# Backup job success/failure
velero_backup_success_total
velero_backup_failure_total

# Last successful backup timestamp
velero_backup_last_successful_timestamp

# Backup duration
velero_backup_duration_seconds

# Storage usage
ceph_rgw_usage_bytes
ceph_rgw_quota_bytes
```

### **Critical Alerts**
```yaml
# Backup failed 2x in a row
- alert: VeleroBackupFailed
  expr: velero_backup_failure_total > 1
  severity: critical

# No backup in 48h
- alert: VeleroBackupStale
  expr: time() - velero_backup_last_successful_timestamp > 172800
  severity: critical

# S3 storage 90% full
- alert: BackupStorageFull
  expr: ceph_rgw_usage_bytes / ceph_rgw_quota_bytes > 0.9
  severity: warning
```

---

## 💰 COST ESTIMATION

### **On-Premise (Ceph RGW)**
- **Cost**: Sunk cost (already paid for hardware)
- **Capacity**: 1.14 TB available
- **Backup Size**: ~50-100 GB compressed
- **Retention**: 30 days = ~3 TB max

### **Offsite (Cloudflare R2)**
- **Storage**: $0.015/GB/month
- **Egress**: $0 (free!)
- **100 GB backup**: $1.50/month
- **Daily backups (30 days)**: ~$4.50/month

### **Total Cost**: < $5/month für Enterprise-Grade DR! 🎉

---

## 📚 REFERENCE DOCUMENTATION

- [Velero Docs](https://velero.io/docs/)
- [Disaster Recovery Best Practices](https://velero.io/docs/v1.14/disaster-case/)
- [Backup Hooks](https://velero.io/docs/v1.14/backup-hooks/)
- [CSI Snapshots](https://velero.io/docs/v1.14/csi/)
- [Ceph RGW S3](https://docs.ceph.com/en/latest/radosgw/s3/)
- [CloudNativePG Backup](https://cloudnative-pg.io/documentation/backup/)
- [3-2-1-1-0 Rule](https://www.veeam.com/blog/321-backup-rule.html)

---

**Maintained by**: Tim275
**Last Updated**: 2025-10-05
**Next Review**: Monthly (or after disaster recovery drill)
