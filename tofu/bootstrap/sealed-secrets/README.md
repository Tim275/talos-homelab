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