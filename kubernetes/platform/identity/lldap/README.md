# LLDAP - Lightweight LDAP User Directory

LLDAP is a lightweight authentication server that implements a subset of the LDAP protocol, specifically designed for small-scale deployments.

## 🎯 Purpose

- **User Directory**: Centralized user management for homelab
- **LDAP Authentication**: Standard LDAP protocol support
- **Authelia Integration**: Provides user backend for OIDC provider

## 📂 Architecture

```
platform/identity/lldap/
├── application.yaml     # ArgoCD Application
├── kustomization.yaml   # Kustomize configuration
├── namespace.yaml       # lldap namespace
├── configmap.yaml       # LLDAP configuration
├── deployment.yaml      # LLDAP deployment
├── service.yaml         # Services (LDAP + HTTP)
├── sealed-secrets.yaml  # Encrypted secrets
└── README.md           # This file
```

## 🔧 Configuration

### Base Configuration
- **Base DN**: `dc=homelab,dc=local`
- **Admin User**: `admin`
- **LDAP Port**: `3890` (internal), `389` (service)
- **HTTP Port**: `17170` (web UI)

### Security Features
- **Rootless container** (user 1000)
- **Read-only filesystem**
- **No privileged escalation**
- **Security context hardening**

## 🚀 Deployment

### Prerequisites
1. **Sealed Secrets Controller** must be deployed
2. **Secrets must be generated** and sealed

### Generate Secrets
```bash
# 1. Generate random secrets
JWT_SECRET=$(openssl rand -base64 32)
KEY_SEED=$(openssl rand -base64 32)
ADMIN_PASSWORD="homelab-admin-2024"

# 2. Create and seal secrets
kubectl create secret generic lldap-secrets \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=key-seed="$KEY_SEED" \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --namespace=lldap --dry-run=client -o yaml \
| kubeseal -o yaml > sealed-secrets.yaml
```

### Deploy via ArgoCD
The application will be automatically deployed through the platform ApplicationSet.

## 🔗 Integration

### Service Endpoints
- **LDAP Protocol**: `lldap-ldap.lldap.svc.cluster.local:389`
- **HTTP Admin UI**: `lldap.lldap.svc.cluster.local:17170`

### Authelia Integration
```yaml
authentication_backend:
  ldap:
    url: ldap://lldap-ldap.lldap.svc.cluster.local:389
    base_dn: dc=homelab,dc=local
    user: admin
    password: # From secret
```

## 📊 Monitoring

### Health Checks
- **Readiness**: `/health` endpoint on port 17170
- **Liveness**: `/health` endpoint on port 17170

### Resources
- **Requests**: 50m CPU, 64Mi RAM
- **Limits**: 200m CPU, 256Mi RAM

## 🔄 Next Steps

1. **Deploy LLDAP** ✅
2. **Create initial users** via web UI
3. **Deploy Authelia** with LLDAP backend
4. **Configure OIDC** in Talos
5. **Setup RBAC mappings**

## 🛡️ Security Notes

- Uses **SQLite** for simplicity (single replica)
- Can be migrated to **PostgreSQL** for HA later
- **TLS/LDAPS** can be enabled with cert-manager
- **SMTP** can be configured for password resets