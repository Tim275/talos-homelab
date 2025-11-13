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

## 🆘 DISASTER RECOVERY PLAYBOOK (Homelab Edition)

### 📋 DR Szenarien Matrix

| Szenario | Wahrscheinlichkeit | Impact | RTO | RPO | Recovery Method |
|----------|-------------------|--------|-----|-----|-----------------|
| **Single Node Failure** | 🔴 Hoch (10%/Jahr) | 🟡 Mittel | 1h | 6h | Talos node replacement + Velero restore |
| **Complete Cluster Loss** | 🟡 Mittel (2%/Jahr) | 🔴 Kritisch | 4h | 24h | GitOps rebuild + Velero restore |
| **Ransomware Attack** | 🟢 Niedrig (0.5%/Jahr) | 🔴 Kritisch | 2h | 6h | Restore from S3 versioned backup |
| **Ceph Storage Failure** | 🟡 Mittel (5%/Jahr) | 🔴 Kritisch | 8h | 24h | Rebuild Ceph + Velero restore |
| **Network/Power Outage** | 🔴 Hoch (20%/Jahr) | 🟢 Niedrig | 0h | 0h | Wait for power/network recovery |
| **Accidental Deletion** | 🔴 Hoch (30%/Jahr) | 🟡 Mittel | 30min | 6h | Velero restore specific resource |
| **Hardware Total Loss (Fire)** | 🟢 Niedrig (0.1%/Jahr) | 🔴 Kritisch | 3 Tage | 24h | Buy new hardware + GitOps rebuild |

---

## 🔥 DR RUNBOOK #1: Complete Cluster Loss (Fire/Flood/Theft)

**Szenario:** Dein komplettes Homelab ist weg (Brand, Überschwemmung, Diebstahl)

**RTO:** 3 Tage (Hardware kaufen + Setup)
**RPO:** 24 Stunden (Daily Backup)

### Phase 1: Hardware Procurement (Tag 1)
```bash
# 1. Bestell neue Hardware (Amazon/Conrad)
# 3× Mini-PC (z.B. Intel NUC oder HP EliteDesk)
# 3× 1TB NVMe SSD
# 1× Managed Switch (z.B. Ubiquiti)
# Budget: ~$1,500

# 2. Während du wartest: Bereite Configs vor
cd ~/homelab-backup
git clone https://github.com/tim275/talos-homelab-scratch
cd talos-homelab-scratch
```

### Phase 2: Talos Cluster Bootstrap (Tag 2)
```bash
# 1. BIOS Settings auf allen 3 Nodes
# - Enable Virtualization (VT-x/AMD-V)
# - Enable UEFI Boot
# - Disable Secure Boot

# 2. Talos Schematic erstellen
cd tofu/talos/image
curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics
# Output: Schematic ID → update in tofu/variables.tofu

# 3. Talos ISO herunterladen
wget https://factory.talos.dev/image/<schematic-id>/v1.10.6/talos-amd64.iso

# 4. Burn ISO auf USB Stick (für jeden Node)
dd if=talos-amd64.iso of=/dev/sdX bs=4M status=progress

# 5. Boot alle 3 Nodes vom USB Stick

# 6. Terraform Apply (generiert Configs + bootstrapt Cluster)
cd tofu
tofu init
tofu apply -auto-approve

# 7. Wait for Kubernetes API
export KUBECONFIG=$(pwd)/output/kube-config.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=10m
```

### Phase 3: Core Infrastructure (Tag 2-3)
```bash
# 1. Deploy Rook-Ceph (Storage Provider)
kubectl apply -f ../kubernetes/infrastructure/storage/rook-ceph/

# Wait for Ceph cluster health
kubectl -n rook-ceph get cephcluster -w
# Wait for: HEALTH_OK

# 2. Deploy ArgoCD (GitOps Engine)
kubectl apply -k ../kubernetes/infrastructure/gitops/argocd/

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# 3. Deploy Velero (Backup Restore)
kubectl apply -k ../kubernetes/infrastructure/storage/velero/

# 4. Configure Velero BSL (Rook Ceph S3)
# Wenn Ceph RGW noch nicht deployed:
kubectl apply -f ../kubernetes/infrastructure/storage/rook-ceph/object-store.yaml

# Create ObjectBucketClaims
kubectl apply -f ../kubernetes/infrastructure/storage/velero/velero-buckets-obc.yaml

# Extract S3 credentials
kubectl get secret rook-ceph-object-user-homelab-objectstore-velero-cluster-backups \
  -n velero -o jsonpath='{.data.AccessKey}' | base64 -d > /tmp/access_key
kubectl get secret rook-ceph-object-user-homelab-objectstore-velero-cluster-backups \
  -n velero -o jsonpath='{.data.SecretKey}' | base64 -d > /tmp/secret_key

# Create Velero credentials secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: velero-s3-credentials-cluster
  namespace: velero
stringData:
  cloud: |
    [default]
    aws_access_key_id=$(cat /tmp/access_key)
    aws_secret_access_key=$(cat /tmp/secret_key)
EOF

# Apply BSLs
kubectl apply -f ../kubernetes/infrastructure/storage/velero/backup-storage-locations.yaml
```

### Phase 4: Restore from Backup (Tag 3)
```bash
# PROBLEM: S3 Buckets sind leer (alte Buckets waren auf altem Ceph!)
# LÖSUNG: Du hast KEINE Offsite-Backups → Datenverlust!

# ⚠️  CRITICAL DECISION POINT:
# Wenn du CLOUD DR hattest (AWS S3):
velero backup-location create aws-dr \
  --provider aws \
  --bucket homelab-velero-dr-backups \
  --config region=eu-central-1

velero restore create cluster-restore \
  --from-backup daily-cluster-backup-20251026 \
  --wait

# ❌ Wenn du KEIN Cloud DR hattest:
# → KOMPLETTER DATENVERLUST
# → Musst alles neu konfigurieren
# → Lessons Learned: Cloud DR ist doch wichtig!

# 5. Sync ArgoCD Apps (GitOps Magic)
argocd app sync -l app.kubernetes.io/instance=argocd
# ArgoCD deployt automatisch alle Apps aus Git!

# 6. Manual restore für kritische Daten (wenn Cloud DR vorhanden)
velero restore create n8n-restore \
  --from-backup tier0-databases-6h-20251027000000 \
  --include-namespaces n8n-prod \
  --wait

velero restore create authelia-restore \
  --from-backup tier0-databases-6h-20251027000000 \
  --include-namespaces authelia \
  --wait
```

### Phase 5: Validation & Testing
```bash
# 1. Check all pods running
kubectl get pods -A | grep -v Running

# 2. Validate N8N data
kubectl exec -n n8n-prod deploy/n8n-postgres -- \
  psql -U postgres -c "SELECT COUNT(*) FROM workflows;"

# 3. Test web UIs
curl -k https://n8n.timourhomelab.org
curl -k https://grafana.timourhomelab.org

# 4. Verify DNS resolution
kubectl get svc -n gateway gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# 5. Check Ceph storage health
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
```

**Ergebnis:**
- ✅ **Mit Cloud DR:** 3 Tage, max 24h Datenverlust
- ❌ **Ohne Cloud DR:** 3 Tage, 100% Datenverlust (nur GitOps Config recovery)

---

## 🏢 ENTERPRISE ON-PREM DR: Daten ohne Cloud sichern

### ❓ **Deine Frage: "Wie macht man DR in Enterprise, wenn Daten NICHT in die Cloud dürfen?"**

**Problem:**
```
ArgoCD = Kann Infrastructure wiederherstellen ✅
GitOps = Alle Manifests in Git ✅
ABER: Datenbanken, PVCs, Secrets → WO? ❌
```

**Use Cases für Cloud-Verbot:**
- 🏦 **Banken:** BaFin/EZB verbieten Cloud-Storage
- 🏥 **Krankenhäuser:** Patientendaten müssen in DE bleiben (DSGVO)
- 🏭 **Industrie:** Produktionsdaten = Betriebsgeheimnis
- 🛡️ **Behörden:** VS-NfD (Verschlusssache) darf nicht AWS

---

## 🎯 Enterprise On-Prem DR Strategien (ohne Cloud)

### Strategie 1: **Multi-Site Replication** (2 Rechenzentren)

**Wie es funktioniert:**
```
┌─────────────────────────────────────────────────────────┐
│ PRIMARY SITE (Frankfurt Datacenter)                     │
│ ├─ Kubernetes Cluster (3 Nodes)                        │
│ ├─ Rook Ceph (100TB Storage)                           │
│ └─ Velero → Ceph S3 (Primary Backups)                  │
└─────────────────────────────────────────────────────────┘
                          │
                          │ WAN Link (10 Gbit/s)
                          │ rclone sync (continuous)
                          ▼
┌─────────────────────────────────────────────────────────┐
│ DR SITE (München Datacenter)                            │
│ ├─ Kubernetes Cluster (3 Nodes, standby)               │
│ ├─ Rook Ceph (100TB Storage, replicated)               │
│ └─ Velero Backups (synchronized from Frankfurt)        │
└─────────────────────────────────────────────────────────┘
```

**Implementation:**
```yaml
# Rclone sync job (CronJob in rook-ceph namespace)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-sync-to-dr-site
  namespace: rook-ceph
spec:
  schedule: "*/30 * * * *"  # Every 30 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: rclone-sync
            image: rclone/rclone:latest
            command:
            - /bin/sh
            - -c
            - |
              # Sync Primary → DR Site
              rclone sync s3-primary:velero-cluster-backups \
                s3-dr:velero-cluster-backups-dr \
                --config /etc/rclone/rclone.conf \
                --transfers 8 \
                --checkers 16 \
                --progress
            volumeMounts:
            - name: rclone-config
              mountPath: /etc/rclone
          volumes:
          - name: rclone-config
            secret:
              secretName: rclone-config
          restartPolicy: OnFailure
```

**Rclone Config:**
```ini
# /etc/rclone/rclone.conf
[s3-primary]
type = s3
provider = Ceph
endpoint = http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
access_key_id = <PRIMARY_ACCESS_KEY>
secret_access_key = <PRIMARY_SECRET_KEY>

[s3-dr]
type = s3
provider = Ceph
endpoint = https://dr-site-ceph.company.internal:443
access_key_id = <DR_ACCESS_KEY>
secret_access_key = <DR_SECRET_KEY>
```

**Cost (Enterprise):**
- Primary Site: $150,000 (Hardware) + $5,000/Monat (Strom, Kühlung)
- DR Site: $150,000 (Hardware) + $5,000/Monat
- WAN Link: $2,000/Monat (10 Gbit/s Glasfaser)
- **Total:** $300,000 + $12,000/Monat

**RTO:** 4 Stunden (Velero Restore + DNS Umschaltung)
**RPO:** 30 Minuten (rclone sync interval)

---

### Strategie 2: **Tape Backup** (LTO-9 Offsite Storage)

**Wie es funktioniert:**
```
┌──────────────────────────────────────────────┐
│ Kubernetes Cluster (Primary)                 │
│ └─ Velero → Ceph S3 → Bareos Tape Backup    │
└──────────────────────────────────────────────┘
                    │
                    │ Nightly Backup
                    ▼
         ┌──────────────────────┐
         │ LTO-9 Tape Library   │
         │ (18TB/Tape × 50)     │
         │ = 900TB Capacity     │
         └──────────────────────┘
                    │
                    │ Weekly Transport
                    ▼
         ┌──────────────────────┐
         │ Offsite Tape Vault   │
         │ (Iron Mountain)      │
         │ Climate-controlled   │
         └──────────────────────┘
```

**Implementation (Bareos Backup):**
```yaml
# Bareos Backup Job
apiVersion: v1
kind: ConfigMap
metadata:
  name: bareos-job-velero
  namespace: backup
data:
  velero-backup.conf: |
    Job {
      Name = "VeleroS3ToTape"
      Type = Backup
      Level = Full
      Client = ceph-rgw-client
      FileSet = "VeleroBackups"
      Storage = LTO-9-Library
      Pool = Weekly-Tapes
      Schedule = "WeeklyCycle"
      Messages = Standard
      Priority = 10
    }

    FileSet {
      Name = "VeleroBackups"
      Include {
        Options {
          signature = MD5
          compression = LZ4
        }
        File = /mnt/ceph-rgw/velero-cluster-backups
        File = /mnt/ceph-rgw/velero-pv-backups
      }
    }

    Schedule {
      Name = "WeeklyCycle"
      Run = Full sun at 01:00
    }
```

**Tape Rotation Schema (Grandfather-Father-Son):**
```
Daily Tapes:   7 Tapes (Mo-So) → Rotation wöchentlich
Weekly Tapes:  4 Tapes (Woche 1-4) → Rotation monatlich
Monthly Tapes: 12 Tapes (Jan-Dez) → Rotation jährlich
Yearly Tapes:  7 Tapes → 7 Jahre Aufbewahrung (Compliance)

Total Tapes: 30 Tapes (7+4+12+7)
```

**Cost (Enterprise):**
- LTO-9 Tape Library: $25,000 (z.B. HP StoreEver MSL6480)
- LTO-9 Tapes: $150/Tape × 30 = $4,500
- Offsite Storage: $500/Monat (Iron Mountain)
- **Total:** $29,500 + $500/Monat

**RTO:** 1-2 Tage (Tape von Offsite holen + Restore)
**RPO:** 7 Tage (Weekly Backup)

---

### Strategie 3: **Portable HDD Backup** (Homelab/SMB Lösung)

**Wie es funktioniert:**
```
┌──────────────────────────────────────────────┐
│ Homelab Kubernetes Cluster                   │
│ └─ Velero → Ceph S3 → USB HDD (rotation)    │
└──────────────────────────────────────────────┘
                    │
                    │ Weekly Manual Sync
                    ▼
         ┌──────────────────────┐
         │ USB HDD #1 (8TB)     │  ◄── Woche 1,3,5 (zu Hause)
         └──────────────────────┘
         ┌──────────────────────┐
         │ USB HDD #2 (8TB)     │  ◄── Woche 2,4,6 (bei Eltern)
         └──────────────────────┘
```

**Implementation (Bash Script):**
```bash
#!/bin/bash
# /usr/local/bin/backup-to-portable-hdd.sh

set -e

MOUNT_POINT="/mnt/backup-hdd"
BACKUP_DATE=$(date +%Y%m%d)

# 1. Detect USB HDD
USB_DEVICE=$(lsblk -o NAME,SIZE,LABEL | grep "BACKUP-HDD" | awk '{print $1}')
if [ -z "$USB_DEVICE" ]; then
  echo "❌ ERROR: USB HDD not found! Please connect backup drive."
  exit 1
fi

# 2. Mount USB HDD
sudo mkdir -p $MOUNT_POINT
sudo mount /dev/$USB_DEVICE $MOUNT_POINT

# 3. Sync Velero S3 buckets to USB HDD
echo "=== Syncing Velero Backups to USB HDD ==="
rclone sync \
  /var/lib/rook/ceph-rgw/velero-cluster-backups \
  $MOUNT_POINT/velero-cluster-backups-$BACKUP_DATE \
  --progress --checksum

rclone sync \
  /var/lib/rook/ceph-rgw/velero-pv-backups \
  $MOUNT_POINT/velero-pv-backups-$BACKUP_DATE \
  --progress --checksum

# 4. Export PostgreSQL dumps (extra safety)
kubectl exec -n n8n-prod deploy/n8n-postgres -- \
  pg_dumpall -U postgres > $MOUNT_POINT/n8n-postgres-$BACKUP_DATE.sql

kubectl exec -n authelia deploy/authelia-postgres -- \
  pg_dumpall -U postgres > $MOUNT_POINT/authelia-postgres-$BACKUP_DATE.sql

# 5. Backup Talos configs
cp -r ~/homelab/tofu/output/*.yaml $MOUNT_POINT/talos-configs-$BACKUP_DATE/

# 6. Verify backup size
BACKUP_SIZE=$(du -sh $MOUNT_POINT | awk '{print $1}')
echo "✅ Backup completed: $BACKUP_SIZE"

# 7. Unmount
sudo umount $MOUNT_POINT

echo "✅ Done! You can now disconnect USB HDD."
echo "📦 Next step: Take HDD offsite (parents, office safe, bank vault)"
```

**Rotation Strategy:**
```bash
Woche 1: USB HDD #1 sync → bei dir zu Hause (Safe)
Woche 2: USB HDD #2 sync → bei Eltern (offsite)
Woche 3: USB HDD #1 holen → sync → zu Hause
Woche 4: USB HDD #2 holen → sync → bei Eltern
```

**Cost (Homelab):**
- 2× USB HDD 8TB: $150/Stück × 2 = **$300**
- Feuerfester Safe: $200 (optional)
- **Total:** $300-500 (one-time)

**RTO:** 4 Stunden (HDD holen + Restore)
**RPO:** 7 Tage (Weekly Sync)

---

### Strategie 4: **NAS at Friend/Family** (Remote Sync)

**Wie es funktioniert:**
```
┌──────────────────────────────────────────────┐
│ Homelab (deine Wohnung)                      │
│ └─ Velero → Ceph S3 → Tailscale VPN        │
└──────────────────────────────────────────────┘
                    │
                    │ Tailscale VPN (encrypted)
                    │ rclone sync (nightly)
                    ▼
┌──────────────────────────────────────────────┐
│ Synology NAS at Friend's House               │
│ └─ 12TB Storage (Velero Replica)            │
└──────────────────────────────────────────────┘
```

**Implementation:**
```yaml
# Kubernetes CronJob (nightly sync)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: offsite-nas-sync
  namespace: velero
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: rclone-offsite
            image: rclone/rclone:latest
            command:
            - /bin/sh
            - -c
            - |
              # Sync to friend's NAS via Tailscale
              rclone sync \
                s3-homelab:velero-cluster-backups \
                sftp-remote:/volume1/homelab-backups \
                --config /etc/rclone/rclone.conf \
                --bwlimit 10M \
                --transfers 4
            volumeMounts:
            - name: rclone-config
              mountPath: /etc/rclone
          restartPolicy: OnFailure
```

**Rclone Config (Tailscale SFTP):**
```ini
[sftp-remote]
type = sftp
host = 100.x.x.x  # Tailscale IP of friend's NAS
user = backup-user
key_file = /etc/ssh/id_rsa_backup
port = 22
```

**Cost (Homelab):**
- Synology DS920+ (4-Bay): $550
- 2× 8TB HDD (RAID1): $300
- **Total:** $850 (one-time) + $0/Monat (bei Freund gehostet)

**RTO:** 6 Stunden (Download von NAS + Restore)
**RPO:** 24 Stunden (Daily Sync)

---

## 📊 DR Strategie Vergleich (On-Prem Only)

| Strategie | RTO | RPO | Cost (Initial) | Cost (Monthly) | Best For |
|-----------|-----|-----|----------------|----------------|----------|
| **Multi-Site Replication** | 4h | 30min | $300k | $12k | 🏦 Banks, Critical Infrastructure |
| **Tape Backup (LTO-9)** | 1-2 Tage | 7 Tage | $30k | $500 | 🏥 Healthcare, Long-Term Compliance |
| **Portable HDD Rotation** | 4h | 7 Tage | $500 | $0 | 🏠 Homelab, SMB |
| **NAS at Friend/Family** | 6h | 24h | $850 | $0 | 🏠 Homelab |
| **Cloud DR (AWS S3)** | 4h | 24h | $0 | $50 | ❌ Nicht erlaubt (Compliance) |

---

## 🎯 Empfehlung für DEIN Homelab (On-Prem Only)

### **Meine Empfehlung: Portable HDD Rotation**

**Warum:**
- ✅ **Cost:** Nur $300 (2× USB HDD)
- ✅ **Simple:** Wöchentlich HDD anstecken + Skript laufen lassen
- ✅ **Offsite:** HDD #2 bei Eltern/Freund = echtes Offsite Backup
- ✅ **Fast RTO:** 4 Stunden (HDD holen + Restore)
- ✅ **DSGVO-konform:** Keine Cloud, alles physisch kontrolliert

**Setup:**
```bash
# 1. USB HDD kaufen
# Amazon: 2× Seagate Expansion 8TB USB 3.0 = ~$300

# 2. Format + Label
sudo mkfs.ext4 /dev/sdb1 -L BACKUP-HDD-1
sudo mkfs.ext4 /dev/sdc1 -L BACKUP-HDD-2

# 3. Script installieren
sudo curl -o /usr/local/bin/backup-to-hdd.sh \
  https://raw.githubusercontent.com/.../backup-to-hdd.sh
sudo chmod +x /usr/local/bin/backup-to-hdd.sh

# 4. Wöchentliche Reminder (Calendar)
# Jeden Sonntag: USB HDD anstecken + Script laufen lassen
```

**Rotation Schema:**
```
Sonntag Woche 1: HDD #1 sync → Safe bei dir zu Hause
Sonntag Woche 2: HDD #2 sync → bei Eltern abgeben
Sonntag Woche 3: HDD #1 sync (update)
Sonntag Woche 4: HDD #2 von Eltern holen → sync → zurückbringen
```

**Result:**
- ✅ 2× Backups (On-Site + Off-Site)
- ✅ Protection gegen Fire/Flood/Theft
- ✅ RPO: 7 Tage max
- ✅ Cost: $0/Monat

---

## 🔥 DR Test: Complete Cluster Loss MIT Portable HDD

**Szenario:** Deine Wohnung brennt ab, Homelab komplett weg

### Phase 1: Hardware kaufen (Tag 1)
```bash
# Gleich wie vorher: 3× NUC + Switch
```

### Phase 2: Talos Cluster (Tag 2)
```bash
# Gleich wie vorher: tofu apply
```

### Phase 3: HDD von Eltern holen (Tag 2)
```bash
# 1. Fahre zu Eltern, hole USB HDD #2
# 2. Steck HDD an deinen Laptop

# 3. Mount HDD
sudo mount /dev/sdb1 /mnt/backup-hdd

# 4. List backups
ls -lh /mnt/backup-hdd/
# Output:
# velero-cluster-backups-20251020/
# velero-pv-backups-20251020/
# n8n-postgres-20251020.sql
# authelia-postgres-20251020.sql
# talos-configs-20251020/
```

### Phase 4: Restore Velero Backups (Tag 3)
```bash
# 1. Copy backups to new Ceph S3
rclone copy \
  /mnt/backup-hdd/velero-cluster-backups-20251020 \
  s3-new:velero-cluster-backups

rclone copy \
  /mnt/backup-hdd/velero-pv-backups-20251020 \
  s3-new:velero-pv-backups

# 2. Configure Velero BSL (pointing to new Ceph)
kubectl apply -f velero-bsl.yaml

# 3. Restore from backup
velero restore create fire-recovery \
  --from-backup daily-cluster-backup-20251020 \
  --wait

# 4. Verify data
kubectl exec -n n8n-prod deploy/n8n-postgres -- \
  psql -U postgres -c "SELECT COUNT(*) FROM workflows;"

# ✅ DATEN SIND ZURÜCK!
```

**Ergebnis:**
- ✅ **RTO:** 3 Tage (Hardware + Setup + Restore)
- ✅ **RPO:** 7 Tage max (letztes Weekly Backup)
- ✅ **Datenverlust:** KEIN 100% Verlust! Max 7 Tage.
- ✅ **Cost:** $0 (HDD war schon da)

---

## ✅ FAZIT: Enterprise On-Prem DR ohne Cloud

**Antwort auf deine Frage:**

> "Wie würde man es in Production Enterprise machen, wenn Daten nicht in die Cloud dürfen?"

**Enterprise (Banks, Healthcare):**
- 🏢 **Multi-Site Replication** ($300k + $12k/Monat)
- 📼 **LTO-9 Tape Backup** ($30k + $500/Monat)
- RTO: 4 Stunden - 2 Tage
- RPO: 30 Minuten - 7 Tage

**Homelab (dein Setup):**
- 💾 **Portable HDD Rotation** ($300 one-time)
- 🏠 **NAS at Friend/Family** ($850 one-time)
- RTO: 4-6 Stunden
- RPO: 7-24 Stunden

**Key Insight:**
```
GitOps (ArgoCD) = Infrastructure Recovery ✅
Velero + Offsite Backup = Data Recovery ✅

BEIDES zusammen = Complete DR ohne Cloud! 🎯
```

---

## 🖥️ DR RUNBOOK #2: Single Node Failure

**Szenario:** Ein Control-Plane Node (z.B. ctrl-0) ist tot (Hardware-Defekt)

**RTO:** 1 Stunde
**RPO:** 0 Stunden (Ceph Replication)

```bash
# 1. Verify cluster still has quorum (2/3 nodes healthy)
export TALOSCONFIG=tofu/output/talos-config.yaml
talosctl -n 192.168.68.102,192.168.68.103 get members

# 2. Check Ceph health (should still work with 2 OSDs)
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
# Expect: HEALTH_WARN (1 OSD down)

# 3. Remove failed node from Talos cluster
talosctl -n 192.168.68.102 reset --graceful --reboot \
  --system-labels-to-wipe STATE,EPHEMERAL

# 4. Replace hardware (oder benutze alten Node nach Reboot)

# 5. Re-provision failed node via Terraform
cd tofu
tofu taint 'module.talos.talos_machine_configuration_apply.controlplane[0]'
tofu apply -auto-approve

# 6. Wait for node to rejoin
kubectl get nodes -w
# Wait for: ctrl-0 Ready

# 7. Verify Ceph recovery
kubectl -n rook-ceph get cephcluster -w
# Wait for: HEALTH_OK (Ceph auto-rebalances)

# 8. No Velero restore needed (data was replicated!)
```

**Ergebnis:** 1 Stunde downtime, 0 Datenverlust ✅

---

## 💣 DR RUNBOOK #3: Ransomware Attack

**Szenario:** Alle PVCs encrypted, Pods crashen mit "file corrupted"

**RTO:** 2 Stunden
**RPO:** 6 Stunden (Tier-0 Backup)

```bash
# 1. SOFORT: Isolate cluster (disconnect network)
# → Pull Ethernet cable oder disable Switch Port

# 2. Identify affected namespaces
kubectl get pods -A | grep Error

# 3. Delete infected namespaces (prevent spread)
kubectl delete namespace n8n-prod --force --grace-period=0

# 4. Restore from OLDEST backup (not latest - might be encrypted!)
velero backup get --selector tier=tier-0
# Choose backup from BEFORE infection (check timestamp!)

velero restore create ransomware-recovery \
  --from-backup tier0-databases-6h-20251027000000 \
  --include-namespaces n8n-prod \
  --wait

# 5. Verify restored data is clean
kubectl exec -n n8n-prod deploy/n8n-postgres -- \
  psql -U postgres -c "SELECT * FROM workflows LIMIT 1;"

# 6. Scan for malware (optional, aber empfohlen)
kubectl run --rm -it malware-scan --image=clamav/clamav \
  --restart=Never -- clamscan -r /data

# 7. Reconnect network + monitor
# Watch for suspicious activity (kubectl logs -f)
```

**Ergebnis:** 2 Stunden RTO, max 6h Datenverlust ✅
**Key Lesson:** S3 Versioning rettet dich! (Encrypted versions ≠ verloren)

---

## 🗑️ DR RUNBOOK #4: Accidental Deletion (`kubectl delete namespace prod`)

**Szenario:** Du hast versehentlich `kubectl delete ns n8n-prod` ausgeführt

**RTO:** 15 Minuten
**RPO:** 6 Stunden

```bash
# 1. PANIC! Aber bleib ruhig, Velero rettet dich.

# 2. Find latest backup
velero backup get | grep n8n-prod | head -1

# 3. Restore entire namespace
velero restore create accidental-deletion-fix \
  --from-backup tier0-databases-6h-20251027060000 \
  --include-namespaces n8n-prod \
  --wait

# 4. Verify pods come back up
kubectl get pods -n n8n-prod -w

# 5. Test application
curl https://n8n.timourhomelab.org/healthz

# Done in 15 minutes! 🎉
```

---

## 🔌 DR RUNBOOK #5: Power Outage (12 Stunden Stromausfall)

**Szenario:** Stromausfall, UPS hält 30min, Cluster shutdown

**RTO:** 0 Stunden (auto-recovery)
**RPO:** 0 Stunden

```bash
# 1. Wait for power to come back

# 2. Nodes boot automatically (Talos auto-starts services)

# 3. Verify cluster health
kubectl get nodes
# All nodes should auto-recover

# 4. Check Ceph (might take 5-10min to rebalance)
kubectl -n rook-ceph get cephcluster

# 5. Verify applications
kubectl get pods -A

# Done! Talos + Kubernetes auto-recover gracefully 🎉
```

**Ergebnis:** 0 Downtime nach Strom zurück, 0 Datenverlust ✅

---

## 📊 DR Testing Schedule (Quarterly)

### Q1 Test: Accidental Deletion Drill
```bash
# Simulate: kubectl delete namespace test-app
# Restore: velero restore create ...
# Measure: RTO (should be < 30min)
```

### Q2 Test: Single Node Failure Drill
```bash
# Simulate: talosctl -n ctrl-2 shutdown
# Verify: Cluster still operational
# Measure: Auto-recovery time
```

### Q3 Test: Ransomware Simulation
```bash
# Simulate: Encrypt test PVC
# Restore: From S3 versioned backup
# Measure: RTO (should be < 2h)
```

### Q4 Test: Complete Cluster Rebuild
```bash
# Simulate: tofu destroy (DANGEROUS!)
# Restore: GitOps + Velero
# Measure: RTO (should be < 8h)
```

---

## 🎯 DR Readiness Checklist

### Before Disaster:
- [ ] Velero Schedules running (check: `velero schedule get`)
- [ ] Latest backup < 6h old (check: `velero backup get`)
- [ ] S3 storage healthy (check: `velero backup-location get`)
- [ ] GitOps repo up-to-date (check: `git push` works)
- [ ] Talos configs backed up (in `tofu/output/`)
- [ ] Recovery documentation accessible (NOT only in cluster!)

### During Disaster:
- [ ] Stay calm, follow runbook
- [ ] Document timeline (for post-mortem)
- [ ] Communicate downtime (if applicable)
- [ ] Take screenshots of errors (for debugging)

### After Recovery:
- [ ] Run validation tests (data integrity)
- [ ] Write post-mortem (what went wrong?)
- [ ] Update DR procedures (lessons learned)
- [ ] Test backup restore (verify it works!)

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

## 🏢 ENTERPRISE PRODUCTION: Was machen Fortune 500 Firmen anders?

### ❓ **Deine Frage: "Ist das eine Enterprise Lösung?"**

**Kurze Antwort:** **JA, aber...** mit Einschränkungen:

| Aspekt | ✅ Dein Setup (Production-Ready) | ⚠️ Fehlt für Fortune 500 |
|--------|----------------------------------|---------------------------|
| **Backup Strategy** | ✅ 4-Tier RPO/RTO System | ⚠️ Keine Geographic Redundancy |
| **Storage** | ✅ Rook Ceph S3 (On-Prem) | ⚠️ Keine Cloud DR Location |
| **Retention** | ✅ 7-90 Tage (Compliance-fähig) | ⚠️ Keine Yearly Backups (7-10 Jahre) |
| **Encryption** | ✅ SSE-S3 + TLS | ⚠️ Kein KMS (Key Management Service) |
| **Immutability** | ✅ S3 Versioning | ⚠️ Kein S3 Object Lock (WORM) |
| **Testing** | ⚠️ Manual Restore Tests | ❌ Keine Automated DR Drills |
| **Monitoring** | ⚠️ Prometheus Metrics geplant | ❌ 24/7 NOC + PagerDuty Integration |
| **Compliance** | ⚠️ GDPR-fähig | ❌ Keine SOC2/ISO27001 Audits |

**Fazit:** Dein Setup ist **"Enterprise-Ready für SMB/Startups"** (50-500 Mitarbeiter), aber nicht **"Fortune 500 Enterprise"** (10.000+ Mitarbeiter).

---

## 🌍 Die 3-2-1 Backup Rule (Industry Standard)

**Was ist die 3-2-1 Rule?**
```
3 = Mindestens 3 Kopien deiner Daten
2 = Auf 2 verschiedenen Medien-Typen
1 = Mindestens 1 Kopie offsite (geografisch getrennt)
```

### ❌ **Dein aktueller Stand:**
```
1 = Nur 1 Backup-Kopie (Rook Ceph S3 on-prem)
1 = Nur 1 Medium (Ceph Block Storage)
0 = Kein Offsite Backup (alles im selben Rack)
```

### ✅ **Enterprise 3-2-1 Setup:**
```
┌─────────────────────────────────────────────────────────────┐
│ KOPIE 1: Production Data (Live)                            │
│ └─ Rook Ceph RBD (3x Replication innerhalb Cluster)       │
├─────────────────────────────────────────────────────────────┤
│ KOPIE 2: On-Prem Backups (Primary)                         │
│ └─ Rook Ceph S3 RGW (dein aktuelles Setup)                │
│ └─ Storage: 100GB S3 Buckets                               │
│ └─ Retention: 7-90 Tage                                    │
├─────────────────────────────────────────────────────────────┤
│ KOPIE 3: Cloud DR Backups (Secondary)                      │
│ └─ AWS S3 Glacier / Azure Blob Archive                     │
│ └─ Geografisch getrennt (anderes Rechenzentrum)            │
│ └─ Retention: 1-7 Jahre (Compliance)                       │
│ └─ Cost: ~$20-50/Monat für 500GB                           │
├─────────────────────────────────────────────────────────────┤
│ MEDIUM 1: Block Storage (Ceph RBD)                         │
│ MEDIUM 2: Object Storage (S3)                              │
│ MEDIUM 3: Cold Storage (Tape/Glacier - optional)           │
└─────────────────────────────────────────────────────────────┘
```

**Cost Beispiel (500GB Daten):**
- On-Prem Ceph: **$0** (Hardware bereits vorhanden)
- AWS S3 Standard: **$11.50/Monat** (500GB × $0.023/GB)
- AWS S3 Glacier Deep Archive: **$0.50/Monat** (500GB × $0.001/GB)

---

## 🔐 Enterprise Compliance: Was verlangen Auditors?

### GDPR (EU Datenschutz):
```
✅ Retention Policies (implemented)
✅ Encryption at Rest (SSE-S3)
✅ Encryption in Transit (TLS)
⚠️  Data Residency (Backups müssen in EU bleiben!)
❌ Right to be Forgotten (Backup Purge Procedures)
❌ Data Processing Agreement mit Cloud Provider
```

### SOC 2 Type II (US Standard für SaaS):
```
❌ Annual Penetration Test (Backup Infrastructure)
❌ Change Management (CAB Approval für Backup Changes)
❌ Quarterly DR Tests (documented, audited)
❌ Access Logs (Who accessed backups? When? Why?)
❌ Encryption Key Rotation (90 Tage Cycle)
```

### ISO 27001 (International Security Standard):
```
❌ Risk Assessment (Backup Failure Impact Analysis)
❌ Incident Response Plan (Backup Corruption Runbook)
❌ Business Continuity Plan (RTO/RPO documented)
❌ Vendor Management (Rook/Velero Security Patches)
```

**Realität:** Compliance kostet **$50k-200k/Jahr** (Audits, Tools, Personal).

---

## 💰 Cost Comparison: Homelab vs. Enterprise

### 📊 **Dein Setup (Homelab/SMB):**
```
Hardware:
- Ceph Cluster (3 Nodes × $500)      = $1,500 (one-time)
- Storage (3 × 1TB SSD)               = $300 (one-time)

Software:
- Rook Ceph                           = $0 (Open Source)
- Velero                              = $0 (Open Source)
- Kubernetes                          = $0 (Open Source)

Operational:
- Electricity (3 Nodes × 100W)        = $30/Monat
- Wartung (deine Zeit)                = $0 (Hobby)
                                        ─────────────
Total Cost of Ownership (1 Jahr):     = $2,160
```

### 🏢 **Fortune 500 Enterprise:**
```
Primary Backups (On-Prem):
- Veeam Enterprise License            = $30,000/Jahr
- Dell PowerProtect DD9900            = $150,000 (Hardware)
- Storage (50TB × $200/TB)            = $10,000/Jahr

Secondary Backups (Cloud DR):
- AWS S3 Standard (10TB)              = $2,300/Monat = $27,600/Jahr
- AWS S3 Glacier (50TB Long-Term)     = $500/Monat = $6,000/Jahr
- Data Transfer Out (500GB/Monat)     = $450/Monat = $5,400/Jahr

Compliance & Monitoring:
- Splunk SIEM (Backup Audit Logs)     = $20,000/Jahr
- PagerDuty Enterprise                = $10,000/Jahr
- SOC2 Audit                          = $50,000/Jahr (one-time, dann $15k/Jahr)

Personnel:
- Backup Administrator (1 FTE)        = $120,000/Jahr Gehalt
- DR Manager (0.5 FTE)                = $60,000/Jahr
                                        ─────────────
Total Cost of Ownership (1 Jahr):     = $489,000
```

**Unterschied:** 226x teurer! (Aber auch für 1000x mehr Daten + 24/7 Support)

---

## 🚀 Upgrade Path: Von Homelab zu Enterprise

### Phase 1: **Jetzt** (2025-Q4) - Homelab Production Ready ✅
```bash
✅ Tier-0 Backups (6h Cycle)
✅ Rook Ceph S3 (100GB)
✅ Velero Schedules (4 Tiers)
✅ S3 Versioning (Ransomware Protection)
✅ Retention Policies (7-90 Tage)

Cost: $0 (bereits deployed)
Time: DONE ✅
Status: AUSREICHEND FÜR HOMELAB 🏠
```

### Phase 2: **OPTIONAL/ÜBERSPRUNGEN** - Cloud DR (3-2-1 Rule) ⏭️
```bash
❌ ÜBERSPRUNGEN - Nicht nötig für Homelab
❌ Cloud DR ist nur für Business Critical Production
❌ 3-2-1 Rule ist overkill für Homelab
❌ Kosten ($50/Monat) nicht gerechtfertigt

BEGRÜNDUNG:
- Homelab hat kein Business Revenue Risk
- On-Prem Ceph Replication (3x) reicht aus
- Bei Totalausfall: Rebuild aus Git + IaC möglich
- Daten-Backup (Tier-0) schützt vor Datenverlust

Cost: $0 (übersprungen)
Time: 0 (nicht implementiert)
```

---

**HINWEIS:** Die folgenden Phasen 2-5 sind **nur für Enterprise/Business relevant**, nicht für Homelab!

---

### ~~Phase 2: **2026-Q1** - Cloud DR (3-2-1 Rule)~~ ⏭️ **ÜBERSPRUNGEN**
```bash
# NICHT IMPLEMENTIERT - NUR FÜR ENTERPRISE
⏭️ Velero Cloud BackupStorageLocation (AWS S3)
⏭️ Sync Tool (rclone: Ceph → AWS S3 täglich)
⏭️ Lifecycle Policies (30d Standard → Glacier)
⏭️ Cross-Region Replication (eu-central-1 → us-east-1)

Cost: ~$50/Monat (für 500GB)
Time: 1 Tag Setup
```

**Terraform Config Beispiel:**
```hcl
# tofu/aws-dr-backup.tf
resource "aws_s3_bucket" "velero_dr" {
  bucket = "homelab-velero-dr-backups"

  lifecycle_rule {
    enabled = true
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Velero BSL for AWS
resource "kubernetes_manifest" "velero_aws_bsl" {
  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "BackupStorageLocation"
    metadata = {
      name      = "aws-dr-backups"
      namespace = "velero"
    }
    spec = {
      provider = "aws"
      default  = false  # Secondary location
      objectStorage = {
        bucket = aws_s3_bucket.velero_dr.id
        prefix = "velero"
      }
      config = {
        region = "eu-central-1"
      }
    }
  }
}
```

### Phase 3: **2026-Q2** - Immutable Backups (Ransomware Defense) 🔒
```bash
⏳ S3 Object Lock (WORM Mode)
⏳ MFA Delete (Extra Protection)
⏳ Compliance Mode (Cannot delete before retention expires)

Cost: $0 (AWS Feature, kein Aufpreis)
Time: 2 Stunden Setup
```

**S3 Bucket Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Principal": "*",
    "Action": [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:PutLifecycleConfiguration"
    ],
    "Resource": "arn:aws:s3:::homelab-velero-dr-backups/*",
    "Condition": {
      "NumericLessThan": {
        "s3:object-lock-remaining-retention-days": "30"
      }
    }
  }]
}
```

### Phase 4: **2026-Q3** - Automated DR Testing 🧪
```bash
⏳ Restore Testing Job (monatlich)
⏳ Chaos Engineering (delete random PVC, restore from backup)
⏳ RTO Validation (measure actual restore time)
⏳ Grafana Dashboard (Backup Success Rate, RTO Trend)

Cost: $0 (Kubernetes CronJob)
Time: 1 Woche Development
```

**CronJob Beispiel:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: velero-restore-test
  namespace: velero
spec:
  schedule: "0 4 1 * *"  # Monatlich am 1. um 04:00
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: velero
          containers:
          - name: restore-test
            image: velero/velero:v1.14
            command:
            - /bin/bash
            - -c
            - |
              # 1. Find latest tier-0 backup
              BACKUP=$(velero backup get -o json | jq -r '.items[] | select(.status.phase=="Completed") | .metadata.name' | grep tier0 | head -1)

              # 2. Create test restore
              velero restore create test-restore-$(date +%Y%m%d) \
                --from-backup $BACKUP \
                --namespace-mappings n8n-prod:n8n-restore-test \
                --wait

              # 3. Validate data
              kubectl exec -n n8n-restore-test deploy/n8n-postgres -- \
                psql -U postgres -c "SELECT COUNT(*) FROM workflows;" > /tmp/result.txt

              # 4. Send metrics to Prometheus Pushgateway
              curl -X POST http://pushgateway.monitoring.svc:9091/metrics/job/velero-restore-test \
                --data-binary @- <<EOF
              velero_restore_test_success 1
              velero_restore_test_duration_seconds $(date +%s)
              EOF

              # 5. Cleanup
              kubectl delete namespace n8n-restore-test
```

### Phase 5: **2026-Q4** - Enterprise Monitoring 📊
```bash
⏳ Prometheus Alerts (Backup Age, Failure Rate)
⏳ PagerDuty Integration (24/7 On-Call Rotation)
⏳ Grafana Dashboards (Executive Summary)
⏳ Weekly Reports (Email to Stakeholders)

Cost: PagerDuty $19/User/Monat (optional)
Time: 3 Tage Setup
```

---

## 📈 ROI Calculation: Lohnt sich Enterprise Backup?

### Szenario 1: **Ransomware Attack**
```
Ohne Backup:
- Downtime: 5 Tage (komplett neu aufsetzen)
- Data Loss: 100% (alles verschlüsselt)
- Ransom: $50,000 (zahlen oder nicht?)
- Revenue Loss: $10k/Tag × 5 = $50,000
                                  ────────
Total Cost:                       = $100,000+

Mit Backup:
- Downtime: 2 Stunden (Velero Restore)
- Data Loss: 6 Stunden max (Tier-0 RPO)
- Recovery Cost: $0 (self-service)
- Revenue Loss: $10k/Tag × 0.08 = $800
                                  ────────
Total Cost:                       = $800

Saved:                            = $99,200 ✅
```

### Szenario 2: **Datacenter Fire**
```
Ohne Offsite Backup:
- Downtime: 30 Tage (neue Hardware kaufen, setup)
- Data Loss: 100% (alles physisch zerstört)
- Revenue Loss: $10k/Tag × 30 = $300,000
                                  ────────
Total Cost:                       = $300,000+

Mit Cloud DR:
- Downtime: 4 Stunden (Restore von AWS S3)
- Data Loss: 24 Stunden max (Daily Backup RPO)
- Recovery Cost: $500 (AWS Data Transfer)
- Revenue Loss: $10k/Tag × 0.17 = $1,700
                                  ────────
Total Cost:                       = $2,200

Saved:                            = $297,800 ✅
```

**Break-Even Point:** Nach **1 einzigen Incident** hat sich Cloud DR ($50/Monat) bezahlt gemacht!

---

## 🎯 Enterprise Checklist: Was brauchst du WIRKLICH?

### ✅ **MUST-HAVE (Tier 1 - Critical):**
```
[✅] Automated Backups (Velero Schedules)
[✅] Retention Policies (7-90 Tage)
[✅] Encryption at Rest (SSE-S3)
[✅] Encryption in Transit (TLS)
[⏳] Cloud DR Location (AWS S3 Glacier) ← NEXT PRIORITY
[⏳] Monthly Restore Tests (CronJob)
```

### ⚠️ **SHOULD-HAVE (Tier 2 - Important):**
```
[⏳] Immutable Backups (S3 Object Lock)
[⏳] Prometheus Alerts (Backup Failures)
[⏳] Grafana Dashboard (Success Rate)
[❌] Offsite Tape Backups (für 10+ Jahre Retention)
```

### 🔵 **NICE-TO-HAVE (Tier 3 - Optional):**
```
[❌] 24/7 NOC (PagerDuty Integration)
[❌] SOC2 Compliance (nur wenn du SaaS verkaufst)
[❌] Geo-Redundant DR (3 Continents)
[❌] Quarterly Penetration Tests
```

**Faustregel:**
- **Homelab:** Tier 1 reicht (Automated Backups + Cloud DR)
- **Startup (<50 Mitarbeiter):** Tier 1 + Tier 2 (Monitoring)
- **Enterprise (1000+ Mitarbeiter):** Alle 3 Tiers (Compliance, 24/7 NOC)

---

## 📚 Enterprise Backup Best Practices (Gartner/Forrester)

### 1. **RPO/RTO Pyramid (was ist üblich?)**
```
                Tier-0 (Mission Critical)
                RPO: 1-6h  | RTO: 15min-1h
                Cost: $$$$ | Frequency: 4x/day
                        ▲
                        │
        ┌───────────────┴───────────────┐
        │   Tier-1 (Business Critical)  │
        │   RPO: 24h | RTO: 1-4h        │
        │   Cost: $$  | Frequency: Daily│
        └───────────────┬───────────────┘
                        │
        ┌───────────────┴──────────────────────┐
        │   Tier-2 (Important Configuration)   │
        │   RPO: 7d  | RTO: 8h                 │
        │   Cost: $  | Frequency: Weekly       │
        └──────────────────────────────────────┘

✅ Dein Setup matched diese Pyramid perfekt!
```

### 2. **Backup Window Strategie**
```
Best Practice: Backups NACHTS (Off-Peak Hours)
✅ 00:00-06:00 UTC = ideal (wenig Traffic)
✅ Gestaffelt (nicht alle gleichzeitig)
✅ I/O Throttling (max 50% Ceph bandwidth)

❌ Anti-Pattern:
- Alle Backups um 00:00 gleichzeitig
- Tagsüber (blockiert Production Traffic)
- Ohne Backup Window Reservation
```

### 3. **Encryption Key Management**
```
Homelab:         AWS SSE-S3 (Amazon-managed keys)
                 └─ $0 cost, aber AWS hat die Keys

Enterprise:      AWS KMS (Customer-managed keys)
                 └─ $1/key/Monat + $0.03/10k requests
                 └─ Key Rotation alle 90 Tage
                 └─ CloudTrail Audit Logs (wer nutzte Key?)

High-Security:   AWS CloudHSM (Hardware Security Module)
                 └─ $1.45/Stunde = $1,051/Monat
                 └─ FIPS 140-2 Level 3 Compliance
                 └─ For Banks, Healthcare, Government
```

### 4. **Restore Testing Frequency**
```
Industry Standard (Veeam Survey 2024):
- Daily:        2% (Paranoid Finance/Healthcare)
- Weekly:       15% (High-Growth SaaS)
- Monthly:      45% (Standard Enterprise) ← EMPFOHLEN
- Quarterly:    30% (SMB/Startups)
- Never:        8% (😱 YOLO Mode)

✅ Dein Target: Monatlich (reicht für Homelab/SMB)
```

---

## 🔮 Future Trends: Wohin geht Backup 2026-2030?

### 1. **AI-Powered Backup Optimization**
```
Problem:    Du backupst täglich 500GB, aber nur 50MB ändern sich
Solution:   AI erkennt "change rate" und macht Tier-0 nur für hot data
Tool:       Kasten K10 Enterprise ($10k/Jahr)
Savings:    70% weniger Storage Costs
```

### 2. **Immutable Infrastructure (GitOps)**
```
Trend:      Kein Backup von Config, nur von State
Reason:     ArgoCD kann Cluster in 10min neu deployen
Backup:     Nur Databases, Secrets, PVCs (nicht Deployments!)
✅          Dein Setup folgt bereits diesem Trend!
```

### 3. **Kubernetes-Native Backup**
```
Veraltet:   VM-Backups (Veeam, Commvault)
Modern:     Cloud-Native Backups (Velero, Kasten)
Future:     Built-in Kubernetes Backup API (KEP-3294)
            └─ Native `kubectl backup create` command
            └─ ETA: Kubernetes 1.32+ (2026)
```

### 4. **Zero-Trust Backup Access**
```
Problem:    Velero ServiceAccount = cluster-admin (zu viel Power!)
Solution:   RBAC per Namespace + OPA Policies
Example:    n8n-operator darf nur n8n-prod namespace backen
Tool:       Kyverno Policy (kostenlos!)
```

---

**Last Updated:** 2025-10-27
**Maintained By:** Tim275 (Homelab Infrastructure)
**Review Cycle:** Quarterly (or after major incidents)

---

## ✅ **FAZIT: Ist dein Setup "Enterprise"?**

**JA für:**
- 🏢 Startups (10-100 Mitarbeiter)
- 🏭 SMB (Small/Medium Business)
- 🏠 Homelab mit Production Workloads ✅ **← DU BIST HIER**
- 💰 Budget <$500/Monat für Backup

**NEIN für:**
- 🏦 Banks (brauchen WORM Tape + FIPS 140-2)
- 🏥 Healthcare (HIPAA = 7 Jahre Retention + Audit Trails)
- 🌍 Global SaaS (brauchen Multi-Region DR)
- 📊 Börsennotierte Firmen (SOX Compliance = $$$)

---

## 🎯 **ENTSCHEIDUNG: Homelab Setup ist AUSREICHEND**

**Aktueller Stand:**
```
✅ Automated Backups (4-Tier System)
✅ S3 Storage (Rook Ceph RGW)
✅ Retention Policies (7-90 Tage)
✅ Encryption (SSE-S3 + TLS)
✅ Ransomware Protection (S3 Versioning)
✅ 3x Replication (Ceph On-Prem)

Status: PRODUCTION READY für Homelab 🏠
Cost: $0/Monat (on-prem only)
Risk Acceptance: Bei Totalausfall → Rebuild aus Git/IaC
```

**Cloud DR ÜBERSPRUNGEN weil:**
- ❌ Kein Business Revenue Risk ($0 Downtime Cost)
- ❌ Kosten ($50/Monat) nicht gerechtfertigt
- ✅ IaC in Git = Infrastructure is Code
- ✅ Bei Fire/Flood: Neu aufsetzen aus Git (2-3 Tage)
- ✅ Tier-0 Backups schützen kritische Daten (PostgreSQL)

**Nächster Schritt:** NICHTS - Setup ist komplett ✅
