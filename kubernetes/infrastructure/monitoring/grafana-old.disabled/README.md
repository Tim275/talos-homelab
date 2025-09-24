# 🏛️ Old World Grafana - Helm Managed Setup (ARCHIVED)

This directory contains the **original Helm-based Grafana setup** that was used before migrating to the **Grafana Operator** pattern.

## 📅 Historical Context

- **Created**: Before Grafana Operator migration
- **Last Working Commit**: `3c828be` (before `9c5827e`)
- **Migration Date**: 2025-09-24
- **Replaced By**: `../grafana/` (Grafana Operator CRDs)

## 🏗️ Architecture - Old World

### **Deployment Pattern**:
```yaml
# Helm Chart Deployment
helmCharts:
  - name: grafana
    repo: https://grafana.github.io/helm-charts
    version: "10.0.0"
    releaseName: grafana
    namespace: monitoring
    valuesFile: values.yaml  # Helm values configuration
```

### **Key Components**:
- **`values.yaml`**: Helm chart configuration (admin/admin, storage, etc.)
- **`datasources.yaml`**: Prometheus datasource as ConfigMap
- **`dashboards-configmap.yaml`**: Dashboard provider configuration
- **`dashboards/`**: All dashboard JSON files (original + enterprise additions)

### **Dashboard Loading**:
```yaml
# ConfigMap Pattern (Old World)
metadata:
  labels:
    grafana_dashboard: "1"  # Grafana sidecar discovers this
    grafana_folder: "Infrastructure"
```

## 🆚 vs New Grafana Operator

| Aspect | Old World (Helm) | New World (Operator) |
|--------|------------------|---------------------|
| **Deployment** | Helm Chart | Grafana Operator CRDs |
| **Configuration** | `values.yaml` | `Grafana` CR |
| **Datasources** | ConfigMap | `GrafanaDatasource` CR |
| **Dashboards** | ConfigMap with labels | ConfigMap + CRD options |
| **Management** | Helm lifecycle | Operator lifecycle |
| **Enterprise** | Limited | Full CRD features |

## 📋 Files Included

```
grafana-old/
├── README.md                    # This documentation
├── kustomization.yaml          # Kustomize + Helm chart config
├── values.yaml                 # Helm chart values (admin/admin, PVC, etc.)
├── datasources.yaml           # Prometheus datasource ConfigMap
├── dashboards-configmap.yaml  # Dashboard provider ConfigMap
└── dashboards/                # All dashboard JSON files
    ├── infrastructure/         # Infrastructure dashboards
    ├── applications/          # Application dashboards
    ├── storage/               # Storage dashboards
    └── networking/           # Network dashboards
```

## 🚀 How to Use (If Needed)

**⚠️ This is ARCHIVED - do NOT deploy unless you need rollback!**

To deploy the old Helm-based setup:

```bash
# 1. Remove current Grafana Operator setup
kubectl delete -k kubernetes/infrastructure/monitoring/grafana/

# 2. Deploy old Helm setup
kubectl apply -k kubernetes/infrastructure/monitoring/grafana-old/

# 3. Wait for Helm chart deployment
kubectl get pods -n monitoring | grep grafana
```

## 🔄 Rollback Considerations

If you need to rollback from Grafana Operator to Helm:

1. **Backup current dashboards** from Grafana UI
2. **Delete Grafana Operator resources**:
   ```bash
   kubectl delete grafana grafana-enterprise -n monitoring
   kubectl delete grafanadatasource prometheus -n monitoring
   ```
3. **Apply old world setup** from this directory
4. **Restore dashboards** manually if needed

## 🎯 What's Preserved

- ✅ **All dashboard JSONs** (original + enterprise additions)
- ✅ **Helm values configuration** (admin/admin, PVC setup)
- ✅ **Prometheus datasource** configuration
- ✅ **Dashboard provider** configuration
- ✅ **Working kustomization** ready to deploy

## 📚 Reference

This setup represents the **proven working state** before Grafana Operator migration and serves as:
- **Documentation** of the old architecture
- **Fallback option** if Operator issues arise
- **Comparison reference** for architecture decisions
- **Historical record** of our monitoring evolution

**Status**: 📦 Archived - Not deployed, kept for reference and emergency rollback.