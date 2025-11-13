# 🛡️ ENTERPRISE BACKUP STRATEGY

**Velero-based disaster recovery for Talos Kubernetes Homelab**

---

## 📊 BACKUP TIERS & SCHEDULES

### **Tier 0: Critical Databases** 🔴
**Schedule**: Every 6 hours (00:00, 06:00, 12:00, 18:00)
**Retention**: 7 days
**What**: PostgreSQL, Redis, LLDAP, Authelia credentials

**Why 6 hours?**
- N8N workflows change frequently during development
- User/group changes in LLDAP need frequent snapshots
- Authelia session data needs short RPO (Recovery Point Objective)

**Namespaces**:
- `lldap` - User directory
- `authelia` - Identity provider
- `n8n-dev` - N8N development database
- `n8n-prod` - N8N production database
- `postgres-operator` - CloudNativePG clusters

---

### **Tier 1: Stateful Applications** 🟠
**Schedule**: Daily at 02:00 AM
**Retention**: 14 days
**What**: N8N workflows, Grafana dashboards, ArgoCD configurations

**Why daily?**
- Grafana dashboards are stable (low change frequency)
- ArgoCD Application configs change occasionally
- N8N workflows benefit from daily point-in-time recovery

**Namespaces**:
- `n8n-dev` - N8N dev environment
- `n8n-prod` - N8N production environment
- `grafana` - Grafana dashboards + datasources
- `argocd` - ArgoCD applications + settings

---

### **Tier 2: Platform Services** 🟡
**Schedule**: Weekly on Sunday at 03:00 AM
**Retention**: 30 days
**What**: Identity platform, TLS certificates, Sealed Secrets, Service Mesh

**Why weekly?**
- Platform services change rarely (monthly updates)
- Certificates auto-renew (weekly snapshot sufficient)
- Sealed Secrets need long-term retention for audit

**Namespaces**:
- `lldap` - User directory backup
- `authelia` - OIDC provider backup
- `cert-manager` - TLS certificates
- `sealed-secrets` - Encrypted secrets
- `istio-system` - Service mesh configuration

---

### **Tier 3: Full Cluster Backup** 🔵
**Schedule**: Monthly on 1st at 04:00 AM
**Retention**: 90 days (3 months)
**What**: Complete cluster state for disaster recovery

**Why monthly?**
- Full cluster recovery baseline
- Compliance requirement (90-day audit trail)
- Infrastructure rarely changes (Talos nodes stable)

**Excludes**: `kube-system`, `kube-public`, `kube-node-lease`

**Includes Pre-Backup Hook**:
- N8N workflow export to `/data/backups/workflows.json`

---

### **Tier 4: Configuration Backup** ⚡
**Schedule**: Every 4 hours
**Retention**: 3 days
**What**: ArgoCD Applications, Kyverno Policies, Network Policies (no PVs)

**Why 4 hours?**
- GitOps changes happen frequently during development
- Policy changes need quick rollback capability
- Lightweight backup (no volume snapshots)

**Resources Backed Up**:
- `applications.argoproj.io`
- `applicationsets.argoproj.io`
- `clusterpolicies.kyverno.io`
- `networkpolicies.networking.k8s.io`

---

## 📅 BACKUP CALENDAR OVERVIEW

| Time     | Tier 0 | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|----------|--------|--------|--------|--------|--------|
| 00:00    | ✅ DB   |        |        |        | ✅ CFG  |
| 02:00    |        | ✅ APP  |        |        |        |
| 04:00    | ✅ DB   |        |        | ✅ FULL |        |
| 06:00    | ✅ DB   |        |        |        |        |
| 08:00    |        |        |        |        | ✅ CFG  |
| 12:00    | ✅ DB   |        |        |        | ✅ CFG  |
| 16:00    |        |        |        |        | ✅ CFG  |
| 18:00    | ✅ DB   |        |        |        |        |
| 20:00    |        |        |        |        | ✅ CFG  |
| Sunday 03:00 |    |        | ✅ PLT  |        |        |
| 1st 04:00 |      |        |        | ✅ FULL |        |

---

## 🎯 WHAT SHOULD BE BACKED UP?

### ✅ **YES - Critical Data**
1. **N8N Workflows** (Tier 0 + Tier 1)
   - Development workflows: `n8n-dev` namespace
   - Production workflows: `n8n-prod` namespace
   - PostgreSQL databases + PersistentVolumes

2. **Identity & Auth** (Tier 0 + Tier 2)
   - LLDAP user database + custom attributes
   - Authelia OIDC configuration + secrets
   - HMAC secrets, RSA keys for OIDC

3. **Platform State** (Tier 1 + Tier 2)
   - Grafana dashboards (created dashboards, not imported)
   - ArgoCD Applications (deployed applications)
   - TLS certificates (cert-manager)

4. **Configuration** (Tier 4)
   - Kyverno Policies (cluster-wide governance)
   - Network Policies (security rules)
   - ArgoCD ApplicationSets

### ❌ **NO - Don't Backup**
1. **Logs** - Elasticsearch indices (too large, can be re-collected)
2. **Metrics** - Prometheus TSDB (ephemeral, 30-day retention)
3. **Cache** - Redis cache data (ephemeral)
4. **Container Images** - Stored in container registry
5. **Static Config** - Already in Git (GitOps source of truth)

---

## 💾 STORAGE BACKEND

**Backend**: MinIO S3-compatible object storage
**Location**: `http://minio.minio.svc.cluster.local:9000`
**Bucket**: `velero-backups`
**Region**: `homelab`

**Volume Snapshots**: CSI snapshots (Rook-Ceph)

---

## 🔄 RESTORE PROCEDURES

### **Restore N8N Workflows (Example)**
```bash
# List available backups
velero backup get | grep tier0-databases

# Restore specific backup
velero restore create n8n-restore \
  --from-backup tier0-databases-6h-20251004120000 \
  --include-namespaces n8n-prod

# Check restore status
velero restore describe n8n-restore
```

### **Restore LLDAP + Authelia (Identity Platform)**
```bash
# Restore from Tier 2 weekly backup
velero restore create identity-restore \
  --from-backup tier2-platform-weekly-20251001030000 \
  --include-namespaces lldap,authelia

# Verify OIDC still works
kubectl get pods -n lldap
kubectl get pods -n authelia
```

### **Full Cluster Disaster Recovery**
```bash
# 1. Install Velero on new cluster
kubectl apply -f kubernetes/infrastructure/storage/velero/

# 2. Restore from monthly full backup
velero restore create cluster-dr \
  --from-backup tier3-full-cluster-monthly-20251001040000

# 3. Wait for all resources to come up
kubectl get pods -A

# 4. Verify ArgoCD syncs from Git
kubectl get applications -n argocd
```

---

## 📈 MONITORING BACKUP HEALTH

**Prometheus Metrics**: Velero exports metrics on port 8085

**Key Metrics**:
- `velero_backup_success_total` - Successful backups
- `velero_backup_failure_total` - Failed backups
- `velero_backup_duration_seconds` - Backup duration
- `velero_backup_items_total` - Items backed up

**Grafana Dashboard**: Create alerts for failed backups

---

## 🔐 SECURITY CONSIDERATIONS

1. **Encryption at Rest**: MinIO encryption enabled
2. **Access Control**: Velero ServiceAccount with minimal RBAC
3. **Secrets**: Sealed Secrets for cloud credentials
4. **Immutability**: S3 bucket versioning + object lock (future)

---

## 📝 BACKUP LABELS & ANNOTATIONS

All resources that need backup should have:
```yaml
metadata:
  labels:
    backup.tier: tier0  # or tier1, tier2, tier3
  annotations:
    backup.velero.io/backup-volumes: "data,config"  # PVC names
```

**Example - N8N Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
  namespace: n8n-prod
  labels:
    backup.tier: tier0  # Critical database backup
    app.kubernetes.io/name: n8n
```

---

## 🎓 BEST PRACTICES IMPLEMENTED

✅ **3-2-1 Backup Rule** (Future):
- 3 copies of data
- 2 different storage types
- 1 offsite copy (Future: S3 replication to external provider)

✅ **Tiered Backup Strategy**: Different RPO/RTO for different data

✅ **Automated Scheduling**: No manual backup intervention

✅ **Pre-Backup Hooks**: Application-consistent backups (N8N export)

✅ **Monitoring**: Prometheus metrics + Grafana dashboards

✅ **Documentation**: Clear restore procedures

---

## 🚀 FUTURE IMPROVEMENTS

1. **Offsite Replication**: MinIO → AWS S3 / Backblaze B2
2. **Backup Testing**: Monthly restore drills
3. **Immutable Backups**: S3 Object Lock for ransomware protection
4. **Backup Encryption**: Client-side encryption before upload
5. **Multi-Cluster DR**: Restore backups to different cluster

---

**Last Updated**: 2025-10-04
**Owner**: Tim275
**Next Review**: 2025-11-01
