# Certificate Management Strategy

This document explains how certificates are managed across dev, staging, and prod environments.

## Architecture Overview

```
Cloudflared Tunnel → Envoy Gateway (TLS termination) → HTTP backends
```

All applications use **HTTP backends** with TLS termination at the Envoy Gateway edge.

## Certificate Strategy by Environment

### 1. Development (dev)

**Issuer:** `selfsigned-cluster-issuer`
**Example:** `n8n-dev.timourhomelab.org`

```yaml
issuerRef:
  kind: ClusterIssuer
  name: selfsigned-cluster-issuer
```

**Purpose:** Self-signed certificates for local development and testing. Browsers will show security warnings, which is acceptable for dev environments.

**Files:**
- `kubernetes/apps/base/n8n/environments/dev/certificate.yaml`
- Certificate created but not actively used (wildcard production cert covers all domains)

### 2. Staging (staging)

**Issuer:** `letsencrypt-staging`
**Purpose:** Testing cert-manager configurations and CI/CD pipelines without hitting Let's Encrypt production rate limits.

```yaml
issuerRef:
  kind: ClusterIssuer
  name: letsencrypt-staging
```

**Not trusted by browsers** - only for testing!

### 3. Production (prod)

**Issuer:** `letsencrypt-prod` or `cloudflare-cluster-issuer`
**Example:** `*.timourhomelab.org` (wildcard)

```yaml
issuerRef:
  kind: ClusterIssuer
  name: cloudflare-cluster-issuer
```

**Trusted by all browsers** - production-grade Let's Encrypt certificates.

## Current Setup

The Envoy Gateway uses a **wildcard production certificate** (`*.timourhomelab.org`) that covers ALL environments:
- ✅ `n8n.timourhomelab.org` (prod)
- ✅ `n8n-dev.timourhomelab.org` (dev)
- ✅ `ceph.timourhomelab.org` (prod)
- ✅ Any `*.timourhomelab.org` subdomain

This is the **recommended approach for homelabs** because:
1. Single trusted certificate for all environments
2. No browser warnings even in dev
3. Simpler Gateway configuration
4. Let's Encrypt production rate limits are sufficient (50 certs/week)

## Alternative: Separate Certificates per Environment

For enterprise scenarios requiring different certificates per environment, you would need:
1. Separate Gateway listeners per environment
2. Different domain patterns (e.g., `*.dev.example.com`, `*.prod.example.com`)
3. OR separate Gateway instances per environment

This is **not recommended for homelabs** due to added complexity.

## ClusterIssuer Definitions

Located in: `kubernetes/infrastructure/controllers/cert-manager/cluster-issuers-enterprise.yaml`

- `letsencrypt-prod` - Production Let's Encrypt (trusted)
- `letsencrypt-staging` - Staging Let's Encrypt (not trusted)
- `selfsigned-cluster-issuer` - Self-signed (not trusted)
- `cloudflare-cluster-issuer` - Production with Cloudflare DNS-01 (trusted)

## Testing the Setup

```bash
# Dev environment (with production cert)
curl -I https://n8n-dev.timourhomelab.org

# Prod environment
curl -I https://n8n.timourhomelab.org

# Both should return HTTP 200 with trusted certificates!
```
