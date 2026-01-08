# Keycloak Authentication Setup

## Current Status

### Implemented
- Kubernetes realm created
- OIDC Clients: ArgoCD, kubectl
- Groups: cluster-admins, developers, viewers
- User: timour (password: test123)
- TOTP/MFA (Google Authenticator)
- Session timeouts configured
- PostgreSQL automated backups (CNPG + Velero)

### Realm Details
- **Realm Name:** kubernetes
- **Keycloak URL:** https://iam.timourhomelab.org
- **OIDC Issuer:** https://iam.timourhomelab.org/realms/kubernetes

## Security s - TODO

### Tier 0 (MUST HAVE)
- [ ] Brute Force Protection
- [ ] Password Policy

### Tier 1 (SHOULD HAVE)
- [ ] Email Verification
- [ ] Backup Codes

### Tier 2 (NICE TO HAVE)
- [ ] WebAuthn/FIDO2
- [ ] Terms & Conditions

## Backup Strategy

### CloudNativePG Scheduled Backup
Daily backup at 2:00 AM to Rook-Ceph S3 bucket.
Retention: 7 days

```bash
kubectl get scheduledbackup -n keycloak
kubectl get backup -n keycloak
```

### Velero Namespace Backup
Daily backup at 3:00 AM including all Keycloak resources.
Retention: 7 days (168h)

```bash
kubectl get schedule.velero.io -n velero keycloak-daily
```

## Jobs

### Realm Setup
Creates kubernetes realm with OIDC clients, groups, and users.

```bash
kubectl apply -f realm-setup.yaml
```

### MFA Setup
Enables TOTP/OTP (Google Authenticator) required action.

```bash
kubectl apply -f mfa-setup.yaml
```

## Adding New OIDC Clients

Edit `realm-setup.yaml` and add new client creation:

```bash
echo "=== Creating <APP-NAME> OIDC client ==="
CLIENT_ID=$(/opt/keycloak/bin/kcadm.sh create clients -r kubernetes \
  -s clientId=<app-name> \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s secret="<client-secret>" \
  -s 'redirectUris=["https://<app>.timourhomelab.org/callback"]' \
  -s standardFlowEnabled=true \
  -i 2>/dev/null || echo "Already exists")
```

Supported apps: ArgoCD, Grafana, Hubble, N8N, Infisical, etc.
