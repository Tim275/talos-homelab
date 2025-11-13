# 🔐 HOW TO: Secrets mit Infisical verschlüsseln & verwalten

## 📋 **ÜBERSICHT - Workflow**

```
1. Infisical UI → Secret hinzufügen
2. Service Token generieren
3. Token als Kubernetes Secret speichern (sealed!)
4. InfisicalSecret CR erstellen
5. Operator synchronisiert automatisch
6. App nutzt Kubernetes Secret
```

---

## 🎯 **SCHRITT 1: Infisical UI Setup (Port-Forward)**

### **1.1 Port-Forward starten**

```bash
export KUBECONFIG=/Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch/tofu/output/kube-config.yaml
kubectl port-forward -n infisical svc/infisical 8080:8080
```

Dann öffne: **http://localhost:8080**

### **1.2 Admin Account erstellen**

Falls noch nicht gemacht:
- Email: `admin@timourhomelab.org` (oder deine Email)
- Password: **Starkes Passwort wählen!**
- Organization: `Timour Homelab`

---

## 🗂️ **SCHRITT 2: Project erstellen**

### **2.1 Neues Project anlegen**

1. In Infisical UI: Klick auf **"+ New Project"**
2. Name: `homelab-secrets` (oder beliebig)
3. **Environments**:
   - `development` (automatisch erstellt)
   - `staging` (optional)
   - `production` (automatisch erstellt)

### **2.2 Secrets hinzufügen**

**Beispiel: N8N Database Secrets**

1. Wähle Environment: **`production`**
2. Klick **"+ Add Secret"**
3. Füge hinzu:

```yaml
# Key-Value Paare
DB_HOST: "n8n-postgres-rw.n8n-prod.svc.cluster.local"
DB_PORT: "5432"
DB_NAME: "n8n"
DB_USER: "n8n"
DB_PASSWORD: "super-secure-password-123!"  # Wird verschlüsselt gespeichert
ENCRYPTION_KEY: "n8n-encryption-key-base64=="
```

4. Klick **"Save"**

**✅ Secrets sind jetzt verschlüsselt in Infisical gespeichert!**

---

## 🔑 **SCHRITT 3: Service Token generieren**

### **3.1 Token erstellen**

1. Gehe zu: **Project Settings** → **Service Tokens**
2. Klick: **"+ Create Service Token"**
3. Konfiguration:
   - **Name**: `n8n-prod-token`
   - **Environment**: `production`
   - **Expiration**: `Never` (oder custom)
   - **Permissions**: `Read` (reicht für sync)
4. **Kopiere den Token!** (nur einmal sichtbar)

Format: `st.xxx.yyy.zzz` (langer Base64 String)

---

## 📦 **SCHRITT 4: Token als Kubernetes Secret speichern**

### **4.1 Unsealed Secret erstellen**

```bash
# /tmp/n8n-service-token.yaml
cat > /tmp/n8n-service-token.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: infisical-service-token
  namespace: n8n-prod
type: Opaque
stringData:
  token: "st.xxx.yyy.zzz"  # HIER DEN ECHTEN TOKEN EINFÜGEN!
EOF
```

### **4.2 Mit Sealed Secrets verschlüsseln**

```bash
export KUBECONFIG=/Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch/tofu/output/kube-config.yaml

kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  --format=yaml \
  < /tmp/n8n-service-token.yaml \
  > kubernetes/apps/n8n/prod/infisical-token-sealed.yaml
```

### **4.3 Sealed Secret committen**

```bash
cd kubernetes/apps/n8n/prod
git add infisical-token-sealed.yaml
git commit -m "feat: add Infisical service token for N8N prod secrets"
git push
```

---

## 🔄 **SCHRITT 5: InfisicalSecret CR erstellen**

### **5.1 CR Manifest erstellen**

```yaml
# kubernetes/apps/n8n/prod/infisical-secret.yaml
---
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: n8n-database-secrets
  namespace: n8n-prod
  annotations:
    # Optional: Auto-reload pods when secrets change
    secrets.infisical.com/auto-reload: "true"
spec:
  # Infisical API endpoint (internal service)
  hostAPI: http://infisical.infisical.svc.cluster.local:8080/api

  # Sync interval (in seconds)
  resyncInterval: 60

  # Authentication
  authentication:
    serviceToken:
      # Reference to the sealed secret we created
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: n8n-prod

      # Which Infisical project/environment to sync from
      secretsScope:
        projectSlug: homelab-secrets
        envSlug: production
        # Optional: only sync specific path
        # secretsPath: /n8n/database

  # Target Kubernetes Secret (will be created/updated)
  managedSecretReference:
    secretName: n8n-database-credentials
    secretNamespace: n8n-prod
    secretType: Opaque
```

### **5.2 Zu Kustomization hinzufügen**

```yaml
# kubernetes/apps/n8n/prod/kustomization.yaml
resources:
  - namespace.yaml
  - infisical-token-sealed.yaml   # ← NEU
  - infisical-secret.yaml          # ← NEU
  - deployment.yaml
  # ... rest
```

---

## 🚀 **SCHRITT 6: Deployment anpassen**

### **6.1 App-Deployment updaten**

```yaml
# kubernetes/apps/n8n/prod/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
  namespace: n8n-prod
spec:
  template:
    spec:
      containers:
        - name: n8n
          image: n8nio/n8n:latest

          # Option 1: Environment Variables aus Secret
          envFrom:
            - secretRef:
                name: n8n-database-credentials  # ← Von Infisical synced!

          # Option 2: Einzelne Env Vars
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: n8n-database-credentials
                  key: DB_HOST
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: n8n-database-credentials
                  key: DB_PASSWORD

          # Option 3: Als Volume mounten
          volumeMounts:
            - name: db-credentials
              mountPath: /run/secrets
              readOnly: true

      volumes:
        - name: db-credentials
          secret:
            secretName: n8n-database-credentials
```

---

## ✅ **SCHRITT 7: Deploy & Verify**

### **7.1 ArgoCD Sync**

```bash
export KUBECONFIG=/Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch/tofu/output/kube-config.yaml

# Trigger sync
kubectl patch application n8n-prod -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### **7.2 Verify Sync**

```bash
# Check InfisicalSecret Status
kubectl get infisicalsecret -n n8n-prod
kubectl describe infisicalsecret n8n-database-secrets -n n8n-prod

# Check managed Secret
kubectl get secret n8n-database-credentials -n n8n-prod

# View Secret (base64 decoded)
kubectl get secret n8n-database-credentials -n n8n-prod -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### **7.3 Check Operator Logs**

```bash
kubectl logs -n infisical -l app.kubernetes.io/name=infisical-secrets-operator --tail=50
```

---

## 🔄 **WORKFLOW - Secrets ändern**

### **Wenn du ein Secret updaten willst:**

1. **Infisical UI öffnen**: http://localhost:8080
2. **Secret bearbeiten**: Ändere z.B. `DB_PASSWORD`
3. **Save klicken**
4. **Warten** (max 60 Sekunden - `resyncInterval`)
5. **Automatisch**: Operator synced → Kubernetes Secret updated
6. **Optional**: Pods neu starten (falls keine auto-reload)

```bash
# Pods mit neuem Secret neu starten
kubectl rollout restart deployment/n8n -n n8n-prod
```

---

## 🎯 **BEST PRACTICES**

### ✅ **DO's**

- ✅ **Ein Project pro Application** (n8n, grafana, etc.)
- ✅ **Environments nutzen**: dev/staging/prod
- ✅ **Service Tokens** mit **Read-only** Permissions
- ✅ **Token Expiration** setzen (90 days)
- ✅ **Secrets in Infisical kategorisieren** (z.B. `/database`, `/api`)
- ✅ **Sealed Secrets für Tokens** verwenden

### ❌ **DON'Ts**

- ❌ **NIEMALS** Service Token in Git plaintext committen!
- ❌ **NIEMALS** Token mit Write-Permissions vergeben
- ❌ **NIEMALS** `Never expire` Token für Production
- ❌ **NICHT** alle Secrets in ein einziges Project packen

---

## 📊 **SECRET LIFECYCLE**

```
┌─────────────────────────────────────────────────────┐
│ 1. CREATE: Infisical UI                            │
│    └─> Secret verschlüsselt mit ROOT_ENCRYPTION_KEY│
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│ 2. SYNC: Infisical Operator (every 60s)            │
│    └─> Fetch from Infisical API via Service Token  │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│ 3. STORE: Kubernetes Secret (in-cluster)           │
│    └─> Base64 encoded (K8s standard)               │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│ 4. USE: Application Pod                            │
│    └─> EnvFrom / VolumeMount                       │
└─────────────────────────────────────────────────────┘
```

---

## 🔍 **TROUBLESHOOTING**

### **Problem: Secret wird nicht synced**

```bash
# Check InfisicalSecret Status
kubectl describe infisicalsecret n8n-database-secrets -n n8n-prod

# Check Operator Logs
kubectl logs -n infisical -l control-plane=controller-manager --tail=100

# Common Issues:
# - Wrong Service Token
# - Wrong projectSlug or envSlug
# - Token expired
# - Infisical API unreachable
```

### **Problem: Token invalid**

```bash
# Regenerate token in Infisical UI
# Update sealed secret
# Delete old secret to force recreation
kubectl delete secret infisical-service-token -n n8n-prod
```

---

## 📚 **EXAMPLE: Complete Setup**

### **File Structure**

```
kubernetes/apps/n8n/prod/
├── kustomization.yaml
├── namespace.yaml
├── infisical-token-sealed.yaml      # Sealed Service Token
├── infisical-secret.yaml            # InfisicalSecret CR
└── deployment.yaml                  # N8N Deployment
```

### **Full Example in Next File...**

(see EXAMPLE-n8n-infisical-setup.yaml)

---

## ✅ **FERTIG!**

Du hast jetzt:
- ✅ Secrets verschlüsselt in Infisical gespeichert
- ✅ Automatische Synchronisation zu Kubernetes
- ✅ GitOps-freundlicher Workflow
- ✅ Zero-Trust Security (Token sealed)

**Next Steps**: Migriere weitere Apps zu Infisical! 🚀
