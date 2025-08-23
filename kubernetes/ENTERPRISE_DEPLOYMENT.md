# 🏢 Enterprise Kubernetes Platform - Deployment Guide

## 🎯 **Granulare Kustomize Kontrolle**

### **Level 1: Profile-basierte Deployments (Einfach)**
```bash
# Dein erweitertes Homelab (bestehende Infra + neue Data Layer)
kubectl apply -k kubernetes/overlays/profiles/homelab

# Minimal Setup (nur Core)
kubectl apply -k kubernetes/overlays/profiles/minimal

# Standard Production
kubectl apply -k kubernetes/overlays/profiles/standard  

# Full Enterprise (alles)
kubectl apply -k kubernetes/overlays/profiles/enterprise
```

### **Level 2: Komponenten-basierte Deployments (Granular)**
```bash
# Nur Data Layer testen
kubectl apply -k kubernetes/overlays/components/platform/data/cloudnative-pg
kubectl apply -k kubernetes/overlays/components/platform/data/mongodb-operator

# Einzelne Infrastructure Komponenten
kubectl apply -k kubernetes/overlays/components/infrastructure/monitoring/prometheus
kubectl apply -k kubernetes/overlays/components/infrastructure/monitoring/grafana
kubectl apply -k kubernetes/overlays/components/infrastructure/storage/longhorn

# Mix & Match - Custom Combinations  
kubectl apply -k kubernetes/overlays/components/infrastructure/monitoring  # Ganzes monitoring
kubectl apply -k kubernetes/overlays/components/platform/data             # Ganze data layer
```

### **Level 3: Individual Component Control (Expert)**
```bash
# PostgreSQL allein
kubectl apply -k kubernetes/platform/data/cloudnative-pg

# MongoDB allein
kubectl apply -k kubernetes/platform/data/mongodb-operator

# Bestehende Infrastruktur einzeln
kubectl apply -k kubernetes/infra/monitoring/prometheus
kubectl apply -k kubernetes/infra/storage/longhorn
```

## 🔥 **Data Layer Features**

### **CloudNative PostgreSQL**
- ✅ **High Availability**: 3-node cluster mit automatic failover
- ✅ **Automated Backup**: Point-in-time recovery mit S3
- ✅ **Monitoring Integration**: Prometheus metrics + Grafana dashboards
- ✅ **Rolling Updates**: Zero-downtime PostgreSQL upgrades
- ✅ **Connection Pooling**: PgBouncer integration

### **MongoDB Operator**
- ✅ **Replica Sets**: Multi-node MongoDB clusters
- ✅ **Automated Scaling**: Horizontal + vertical scaling
- ✅ **Backup & Restore**: Automated backup scheduling
- ✅ **Security**: TLS encryption + RBAC integration
- ✅ **Monitoring**: MongoDB metrics für Prometheus

## 🎛️ **Deployment Examples**

### **🏠 Homelab Setup (Recommended)**
```bash
# Dein aktueller Setup + neue Data Layer
kubectl apply -k kubernetes/overlays/profiles/homelab

# Das deployed:
# ✅ Deine bestehende Infrastruktur (ArgoCD, Prometheus, etc.)
# ✅ CloudNative PostgreSQL Operator
# ✅ MongoDB Community Operator  
# ✅ Optimiert für Homelab (2-node clusters, moderate resources)
```

### **🧪 Data Layer Testing**
```bash
# Nur die neuen Database Operators testen
kubectl apply -k kubernetes/overlays/components/platform/data/cloudnative-pg
kubectl apply -k kubernetes/overlays/components/platform/data/mongodb-operator

# Nach Test: Wieder entfernen
kubectl delete -k kubernetes/overlays/components/platform/data/cloudnative-pg
```

### **⚙️ Custom Mix**
```yaml
# Create: kubernetes/overlays/profiles/my-custom/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Core infrastructure (required)
  - ../../../infra/controllers/argocd
  - ../../../infra/controllers/cert-manager
  
  # Select monitoring components
  - ../../components/infrastructure/monitoring/prometheus  # ✅
  - ../../components/infrastructure/monitoring/grafana     # ✅
  # Skip loki, jaeger for resources
  
  # Select data components
  - ../../components/platform/data/cloudnative-pg         # ✅ PostgreSQL
  # Skip MongoDB for now
  
  # Storage
  - ../../components/infrastructure/storage/longhorn      # ✅
```

## 🚀 **Database Usage Examples**

### **PostgreSQL Cluster Usage**
```bash
# Create application database
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: my-app-db
  namespace: postgresql-system
spec:
  cluster:
    name: postgresql-cluster
  name: myapp
  owner: app
EOF

# Get connection details
kubectl get secret postgresql-app-secret -n postgresql-system -o yaml
```

### **MongoDB Cluster Usage**
```bash
# Create MongoDB database
kubectl apply -f - <<EOF  
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: my-mongodb
  namespace: mongodb-system
spec:
  members: 2
  type: ReplicaSet
  version: "7.0.5"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
  - name: app-user
    db: myapp
    passwordSecretRef:
      name: app-password
    roles:
    - name: readWrite
      db: myapp
EOF
```

## 📊 **Monitoring Integration**

Both database operators integrate with your existing monitoring:

- **Grafana Dashboards**: Auto-imported PostgreSQL + MongoDB dashboards
- **Prometheus Metrics**: Database performance metrics
- **Alerting**: Database-specific alert rules
- **Log Aggregation**: Database logs in Loki

## 🔧 **Next Steps & Extensions**

Ready to add more enterprise features:

```bash
# Add Redis for caching
kubectl apply -k kubernetes/overlays/components/platform/data/redis-operator

# Add security layer
kubectl apply -k kubernetes/overlays/components/platform/security/opa
kubectl apply -k kubernetes/overlays/components/platform/security/falco

# Add service mesh
kubectl apply -k kubernetes/overlays/components/platform/service-mesh/istio
```

Your **Enterprise-Grade Kubernetes Platform** is ready! 🎯