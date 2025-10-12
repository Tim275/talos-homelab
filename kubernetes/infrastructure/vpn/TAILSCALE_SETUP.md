# 🔐 Tailscale VPN Setup Guide
**IKEA-Style Step-by-Step Anleitung** 📋

---

## 📦 **Was du bekommst:**
- ✅ Sicherer VPN-Zugriff zu deinem Kubernetes Cluster
- ✅ Direkt auf Kubernetes Pods zugreifen (10.244.0.0/16)
- ✅ Enterprise Tier-0 Pattern (Operator + HA Connectors)
- ✅ GitOps via ArgoCD (wie Grafana/Sail Operator)
- ✅ Automatic subnet route advertisement

---

## 🛠️ **Was du brauchst:**
- [ ] Tailscale Account (kostenlos): https://login.tailscale.com/
- [ ] MacBook/Laptop mit Tailscale installiert
- [ ] Kubernetes Cluster mit ArgoCD
- [ ] 30 Minuten Zeit

---

## 📋 **Schritt 1: Tailscale Account erstellen**

### 1.1 Gehe zu: https://login.tailscale.com/
### 1.2 Wähle **"Sign up with Google"** oder GitHub
### 1.3 Bestätige deine Email

**✅ Checkpoint:** Du siehst das Tailscale Admin Dashboard

---

## 📋 **Schritt 2: OAuth Client erstellen**

### 2.1 Gehe zu: https://login.tailscale.com/admin/settings/oauth
### 2.2 Klicke **"Generate OAuth Client"**
### 2.3 Wähle Scopes:
   - ✅ **devices:core** (write access)
### 2.4 Kopiere:
   - **Client ID**: `kAcbk5Qcd411CNTRL` (Beispiel)
   - **Client Secret**: `tskey-client-kAcbk5Qcd411CNTRL-...` (Beispiel)

**⚠️ WICHTIG:** Client Secret nur EINMAL sichtbar - kopieren!

**✅ Checkpoint:** Du hast Client ID + Secret kopiert

---

## 📋 **Schritt 3: Access Control List (ACL) konfigurieren**

### 3.1 Gehe zu: https://login.tailscale.com/admin/acls
### 3.2 Ersetze den gesamten JSON Inhalt mit:

```json
{
  "tagOwners": {
    "tag:k8s-operator": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  },

  "autoApprovers": {
    "routes": {
      "10.244.0.0/16": ["tag:k8s"],
      "10.96.0.0/16": ["tag:k8s"]
    }
  },

  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["tag:k8s"],
      "dst": ["tag:k8s:*"]
    },
    {
      "action": "accept",
      "src": ["tag:k8s-operator"],
      "dst": ["tag:k8s:*"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

### 3.3 Klicke **"Save"**

**✅ Checkpoint:** ACL gespeichert ohne Fehler

---

## 📋 **Schritt 4: SealedSecret erstellen**

### 4.1 Auf deinem Laptop (wo kubectl funktioniert):

```bash
# Set kubeconfig
export KUBECONFIG=/path/to/your/kubeconfig.yaml

# OAuth Credentials als Dateien
echo -n 'kAcbk5Qcd411CNTRL' > /tmp/client_id.txt
echo -n 'tskey-client-kAcbk5Qcd411CNTRL-...' > /tmp/client_secret.txt

# SealedSecret generieren
kubectl create secret generic operator-oauth \
  --from-file=client_id=/tmp/client_id.txt \
  --from-file=client_secret=/tmp/client_secret.txt \
  --namespace=tailscale \
  --dry-run=client -o yaml | \
  kubeseal \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=sealed-secrets \
    --format=yaml > kubernetes/infrastructure/vpn/tailscale-operator/oauth-sealed.yaml

# Cleanup
rm /tmp/client_id.txt /tmp/client_secret.txt
```

### 4.2 Überprüfe die Datei:
```bash
cat kubernetes/infrastructure/vpn/tailscale-operator/oauth-sealed.yaml
```

Du solltest sehen:
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: operator-oauth
  namespace: tailscale
spec:
  encryptedData:
    client_id: AgD...
    client_secret: AgB...
```

**✅ Checkpoint:** `oauth-sealed.yaml` erstellt mit verschlüsselten Credentials

---

## 📋 **Schritt 5: GitOps Deployment**

### 5.1 Commit & Push:
```bash
git add kubernetes/infrastructure/vpn/tailscale-operator/
git commit -m "feat: add Tailscale VPN with OAuth authentication"
git push
```

### 5.2 ArgoCD Application erstellen:
Die Application ist bereits in `kubernetes/infrastructure/vpn/tailscale-operator/application.yaml`!

### 5.3 Namespace Label setzen (PodSecurity):
```bash
kubectl label namespace tailscale \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  --overwrite
```

### 5.4 Deployment starten:
```bash
kubectl apply -k kubernetes/infrastructure/vpn/tailscale-operator/
```

**✅ Checkpoint:** Alle Manifests applied ohne Fehler

---

## 📋 **Schritt 6: Deployment verifizieren**

### 6.1 Check Pods:
```bash
kubectl get pods -n tailscale
```

**Erwartete Ausgabe:**
```
NAME                           READY   STATUS    RESTARTS   AGE
operator-67f8b6b66d-snrp7      1/1     Running   0          2m
ts-k8s-subnet-router-n2z8h-0   1/1     Running   0          1m
ts-k8s-subnet-router-n2z8h-1   1/1     Running   0          1m
```

### 6.2 Check Connector Status:
```bash
kubectl get connector -n tailscale
```

**Erwartete Ausgabe:**
```
NAME                SUBNETROUTES                 STATUS
k8s-subnet-router   10.244.0.0/16,10.96.0.0/16   ConnectorCreated
```

### 6.3 Check Tailscale Admin:
Gehe zu: https://login.tailscale.com/admin/machines

Du solltest sehen:
- ✅ `tailscale-operator` (tag:k8s-operator)
- ✅ `talos-homelab-k8s-0` (tag:k8s) - **Subnets**
- ✅ `talos-homelab-k8s-1` (tag:k8s) - **Subnets**

**✅ Checkpoint:** Alle 3 Devices in Tailscale Admin sichtbar

---

## 📋 **Schritt 7: MacBook/Laptop konfigurieren**

### 7.1 Tailscale auf deinem Device installieren:
- **macOS**: https://tailscale.com/download/macos
- **Windows**: https://tailscale.com/download/windows
- **Linux**: https://tailscale.com/download/linux

### 7.2 Tailscale starten und einloggen

### 7.3 Subnet Routes akzeptieren:
```bash
sudo tailscale set --accept-routes=true
```

### 7.4 Status checken:
```bash
tailscale status
```

**Erwartete Ausgabe:**
```
100.87.208.54   macbook-pro-von-timour    timour.miagol@ macOS   -
100.64.235.76   tailscale-operator        tagged-devices linux   -
100.69.215.3    talos-homelab-k8s-0       tagged-devices linux   -
100.99.134.50   talos-homelab-k8s-1       tagged-devices linux   -
```

**✅ Checkpoint:** Du siehst alle Kubernetes Devices

---

## 📋 **Schritt 8: Connectivity testen**

### 8.1 Ping Connector Pod:
```bash
ping -c 3 100.69.215.3
```

**Erwartete Ausgabe:**
```
64 bytes from 100.69.215.3: icmp_seq=0 ttl=64 time=5.264 ms
```

### 8.2 Check Routing Table:
```bash
netstat -rn | grep "10.244\|10.96"
```

**Erwartete Ausgabe:**
```
10.96/16           link#43            UCS                utun19
10.244/16          link#43            UCS                utun19
```

### 8.3 Test Kubernetes Pod IP:
```bash
# Get ArgoCD Pod IP
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.podIP}'

# Output: 10.244.6.66

# Test HTTP zu Pod IP
curl http://10.244.6.66:8080
```

**Erwartete Ausgabe:**
```html
<!doctype html><html>...</html>  # ArgoCD UI HTML
```

**✅ Checkpoint:** Du kannst auf Kubernetes Pods zugreifen!

---

## 🎉 **ERFOLG! Tailscale VPN läuft perfekt!**

### ✅ **Was jetzt funktioniert:**
- ✅ Sicherer VPN-Zugriff zu deinem Kubernetes Cluster
- ✅ Direkt auf alle Pods zugreifen via IP (10.244.x.x)
- ✅ HA Setup (2 Connector Pods)
- ✅ GitOps managed via ArgoCD
- ✅ Automatic route advertisement

---

## 🔧 **Troubleshooting**

### Problem: "Pod CrashLoopBackOff: tag not permitted"
**Lösung**: Check ACL - `tag:k8s-operator` muss in `tagOwners` sein!

### Problem: "Connector Pods starten nicht"
**Lösung**: Namespace Label setzen:
```bash
kubectl label namespace tailscale pod-security.kubernetes.io/enforce=privileged --overwrite
```

### Problem: "MacBook sieht keine Connector Pods"
**Lösung**: Tailscale daemon neustarten:
```bash
sudo launchctl stop com.tailscale.tailscaled
sudo launchctl start com.tailscale.tailscaled
```

### Problem: "Routes nicht in routing table"
**Lösung**: Routes akzeptieren:
```bash
sudo tailscale set --accept-routes=true
```

---

## 📚 **Weiterführende Dokumentation**

- **Tailscale Kubernetes Operator**: https://tailscale.com/kb/1236/kubernetes-operator
- **Cilium eBPF Integration**: https://docs.cilium.io/
- **ArgoCD GitOps**: https://argo-cd.readthedocs.io/

---

## 🎯 **Next Steps: Split-Routing**

Siehe [SPLIT_ROUTING.md](SPLIT_ROUTING.md) für:
- Grafana via VPN erreichbar
- N8N via Cloudflare Tunnel erreichbar
- HTTPRoute-basiertes Routing

---

**Erstellt**: 2025-10-12
**Autor**: Tim275 + Claude
**Version**: 1.0.0 (Enterprise Tier-0 Pattern)
