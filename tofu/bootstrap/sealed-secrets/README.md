# Sealed Secrets

## How it works
1. Secrets werden lokal mit dem public cert verschlüsselt, bevor sie committet werden
2. Der Sealed-Secrets-Controller entschlüsselt sie im Cluster mit dem private key
3. Daraus entstehen normale K8s-Secrets, die Apps ganz normal nutzen

## Usage

```bash
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
stringData:
  key: "value"
EOF

kubeseal --cert certificate/sealed-secrets.crt --format yaml < secret.yaml > sealed-secret.yaml
rm secret.yaml
git add sealed-secret.yaml
```

Zertifikat liegt unter `certificate/sealed-secrets.crt`. Nie Klartext-Secrets committen.

## ⚠️ Key-Restore nach `tofu destroy`/`apply`

Der Controller generiert bei jedem Neustart auf leerem Cluster ein **neues**
Key-Pair — alle bestehenden SealedSecrets werden dann unlesbar
(`no key could decrypt secret` bei `kubectl get sealedsecrets -A`).

Nach jedem Cluster-Rebuild:
```bash
kubectl delete secret sealed-secrets-key* -n sealed-secrets
kubectl create secret tls sealed-secrets-key \
  --cert=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
  --key=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.key \
  -n sealed-secrets
kubectl label secret sealed-secrets-key -n sealed-secrets \
  sealedsecrets.bitnami.com/sealed-secrets-key=active
kubectl rollout restart deployment sealed-secrets-controller -n sealed-secrets
kubectl get sealedsecrets --all-namespaces   # SYNCED muss ueberall True sein
```

Betroffen, wenn die Keys mismatchen: Cert-Issuance, Cloudflare Tunnel, PVC-Provisioning,
Alertmanager-Notifications, Velero.
