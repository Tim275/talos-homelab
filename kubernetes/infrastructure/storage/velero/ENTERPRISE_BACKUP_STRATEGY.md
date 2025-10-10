# 🏢 Enterprise Velero Backup Strategy

## 📊 The Tier System (RPO/RTO Based)

**RPO** = Recovery Point Objective = "Wie viel Datenverlust ist akzeptabel?"
**RTO** = Recovery Time Objective = "Wie schnell muss System wieder online?"

---

## 🔴 TIER-0: Mission Critical
**"Wenn das weg ist, ist Business tot"**

### Was wird gesichert:
- **PostgreSQL Datenbanken**
  - N8N Production (Workflows, Credentials, Executions)
  - Authelia (User Sessions, 2FA Secrets)
  - LLDAP (User Directory, Groups, Passwords)

### Metriken:
- **RPO:** 6 Stunden (max 6h Datenverlust akzeptabel)
- **RTO:** 15 Minuten (muss in 15min wieder laufen)
- **Schedule:** `0 */6 * * *` (Alle 6 Stunden: 00:00, 06:00, 12:00, 18:00)
- **Retention:** 7 Tage (28 Backups total)
- **Storage:** ~2GB pro Backup = **56GB total**

### Backup Methode:
```yaml
✅ CSI Volume Snapshots (fast, consistent)
✅ Pre-Hooks: PostgreSQL CHECKPOINT (flush WAL)
✅ Label Selector: cnpg.io/cluster
✅ Includes: PVCs, Secrets, ConfigMaps
```

### Warum alle 6h?
- Bei Datenverlust verlierst du max 6h Workflows
- 4x täglich = genug Restore-Punkte für Compliance
- Nicht zu häufig (Storage/Performance Balance)

---

## 🟠 TIER-1: Business Critical
**"Wichtig, aber rebuild möglich in paar Stunden"**

### Was wird gesichert:
- **Stateful Applications (ohne DB)**
  - N8N Application Manifests (Deployment, Service, ConfigMaps)
  - Persistent Volume Claims (außer PostgreSQL - das ist Tier-0)
  - Application Secrets (API Keys, Webhooks, OAuth)
  - Kafka Topics (wenn vorhanden)

### Metriken:
- **RPO:** 24 Stunden
- **RTO:** 1 Stunde
- **Schedule:** `0 2 * * *` (Täglich um 02:00 Uhr)
- **Retention:** 30 Tage
- **Storage:** ~500MB pro Backup = **15GB total**

### Backup Methode:
```yaml
✅ Full Namespace Backup
✅ Includes: Deployments, Services, ConfigMaps, Secrets
✅ CSI Snapshots für PVCs
✅ Application-level consistency (Pre-Hooks wenn nötig)
```

### Warum täglich?
- Config changes passieren täglich (GitOps updates)
- 30 Tage Retention = compliance ready (monthly audit)
- Nachts wenig Traffic = backup impact minimal

---

## 🟡 TIER-2: Important Configuration
**"Cluster Config - rebuild dauert, aber keine Daten verloren"**

### Was wird gesichert:
- **Infrastructure as Code**
  - ArgoCD Applications & AppProjects
  - Sealed Secrets (encrypted values)
  - Cert-Manager (Certificates, Issuers, ClusterIssuers)
  - Gateway API (HTTPRoutes, Gateways)
  - NetworkPolicies (Cilium, Calico)
  - RBAC (ClusterRoles, RoleBindings)
  - Service Meshes (Istio VirtualServices, DestinationRules)

### Metriken:
- **RPO:** 24 Stunden
- **RTO:** 4 Stunden
- **Schedule:** `0 3 * * *` (Täglich um 03:00 Uhr - nach Tier-1)
- **Retention:** 14 Tage
- **Storage:** ~200MB pro Backup = **2.8GB total**

### Backup Methode:
```yaml
✅ Label Selector: backup.tier=tier2
✅ Cluster-scoped resources included
✅ No volume snapshots needed (config only)
✅ Namespace: argocd, cert-manager, gateway, istio-system
```

### Warum täglich?
- GitOps macht auto-deploy, aber Backup = safety net
- 14 Tage reichen (config changes sind in Git sowieso)
- Schneller restore als komplettes ArgoCD re-sync

---

## 🟢 TIER-3: Infrastructure State
**"Nice to have - schneller restore als neu deployen"**

### Was wird gesichert:
- **Operator State & Monitoring**
  - Rook-Ceph Config (CephCluster, CephObjectStore, CephBlockPool)
  - Prometheus Operator CRDs (ServiceMonitors, PodMonitors)
  - Grafana Dashboards (als ConfigMaps)
  - AlertManager Configuration
  - Cilium CNI Config (CiliumNetworkPolicies)

### Metriken:
- **RPO:** 7 Tage
- **RTO:** 8 Stunden
- **Schedule:** `0 1 * * 0` (Wöchentlich Sonntag 01:00)
- **Retention:** 60 Tage (8 Backups total)
- **Storage:** ~100MB pro Backup = **800MB total**

### Backup Methode:
```yaml
✅ Cluster-wide CRDs backup
✅ Label Selector: backup.tier=tier3
✅ Namespace: rook-ceph, monitoring, observability
```

### Warum wöchentlich?
- Ändert sich sehr selten (infrastructure drift minimal)
- Kann notfalls neu deployed werden (IaC in Git)
- 60 Tage = audit compliance für Infrastruktur-Changes

---

## ⏰ Backup Timeline (Daily Schedule)

```
┌─────────────────────────────────────────────────────┐
│ TÄGLICH:                                            │
├─────────────────────────────────────────────────────┤
│ 00:00  Tier-0 Database Backup (6h cycle #1)        │
│ 02:00  Tier-1 Applications Backup (daily)          │
│ 03:00  Tier-2 Configuration Backup (daily)         │
│ 06:00  Tier-0 Database Backup (6h cycle #2)        │
│ 12:00  Tier-0 Database Backup (6h cycle #3)        │
│ 18:00  Tier-0 Database Backup (6h cycle #4)        │
├─────────────────────────────────────────────────────┤
│ WÖCHENTLICH (Sonntag):                             │
├─────────────────────────────────────────────────────┤
│ 01:00  Tier-3 Infrastructure Backup (weekly)       │
└─────────────────────────────────────────────────────┘
```

### Warum gestaffelt?
- **I/O Load Distribution:** Verhindert I/O spikes (nicht alle gleichzeitig)
- **Dependency Order:** Tier-1 nach Tier-0 (Apps nach DB)
- **Off-Peak Hours:** Nachts wenig Load = schnellere Backups
- **Parallel Execution:** Verschiedene Namespaces = kein Lock-Contention

---

## 💾 Storage Kalkulation (30 Tage)

```
Tier-0 (7d, 4x daily):   28 × 2GB   = 56.0 GB
Tier-1 (30d, daily):     30 × 500MB = 15.0 GB
Tier-2 (14d, daily):     14 × 200MB =  2.8 GB
Tier-3 (60d, weekly):     8 × 100MB =  0.8 GB
                                     ─────────
Total Storage Required:               74.6 GB
```

**Ceph RGW S3 Bucket:** 100GB reserviert ✅
**S3 Versioning:** Enabled (ransomware protection) ✅
**Lifecycle Policy:** 90 Tage object retention ✅

---

## 🎯 Aktueller Status vs. Enterprise Target

### ✅ Aktuell Deployed:
```yaml
n8n-prod-daily:
  Status: ✅ Running
  Schedule: "0 2 * * *" (täglich 02:00)
  Retention: 7 Tage
  Scope: n8n-prod namespace only
  Tier: Tier-1 equivalent (aber nur N8N)
```

### ❌ Was Fehlt (To-Do):
- [ ] **Tier-0:** 6h Database Backups (Authelia, LLDAP fehlen)
- [ ] **Tier-1:** Erweitert um Kafka, Redis, andere stateful apps
- [ ] **Tier-2:** Config/Secrets Backups (ArgoCD, Cert-Manager)
- [ ] **Tier-3:** Infrastructure State Backups (Ceph, Operators)
- [ ] **Monitoring:** Prometheus Alerts für Backup Failures
- [ ] **Dashboard:** Grafana Backup Success Rate Dashboard

---

## 🚨 Disaster Recovery Procedures

### RTO Compliance Test (Quarterly):
```bash
# 1. Create test restore namespace
kubectl create namespace n8n-restore-test

# 2. Restore latest Tier-0 backup
velero restore create n8n-test-restore \
  --from-backup n8n-prod-daily-20251010020010 \
  --namespace-mappings n8n-prod:n8n-restore-test

# 3. Validate application startup time
kubectl get pods -n n8n-restore-test -w

# 4. Verify data integrity
kubectl exec -n n8n-restore-test deploy/n8n -- \
  psql -U postgres -c "SELECT COUNT(*) FROM workflows;"

# 5. Cleanup
kubectl delete namespace n8n-restore-test
```

### Backup Failure Response (Runbook):
```bash
# 1. Check last successful backup
velero backup get | grep -v Deleting

# 2. If > 24h old, trigger manual backup
velero backup create manual-emergency-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces n8n-prod \
  --wait

# 3. Check Velero logs
kubectl logs -n velero -l deploy=velero --tail=100

# 4. Verify S3 storage location health
velero backup-location get
```

---

## 📊 Monitoring & Alerting

### Prometheus Metrics (to be configured):
```promql
# Backup age (should be < 6h for Tier-0)
time() - velero_backup_last_successful_timestamp{schedule="tier0-databases-6h"}

# Backup failures (should be 0)
velero_backup_failure_total

# Backup duration (should be < 5min)
velero_backup_duration_seconds{schedule=~".*"}
```

### Alert Rules (to be deployed):
```yaml
- alert: VeleroBackupFailed
  expr: velero_backup_failure_total > 0
  for: 15m
  annotations:
    summary: "Velero backup failed for {{ $labels.schedule }}"

- alert: VeleroBackupTooOld
  expr: time() - velero_backup_last_successful_timestamp > 86400
  annotations:
    summary: "No successful backup in 24h for {{ $labels.schedule }}"
```

---

## 🔐 Security Best Practices

### Backup Encryption:
```yaml
# Already configured via Rook-Ceph RGW:
✅ Server-Side Encryption (SSE-S3)
✅ TLS in transit (HTTPS to S3)
✅ RBAC for Velero ServiceAccount
✅ Sealed Secrets encrypted at rest
```

### Access Control:
```yaml
# Velero RBAC (already configured):
- ClusterRole: cluster-admin (for cluster-scoped resources)
- Namespace: velero (isolated)
- S3 Credentials: Kubernetes Secret (not in Git)
```

### Ransomware Protection:
```yaml
✅ S3 Versioning enabled (can recover from encryption attacks)
✅ Immutable backups (90 day lifecycle before deletion)
✅ Off-cluster storage (Ceph RGW on separate nodes)
⚠️  Optional: MFA Delete (extra protection for S3 bucket)
```

---

## 📚 References

- [Velero Best Practices](https://velero.io/docs/main/best-practices/)
- [Disaster Recovery Patterns](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [RPO/RTO Calculation](https://www.ibm.com/cloud/learn/rpo-vs-rto)
- [PostgreSQL Backup Hooks](https://velero.io/docs/main/backup-hooks/)

---

**Last Updated:** 2025-10-10
**Maintained By:** Tim275 (Homelab Infrastructure)
**Review Cycle:** Quarterly (or after major incidents)
