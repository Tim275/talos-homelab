# 🎯 Backup Priority Matrix: Was MUSS gebackuped werden?

## 📊 Analyse deines Clusters

### ✅ **TIER-0: KRITISCHE DATEN (MUST BACKUP!)**
**= Datenverlust = Business-Critical**

#### 1. **PostgreSQL Datenbanken** 🔴 HIGHEST PRIORITY
```yaml
n8n-prod:
  - n8n-postgres-1, n8n-postgres-2
  - Enthält: Workflows, Executions, Credentials, User Accounts
  - Backup: ✅ Tier-0 (alle 6h)
  - Recovery: Velero PVC Snapshot

n8n-dev:
  - n8n-postgres-1
  - Enthält: Dev Workflows, Test Data
  - Backup: ✅ Tier-1 (täglich)

keycloak:
  - keycloak-db-1
  - Enthält: User Accounts, OIDC Clients, Realm Config
  - Backup: ✅ Tier-0 (alle 6h)
  - Warum kritisch: Login funktioniert nicht ohne!

infisical:
  - infisical-postgres-1
  - Enthält: Secrets, API Keys, Environment Variables
  - Backup: ✅ Tier-0 (alle 6h)
  - Warum kritisch: Alle App-Secrets sind hier!
```

**Velero Selector:**
```yaml
labelSelector:
  matchLabels:
    cnpg.io/cluster: n8n-postgres
    cnpg.io/cluster: keycloak-db
    cnpg.io/cluster: infisical-postgres
```

---

#### 2. **Redis (mit Persistence)** 🟡 HIGH PRIORITY
```yaml
authelia:
  - redis-authelia-0
  - Enthält: Session Data, 2FA Secrets, TOTP Seeds
  - Backup: ✅ Tier-0 (alle 6h)
  - Warum kritisch: User Sessions + 2FA verloren!

n8n-prod:
  - redis-n8n-0
  - Enthält: Job Queue, Workflow Execution State
  - Backup: ✅ Tier-1 (täglich)
  - Warum kritisch: Running workflows verloren

argocd:
  - argocd-redis-ha-server-0,1,2
  - Enthält: Application Sync State, Repo Cache
  - Backup: ⚠️  Tier-2 (wöchentlich)
  - Warum weniger kritisch: ArgoCD kann re-sync from Git
```

**Velero Selector:**
```yaml
labelSelector:
  matchLabels:
    app.kubernetes.io/name: redis
  matchExpressions:
    - key: app.kubernetes.io/instance
      operator: In
      values: [authelia, n8n, argocd]
```

---

#### 3. **Elasticsearch Indices** 🟠 MEDIUM-HIGH PRIORITY
```yaml
elastic-system:
  - production-cluster-es-master-data-0,1,2
  - Enthält: Application Logs, Audit Trails, Metrics
  - Backup: ✅ Elasticsearch Snapshots → Ceph S3
  - Snapshot Repo: ceph-s3-snapshots
  - Schedule: Daily (ILM Policy managed)

Was ist drin?
  - Vector logs (application logs)
  - Audit trails (who did what)
  - Error logs (debugging history)

Warum wichtig?
  - Compliance (DSGVO audit trail)
  - Debugging (incident investigation)
  - Aber: Können neu generiert werden (nicht wie DB-Daten!)
```

**Backup Method:**
```bash
# Elasticsearch hat eigenes Snapshot System (nicht Velero!)
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -X PUT "https://localhost:9200/_snapshot/ceph-s3-snapshots/daily-$(date +%Y%m%d)"
```

---

#### 4. **Grafana Dashboards** 🟡 HIGH PRIORITY
```yaml
grafana:
  - grafana-deployment-*
  - Enthält: Custom Dashboards, Datasources, Alert Rules
  - Backup: ✅ Tier-2 (täglich)
  - Warum wichtig: Dashboards neu erstellen = Stunden Arbeit!

PVC:
  - grafana-storage (SQLite DB mit Dashboard configs)
```

**Velero Selector:**
```yaml
labelSelector:
  matchLabels:
    app.kubernetes.io/name: grafana
```

---

#### 5. **LLDAP User Directory** 🔴 CRITICAL
```yaml
lldap:
  - lldap-*
  - Enthält: User Accounts, Groups, LDAP Tree
  - Backup: ✅ Tier-0 (alle 6h)
  - Warum kritisch: Central User Directory (SSO Basis!)

PVC:
  - lldap-data (SQLite DB mit User Data)
```

---

#### 6. **Authelia Config + Data** 🔴 CRITICAL
```yaml
authelia:
  - authelia-*
  - Enthält: ACL Rules, User Sessions, 2FA Secrets
  - Backup: ✅ Tier-0 (alle 6h)
  - Warum kritisch: Auth Gateway für alle Apps!
```

---

### ⚠️ **TIER-1: WICHTIGE DATEN (Should Backup)**
**= Datenverlust = Ärgerlich, aber rebuild möglich**

#### 7. **Kafka Topics** 🟡 MEDIUM PRIORITY
```yaml
kafka:
  - my-cluster-dual-role-0,1,2
  - Enthält: Persistent Topics, Messages
  - Backup: ⚠️  Tier-1 (täglich)
  - Warum weniger kritisch: Depends on use case

Frage: Hast du wichtige Messages in Kafka?
  - Wenn nur Demo/Test → SKIP BACKUP
  - Wenn Production Events → TIER-0!
```

---

#### 8. **InfluxDB Metrics** 🟢 LOW PRIORITY
```yaml
influxdb:
  - influxdb-0
  - Enthält: Time-Series Metrics (Historical Data)
  - Backup: ⚠️  Tier-3 (wöchentlich)
  - Warum weniger kritisch: Metrics regenerieren sich
  - Aber: Historical Trends verloren!
```

---

#### 9. **Loki Log Storage** 🟢 LOW PRIORITY
```yaml
loki:
  - loki-0
  - Enthält: Log Chunks (compressed logs)
  - Backup: ⚠️  SKIP (too much data, low value)
  - Warum skip: Logs sind in Elasticsearch (besser searchable)
  - Loki = short-term buffer (7-14 Tage retention)
```

---

### ✅ **TIER-2: CONFIG/STATE (Nice to Have)**
**= Verlust = Rebuild dauert 1-2 Stunden**

#### 10. **Sealed Secrets** 🟡 IMPORTANT
```yaml
sealed-secrets:
  - sealed-secrets-controller-*
  - Enthält: Encryption Keys für Sealed Secrets
  - Backup: ✅ Tier-2 (täglich)
  - Warum wichtig: Ohne Keys kannst du Sealed Secrets nicht decrypten!

Was backupen:
  - Secret: sealed-secrets-controller (Encryption Key)
  - Namespace: sealed-secrets
```

---

#### 11. **Cert-Manager Certificates** 🟢 LOW PRIORITY
```yaml
cert-manager:
  - cert-manager-*
  - Enthält: TLS Certificates, Let's Encrypt Accounts
  - Backup: ⚠️  SKIP (LetsEncrypt re-issue möglich)
  - Aber: Rate Limits beachten! (5 certs/domain/week)
```

---

#### 12. **ArgoCD Applications** 🟢 LOW PRIORITY
```yaml
argocd:
  - argocd-application-controller-*
  - Enthält: Application Manifests, Sync State
  - Backup: ⚠️  SKIP (alles in Git!)
  - Recovery: Bootstrap ArgoCD → Auto-sync from Git
```

---

### ❌ **TIER-3: STATELESS (NO BACKUP NEEDED!)**
**= Verlust = Einfach neu deployen (GitOps)**

#### Stateless Operators (SKIP BACKUP):
```yaml
✅ SKIP (GitOps recovery):
  - rook-ceph-operator (aber Ceph DATA = critical!)
  - prometheus-operator
  - grafana-operator
  - elastic-operator
  - strimzi-cluster-operator
  - velero selbst
  - cilium
  - coredns
  - metrics-server
  - kube-prometheus-stack
  - loki-gateway
  - promtail
  - hubble
  - istio-operator
  - jaeger-operator

Warum SKIP?
  - Sind nur Controller (keine Daten)
  - GitOps deployt sie neu aus Manifests
  - Recovery: kubectl apply -k infrastructure/
```

---

## 🎯 **ZUSAMMENFASSUNG: Was gehört in Velero Backups?**

### **Tier-0 (alle 6h):**
```yaml
Namespaces:
  - n8n-prod          # PostgreSQL + Redis (Workflows)
  - keycloak          # PostgreSQL (User Accounts)
  - infisical         # PostgreSQL (Secrets)
  - authelia          # Redis + Config (2FA, Sessions)
  - lldap             # SQLite (User Directory)

Label Selector:
  app.kubernetes.io/component: database
  cnpg.io/cluster: *
  app.kubernetes.io/name: redis (nur authelia, n8n)

Backup Method:
  - Velero CSI Volume Snapshots (Rook Ceph RBD)
  - Include: PVCs, Secrets, ConfigMaps
```

### **Tier-1 (täglich):**
```yaml
Namespaces:
  - n8n-dev           # Dev Environment
  - grafana           # Dashboards, Datasources
  - kafka             # (nur wenn Production Topics!)
  - influxdb          # (optional - Metrics History)

Label Selector:
  app.kubernetes.io/name: grafana
  app.kubernetes.io/name: kafka
```

### **Tier-2 (wöchentlich):**
```yaml
Namespaces:
  - sealed-secrets    # Encryption Keys
  - cert-manager      # (optional - Rate Limits)

Label Selector:
  app.kubernetes.io/name: sealed-secrets
```

### **SKIP (GitOps recovery):**
```yaml
Namespaces:
  - argocd            # (alles in Git)
  - rook-ceph         # (Operator, aber DATA wird via CSI gesichert!)
  - monitoring        # (Prometheus = ephemeral data)
  - kube-system       # (Kubernetes core services)
  - cilium            # (CNI, stateless)
  - velero            # (Backup Tool selbst)
```

---

## 📦 **Aktuelle Velero Backup-Größen (geschätzt):**

```
Tier-0 (kritisch):
  - n8n-prod:      5GB (PostgreSQL + Redis)
  - keycloak:      500MB (PostgreSQL)
  - infisical:     200MB (PostgreSQL)
  - authelia:      100MB (Redis)
  - lldap:         50MB (SQLite)
                   ─────────
  Total:           5.85GB × 4 backups/Tag = 23.4GB/Tag

Tier-1 (wichtig):
  - grafana:       100MB (Dashboards)
  - n8n-dev:       1GB (Dev DB)
                   ─────────
  Total:           1.1GB × 1 backup/Tag = 1.1GB/Tag

Elasticsearch Snapshots:
  - ES Indices:    10GB (komprimiert)
  - Daily:         10GB × 7 Tage = 70GB

Gesamt pro Woche:
  - Velero:        (23.4 + 1.1) × 7 = 171.5GB
  - Elasticsearch: 70GB
                   ─────────
  Total:           241.5GB/Woche

Ceph S3 Bucket (100GB):
  - Mit Rotation (7d Tier-0, 30d Tier-1) = PASST! ✅
```

---

## ✅ **FAZIT: Deine kritischen Backups:**

**MUST BACKUP (Datenverlust = Katastrophe):**
1. ✅ n8n-prod (Workflows, Credentials) → Tier-0
2. ✅ Keycloak (User Accounts) → Tier-0
3. ✅ Infisical (Secrets) → Tier-0
4. ✅ Authelia (2FA, Sessions) → Tier-0
5. ✅ LLDAP (User Directory) → Tier-0

**SHOULD BACKUP (Ärgerlich, aber rebuild möglich):**
6. ✅ Grafana (Dashboards) → Tier-1
7. ✅ n8n-dev (Dev Environment) → Tier-1
8. ⚠️  Kafka (nur wenn Production Events!)
9. ⚠️  Elasticsearch Snapshots (Logs, Audit Trail)

**SKIP BACKUP (GitOps recovery):**
- ❌ ArgoCD (alles in Git)
- ❌ Monitoring Operators (stateless)
- ❌ Rook-Ceph Operator (Ceph DATA wird via CSI gesichert!)
- ❌ Cilium, CoreDNS (stateless)

**Speicherplatz:**
- Velero: ~25GB/Tag × 7 Tage = 175GB
- Elasticsearch: ~70GB (7 Tage Logs)
- Total: ~245GB/Woche
- **Ceph S3 Bucket (100GB):** MIT Rotation = PASST! ✅
