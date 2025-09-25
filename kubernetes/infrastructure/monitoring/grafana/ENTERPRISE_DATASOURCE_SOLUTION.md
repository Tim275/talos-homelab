# 🏢 Enterprise Grafana Datasource Mapping Solutions

## 🚨 Problem Statement

**Issue**: Grafana dashboards have hardcoded datasource references like `DS_PROMETHEUS`, but we're using VictoriaMetrics
**Error**: `"Datasource(DS_PROMETHEUS) was not found"`
**Previous Solution**: Complex RBAC + PostSync Job (5 files, kubectl patches)

## ✅ Enterprise Solutions (Ranked by Simplicity)

### **SOLUTION 1: Multiple Datasource Aliases** (RECOMMENDED)

**Concept**: Create multiple GrafanaDatasource CRDs with different names pointing to the same VictoriaMetrics backend.

**Benefits**:
- ✅ **Zero RBAC files** - Pure declarative CRD approach
- ✅ **Zero Jobs** - No PostSync hooks or kubectl patching
- ✅ **Works with imported dashboards** - Handles any `DS_*` pattern
- ✅ **Enterprise maintainable** - Standard Kubernetes resources

**Implementation**:
```yaml
# Primary datasource
name: VictoriaMetrics

# Alias for DS_PROMETHEUS references
name: DS_PROMETHEUS

# Additional common patterns
name: DS__VICTORIAMETRICS
name: DS__VICTORIAMETRICS-PROD-ALL
name: Prometheus  # Legacy compatibility
```

**Files**:
- `victoriametrics-datasource.yaml` - Primary + DS_PROMETHEUS alias
- `datasource-aliases.yaml` - Additional common aliases

### **SOLUTION 2: GrafanaDashboard Datasource Mapping** (Per-Dashboard)

**Concept**: Use the `spec.datasources` field in GrafanaDashboard CRDs to map hardcoded references.

**Benefits**:
- ✅ **Dashboard-specific control** - Fine-grained mapping per dashboard
- ✅ **Multiple input mappings** - Handle various DS patterns per dashboard
- ✅ **No RBAC complexity** - Pure CRD approach

**Implementation**:
```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
spec:
  datasources:
    - inputName: "DS_PROMETHEUS"
      datasourceName: "VictoriaMetrics"
    - inputName: "DS__PROMETHEUS"
      datasourceName: "VictoriaMetrics"
  grafanaCom:
    id: 2842
```

**Files**:
- `dashboard-datasource-mappings.yaml` - Enhanced dashboards with mapping

### **SOLUTION 3: ConfigMap Dashboard Provisioning** (Alternative)

**Concept**: Use Grafana's native provisioning with environment variables.

**Implementation**:
```yaml
datasources:
  - name: ${PROMETHEUS_DATASOURCE_NAME:-VictoriaMetrics}
    type: prometheus
    uid: ${DS_PROMETHEUS:-victoriametrics}
```

## 🎯 Recommended Architecture

**Primary Approach**: Multiple Datasource Aliases (Solution 1)
**Fallback**: Per-dashboard mapping for complex cases (Solution 2)

### Enterprise Benefits:
1. **Eliminates complex RBAC** (5 files → 2 files)
2. **No PostSync jobs** - Faster ArgoCD sync
3. **Handles all import patterns** - Works with Grafana.com imports
4. **Future-proof** - Supports any DS_* pattern
5. **GitOps native** - Pure Kubernetes CRD resources

## 📁 File Structure Changes

### ❌ Removed (Old Complex Approach):
- `datasource-fix-rbac.yaml`
- `datasource-fix-role.yaml`
- `datasource-fix-rolebinding.yaml`
- `datasource-fix-job.yaml`
- `prometheus-datasource.yaml`

### ✅ Added (Enterprise Approach):
- `victoriametrics-datasource.yaml` (Enhanced with aliases)
- `datasource-aliases.yaml` (Common pattern aliases)
- `dashboard-datasource-mappings.yaml` (Optional per-dashboard control)

## 🚀 Migration Impact

**Before**:
- 5 RBAC files + 1 PostSync Job
- kubectl patch operations
- Complex debugging when dashboards fail

**After**:
- 2-3 clean CRD files
- Declarative Kubernetes resources
- Automatic dashboard compatibility

## 🌐 Enterprise Pattern Match

This solution follows **Netflix/Google Cloud** patterns:
- **Declarative over Imperative** - CRDs instead of jobs
- **Multiple Service Aliases** - Common in service mesh patterns
- **Zero-downtime Configuration** - No restart-dependent patches
- **GitOps Native** - All resources are git-trackable

## ✅ Validation Checklist

- [ ] VictoriaMetrics primary datasource working
- [ ] DS_PROMETHEUS alias resolves to VictoriaMetrics
- [ ] Legacy "Prometheus" name compatibility maintained
- [ ] Failed imports from logs (DS__VICTORIAMETRICS, DS__VICTORIAMETRICS-PROD-ALL) now work
- [ ] No more "datasource not found" errors in Grafana dashboards
- [ ] ArgoCD sync waves cleaner (no PostSync job delays)
- [ ] Dashboard imports from Grafana.com work without modification

This enterprise solution transforms a complex 5-file RBAC/Job approach into a clean 2-file CRD-based architecture that handles all datasource mapping scenarios.
