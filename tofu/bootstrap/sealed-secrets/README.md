# Sealed Secrets

## How it works
1. **Encrypt secrets locally** with public cert before commit
2. **Sealed Secrets controller** decrypts them in cluster with private key
3. **Creates normal K8s Secrets** that apps can use

## Usage

**Create encrypted secret:**
```bash
# 1. Create normal secret YAML
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
stringData:
  key: "value"
EOF

# 2. Encrypt with kubeseal
kubeseal --cert certificate/sealed-secrets.crt --format yaml < secret.yaml > sealed-secret.yaml

# 3. Delete plaintext and commit encrypted version
rm secret.yaml
git add sealed-secret.yaml
```

**Certificate location:** `certificate/sealed-secrets.crt`

**⚠️ Never commit plaintext secrets - only SealedSecrets!**

---

## 🚨 CRITICAL: SealedSecrets Key Management for tofu destroy/apply

### Problem
When you run `tofu destroy` and `tofu apply`, the SealedSecrets controller generates **NEW** private/public keys, making **ALL existing SealedSecrets unreadable**!

### Symptoms
```bash
kubectl get sealedsecrets --all-namespaces
# Shows: "no key could decrypt secret (key-name)" for ALL secrets
```

### Solution: Restore Bootstrap Keys

**After every `tofu apply` that recreates the cluster, run:**

```bash
# 1. Delete auto-generated key
kubectl delete secret sealed-secrets-key* -n sealed-secrets

# 2. Restore original bootstrap keys
kubectl create secret tls sealed-secrets-key \
  --cert=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
  --key=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.key \
  -n sealed-secrets

# 3. Label as active
kubectl label secret sealed-secrets-key -n sealed-secrets \
  sealedsecrets.bitnami.com/sealed-secrets-key=active

# 4. Restart controller
kubectl rollout restart deployment sealed-secrets-controller -n sealed-secrets

# 5. Verify ALL SealedSecrets work
kubectl get sealedsecrets --all-namespaces
# Should show "True" in SYNCED column for all secrets
```

### Prevention Best Practices

1. **Backup Keys Before Destroy:**
   ```bash
   # Before tofu destroy
   mkdir -p secrets/backup/$(date +%Y%m%d_%H%M%S)/
   kubectl get secret sealed-secrets-key* -n sealed-secrets -o yaml > \
     secrets/backup/$(date +%Y%m%d_%H%M%S)/sealed-secrets-keys.yaml
   ```

2. **Automated Post-Deploy Script:**
   Create `post-deploy-restore.sh`:
   ```bash
   #!/bin/bash
   set -e
   echo "🔧 Restoring SealedSecrets keys..."
   kubectl delete secret sealed-secrets-key* -n sealed-secrets --ignore-not-found
   kubectl create secret tls sealed-secrets-key \
     --cert=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
     --key=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.key \
     -n sealed-secrets
   kubectl label secret sealed-secrets-key -n sealed-secrets \
     sealedsecrets.bitnami.com/sealed-secrets-key=active
   kubectl rollout restart deployment sealed-secrets-controller -n sealed-secrets
   echo "✅ SealedSecrets keys restored - waiting for pods..."
   kubectl rollout status deployment sealed-secrets-controller -n sealed-secrets
   echo "🎉 All SealedSecrets should work now!"
   ```

3. **Alternative: Persistent Storage for Keys** (Advanced)
   - Store keys in external secrets management (Vault, etc.)
   - Use persistent volumes for key storage
   - Consider external-secrets-operator integration

### Why This Happens
- SealedSecrets controller auto-generates keys on first startup
- `tofu destroy` removes all cluster state including keys
- `tofu apply` creates fresh cluster with new auto-generated keys
- Old SealedSecrets encrypted with old keys become unreadable

### Critical Services Affected
When keys mismatch, these services FAIL:
- 🔒 **Certificate Issuance** (TLS/SSL certs)
- 🌐 **Cloudflare Tunnel** (External access)  
- 💾 **Storage Provisioning** (PVCs fail)
- 📢 **Monitoring Alerts** (Slack notifications)
- 💿 **Backup Systems** (Velero)

**⚠️ ALWAYS restore keys immediately after cluster recreation!**