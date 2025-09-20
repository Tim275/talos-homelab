# 🏢 Enterprise Jaeger Operator Manifests

## 🎯 **Why Local Manifests?**

**Enterprise-Grade Principle:** Never depend on external URLs in production deployments.

### ❌ **Anti-Pattern:**
```yaml
resources:
  - https://github.com/jaegertracing/jaeger-operator/releases/download/v1.65.0/jaeger-operator.yaml
```

**Problems:**
- **Single Point of Failure:** GitHub outages break deployments
- **Security Risk:** Unvalidated external YAML execution
- **No Version Control:** Manifest changes without notice
- **Network Dependencies:** Fragile during deployment

### ✅ **Enterprise Solution:**
```yaml
resources:
  - manifests/jaeger-operator-v1.65.0.yaml  # Local versioned manifests
```

**Benefits:**
- **Air-Gapped Deployments:** No external dependencies
- **Security:** Manifests reviewed and committed to Git
- **Reproducibility:** Exact same manifests every deployment
- **Audit Trail:** Git history of all changes

## 📦 **Manifest Versioning**

| File | Version | Source | Date |
|------|---------|--------|------|
| `jaeger-operator-v1.65.0.yaml` | v1.65.0 | [GitHub Release](https://github.com/jaegertracing/jaeger-operator/releases/tag/v1.65.0) | 2025-09-19 |

## 🔄 **Update Process**

```bash
# 1. Download new version
curl -L https://github.com/jaegertracing/jaeger-operator/releases/download/v1.66.0/jaeger-operator.yaml \
  -o kubernetes/infra/monitoring/jaeger/manifests/jaeger-operator-v1.66.0.yaml

# 2. Update kustomization.yaml
sed -i 's/jaeger-operator-v1.65.0.yaml/jaeger-operator-v1.66.0.yaml/' \
  kubernetes/infra/monitoring/jaeger/kustomization.yaml

# 3. Test and commit
git add kubernetes/infra/monitoring/jaeger/manifests/jaeger-operator-v1.66.0.yaml
git commit -m "feat: Update Jaeger operator to v1.66.0"
```

This follows Netflix/Uber enterprise practices! 🚀