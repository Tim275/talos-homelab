# Commit Message Guidelines

## ✅ **GOOD Commit Messages (Short & Clear)**

```
fix: disable Velero CRD upgrade hook for ArgoCD compatibility
feat: add Elasticsearch cold tier optimization (40-50% savings)
docs: add Elasticsearch license comparison guide
fix: correct Elasticsearch SLM cron to Quartz format
feat: enable S3 snapshots for Elasticsearch with Ceph RGW
```

## ❌ **BAD Commit Messages (Too Long)**

```
fix: disable Velero CRD upgrade hook (ArgoCD compatibility)
- ArgoCD cannot handle Helm hooks (helm.sh/hook annotation)
- CRDs are already installed, upgrade not needed
- Fixes stuck sync waiting for velero-upgrade-crds hook
- Resolves: waiting for completion of hook rbac.authorization.k8s.io/ClusterRole/velero-upgrade-crds

docs: add comprehensive Elasticsearch license comparison to POLICIES_GUIDE
- Add license tiers comparison table (Basic, Platinum, Enterprise)
- Document break-even analysis for Enterprise upgrade (~18TB)
- Add decision tree for license selection
- Highlight SAML/OIDC requires Platinum license
- Add upgrade scenarios and recommendations
- Cross-reference LICENSE_COMPARISON.md for details
```

## 📏 **Rules**

### 1. **One-Line Summary Only**
- Maximum 72 characters
- Start with type: `feat`, `fix`, `docs`, `refactor`, `chore`
- No bullet points or multi-line descriptions

### 2. **Format**
```
<type>: <short description>
```

**Examples:**
```
feat: add N8N backup schedule with Velero
fix: resolve ArgoCD sync timeout for Velero
docs: update Elasticsearch optimization guide
refactor: simplify Vector log routing configuration
chore: update Velero to v1.14.1
```

### 3. **Type Prefixes**

| Type | When to Use |
|------|-------------|
| `feat` | New feature or functionality |
| `fix` | Bug fix or error resolution |
| `docs` | Documentation only |
| `refactor` | Code restructuring (no behavior change) |
| `chore` | Maintenance (dependencies, cleanup) |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |

### 4. **What NOT to Include**

❌ Bullet points
❌ Multi-line descriptions
❌ Technical implementation details
❌ Issue references (unless critical)
❌ Explanations of "why" (save for PR description)

### 5. **Examples from Real Commits**

**Instead of:**
```
feat: implement Elastic best practices - namespace differentiation and professional Data Views
- Vector: Add Proxmox hostname extraction (nipogi/minisforum separation)
- Vector: Add Talos node role detection (control-plane vs workers)
- Vector: Dynamic namespace routing for host/node differentiation
- Kibana: Replace 12 tier-based views with 23 Elastic-compliant views
```

**Write:**
```
feat: implement Elastic namespace differentiation for Vector and Kibana
```

**Instead of:**
```
fix: disable Velero CRD upgrade hook (ArgoCD compatibility)
- ArgoCD cannot handle Helm hooks (helm.sh/hook annotation)
- CRDs are already installed, upgrade not needed
```

**Write:**
```
fix: disable Velero CRD upgrade hook for ArgoCD
```

## 🎯 **Quick Reference**

**Good:**
- `feat: add Keycloak OIDC integration for Grafana`
- `fix: resolve Prometheus scrape timeout for Elasticsearch`
- `docs: add Velero backup restore procedures`
- `refactor: consolidate Vector log transforms`
- `chore: upgrade Talos to v1.10.6`

**Bad:**
- `feat: add Keycloak OIDC integration for Grafana with SAML fallback and role mapping`
- `fix: resolve Prometheus scrape timeout for Elasticsearch (increased timeout from 10s to 30s, added retry logic, fixed TLS verification)`

## 💡 **Why Short Commits?**

1. **Git Log Readability**: `git log --oneline` shows full message
2. **GitHub UI**: Commit list displays first 72 characters
3. **Searchability**: Easy to find specific changes
4. **Professional Standard**: Industry best practice

## 🚀 **Action Items**

- [x] Keep commit messages to ONE line
- [x] Use type prefixes consistently
- [x] Stay under 72 characters
- [x] Save details for documentation files
- [x] No bullet points in commit messages

---

**TL;DR**: One sentence, max 72 chars, start with type prefix.
