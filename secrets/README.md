# Secrets Management

This folder contains encrypted secrets and sensitive configuration files.

## Structure
- `sealed-secrets/` - SealedSecrets YAML files  
- `raw/` - Unencrypted secrets for development (DO NOT COMMIT)
- `backup/` - Backup copies of sealed secrets

## Usage
1. Store raw secrets in `raw/` folder (ignored by git)
2. Use `kubeseal` to encrypt secrets to `sealed-secrets/`
3. Apply sealed secrets to cluster
4. Keep backups in `backup/` folder

## Commands
```bash
# Encrypt a secret
kubeseal --format=yaml < raw/secret.yaml > sealed-secrets/secret-sealed.yaml

# Decrypt for debugging (requires cluster access)
kubectl get secret <name> -o yaml
```