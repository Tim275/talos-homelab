# Cert-manager

## Was ist cert-manager?

cert-manager ist ein **Kubernetes Controller** der **automatisch TLS-Zertifikate** für deine Services erstellt und verwaltet.

**Einfach gesagt:** Ein Roboter der dafür sorgt, dass deine Websites das grüne Schloss 🔒 haben.

## Warum brauchen wir cert-manager?

### Ohne cert-manager (manuell):
```bash
# Du musst alle 90 Tage:
1. Neues Zertifikat bei Let's Encrypt beantragen
2. Domain-Besitz beweisen  
3. Zertifikat herunterladen
4. In Kubernetes als Secret speichern
5. Ingress/Gateway konfigurieren

# Vergisst du es → Website zeigt "Unsichere Verbindung" ❌
```

### Mit cert-manager (automatisch):
```yaml
# Du schreibst einmal:
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: meine-app-tls
spec:
  secretName: meine-app-tls
  dnsNames:
    - meine-app.example.com

# cert-manager macht den Rest:
# ✅ Zertifikat holen
# ✅ Automatisch erneuern (alle 90 Tage)
# ✅ In Secret speichern
# ✅ Du musst nie wieder dran denken
```

## Warum ist cert-manager notwendig mit Gateway API?

### Das Problem:
Gateway API ist **brandneu** und **standardisiert**. Es gibt keine "magischen" TLS-Features wie bei alten Ingress Controllern.

**Gateway API sagt:** "Ich kann TLS, aber du musst mir das Zertifikat als Kubernetes Secret geben"

**Du denkst:** "OK, ich erstelle ein Secret mit meinem Zertifikat"

**3 Monate später:** Zertifikat läuft ab → Gateway zeigt "Unsichere Verbindung" → Panik! 😱

### Die Lösung:
cert-manager erstellt automatisch das Secret für Gateway:

```yaml
# Certificate Resource
apiVersion: cert-manager.io/v1
kind: Certificate
spec:
  secretName: wildcard-tls
  dnsNames:
    - "*.homelab.local"

# Gateway nutzt das Secret
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
spec:
  listeners:
    - name: https
      tls:
        certificateRefs:
          - name: wildcard-tls  👈 Automatisch von cert-manager erstellt
```

## Der Prozess

**Warum braucht cert-manager den Cloudflare API Token?**

cert-manager läuft im Cluster, muss aber DNS Records bei Cloudflare erstellen:

```
1. Let's Encrypt: "Beweise Domain-Besitz mit DNS TXT Record"
2. cert-manager nutzt Cloudflare API → erstellt TXT Record
3. Let's Encrypt prüft DNS → gibt Zertifikat zurück
4. cert-manager speichert als Kubernetes Secret
5. Gateway nutzt Secret → Grünes Schloss ✅
```

## Installation Step-by-Step

### 🔧 Schritt 1: Cloudflare API Token erstellen

**Was du in Cloudflare machst:**

1. **Gehe zu:** https://dash.cloudflare.com/profile/api-tokens
2. **Klicke:** "Create Token"
3. **Wähle:** "Custom token"
4. **Token name:** cert-manager
5. **Permissions:**
   - `Zone:Zone:Read`
   - `Zone:DNS:Edit`
6. **Zone Resources:**
   - `Include:All zones` (oder deine spezifische Domain)
7. **Klicke:** "Continue to summary" → "Create Token"
8. **Kopiere den Token:** `1234567890abcdef...` ⚠️ Nur einmal sichtbar!

### 🏗️ Schritt 2: cert-manager installieren (Infrastructure as Code)

**Erstelle die Dateien:**

```bash
# Controller-Setup
mkdir -p kubernetes/infra/controllers/cert-manager
```

```yaml
# kubernetes/infra/controllers/cert-manager/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ns.yaml

helmCharts:
  - name: cert-manager
    repo: https://charts.jetstack.io
    version: 1.18.2
    releaseName: cert-manager
    namespace: cert-manager
    valuesInline:
      installCRDs: true
      extraArgs:
        - "--enable-gateway-api"
```

```yaml
# kubernetes/infra/controllers/cert-manager/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
```

### 🔐 Schritt 3: Cloudflare Token als Sealed Secret

**Erstelle den Sealed Secret:**

```bash
# 1. Erstelle temporäres Secret
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token='DEIN-CLOUDFLARE-TOKEN' \
  --namespace=gateway \
  --dry-run=client -o yaml > temp-secret.yaml

# 2. Verschlüssele es mit kubeseal
kubeseal -f temp-secret.yaml -w kubernetes/infra/network/gateway/cloudflare-api-token.yaml

# 3. Lösche temporäre Datei
rm temp-secret.yaml
```

**Oder manuell erstellen:**

```yaml
# kubernetes/infra/network/gateway/cloudflare-api-token.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: cloudflare-api-token
  namespace: gateway
spec:
  encryptedData:
    api-token: AgBy3i4OJSWK+PiTySYZZA9r... # Hier dein verschlüsselter Token
  template:
    metadata:
      name: cloudflare-api-token
      namespace: gateway
    type: Opaque
```

### 🎯 Schritt 4: Gateway Network Setup

```yaml
# kubernetes/infra/network/gateway/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gateway
```

```yaml
# kubernetes/infra/network/gateway/cloudflare-issuer.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: cloudflare-issuer
  namespace: gateway
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: "DEINE-EMAIL@example.com"  # 👈 Ändere das!
    privateKeySecretRef:
      name: cloudflare-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

```yaml
# kubernetes/infra/network/gateway/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: homelab-tls-cert
  namespace: gateway
spec:
  secretName: homelab-tls-cert
  issuerRef:
    name: cloudflare-issuer
    kind: Issuer
  dnsNames:
    - "*.homelab.local"  # 👈 Ändere deine Domain!
```

```yaml
# kubernetes/infra/network/gateway/gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: homelab-gateway
  namespace: gateway
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      hostname: "*.homelab.local"
    - name: https
      port: 443
      protocol: HTTPS
      hostname: "*.homelab.local"
      tls:
        mode: Terminate
        certificateRefs:
          - name: homelab-tls-cert
```

```yaml
# kubernetes/infra/network/gateway/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ns.yaml
  - cloudflare-api-token.yaml
  - cloudflare-issuer.yaml
  - certificate.yaml
  - gateway.yaml
```

### 🚀 Schritt 5: Deployment via ArgoCD

**Commit und Push:**

```bash
git add kubernetes/infra/
git commit -m "feat: add cert-manager with Gateway API

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

**ArgoCD deployed automatisch** dank der ApplicationSets! 🎯

### ✅ Schritt 6: Verifizierung

```bash
# cert-manager Pods prüfen
kubectl get pods -n cert-manager

# Certificate Status prüfen
kubectl get certificate -n gateway
kubectl describe certificate homelab-tls-cert -n gateway

# Gateway Status prüfen
kubectl get gateway -n gateway
kubectl describe gateway homelab-gateway -n gateway

# Secret wurde erstellt?
kubectl get secret homelab-tls-cert -n gateway
```

## Zusammenfassung

**cert-manager ist der Zertifikats-Roboter für Kubernetes.**

1. **Du sagst:** "Ich hätte gern ein Zertifikat für *.homelab.local"
2. **cert-manager sagt:** "Kein Problem, ich hole das für dich bei Let's Encrypt"
3. **Let's Encrypt sagt:** "Beweise dass du die Domain besitzt"
4. **cert-manager nutzt Cloudflare API:** "Hier ist der DNS Beweis"
5. **Let's Encrypt gibt Zertifikat:** "Hier hast du es"
6. **cert-manager speichert es:** "Gateway, hier ist dein TLS Secret"
7. **Gateway nutzt es:** "Browser, hier ist mein gültiges Zertifikat ✅"

**Das Ergebnis:** Grünes Schloss 🔒 ohne dass du je wieder dran denken musst!

**lets goooog** 🚀