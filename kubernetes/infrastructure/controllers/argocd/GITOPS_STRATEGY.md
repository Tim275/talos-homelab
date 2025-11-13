# 🚀 GitOps Strategy 2025 - Enterprise ApplicationSet Patterns

## 🎯 **Our Implementation: GoTemplate + File Generator Pattern**

### **Problem Statement**
Traditional ArgoCD ApplicationSets with hardcoded lists don't respect Kustomize enable/disable patterns.

### **Solution: AWS/Amazon EKS Blueprints Pattern**
We've implemented the **File Generator + GoTemplate** pattern used by enterprise teams:

```yaml
# _enabled.yaml - Central Control File
components:
  - name: grafana
    enabled: true      # ← Edit this to control deployment!
  - name: prometheus
    enabled: false     # ← Disabled component
```

```yaml
# ApplicationSet with GoTemplate
spec:
  goTemplate: true
  generators:
  - git:
      files:
      - path: kubernetes/infrastructure/monitoring/_enabled.yaml
  template:
    spec:
      {{- if .enabled }}
      # Only deploy enabled components!
      {{- end }}
```

### **🏆 Benefits**
- ✅ **Kustomize Control**: Edit `_enabled.yaml` → Controls ApplicationSet
- ✅ **ArgoCD UI Clean**: Only enabled components visible
- ✅ **Enterprise Pattern**: Used by AWS, Amazon EKS Blueprints
- ✅ **Git-Native**: Pure GitOps workflow
- ✅ **Scalable**: Works for any domain (infrastructure, platform, apps)

---

## 📚 **Enterprise Patterns & Sources**

### **🔵 AWS/Amazon EKS Blueprints**
**Source**: https://aws.amazon.com/blogs/containers/continuous-deployment-and-gitops-delivery-with-amazon-eks-blueprints-and-argocd/

**Key Features**:
- Multi-cluster GitOps delivery
- Bootstrap repositories with App-of-Apps per environment
- ApplicationSet automation for cluster management
- Enterprise-grade configuration management

### **🟡 Piotr's TechBlog (2025-03-20)**
**Source**: https://piotrminkowski.com/2025/03/20/the-art-of-argo-cd-applicationset-generators-with-kubernetes/

**Title**: "The Art of Argo CD ApplicationSet Generators"

**Key Topics**:
- Advanced ApplicationSet generator techniques
- Multi-cluster management patterns
- Enterprise deployment strategies
- Kubernetes GitOps best practices

### **🔴 Medium Enterprise Blogs**

#### **Advanced Deployment Strategies**
**Source**: https://medium.com/@kittipat_1413/advanced-deployment-strategies-using-applicationsets-and-application-of-applications-in-argocd-e01774e10561

**Key Features**:
- ApplicationSet + Application of Applications patterns
- Hierarchical service management
- Multi-environment deployment strategies
- Robust frameworks for complex Kubernetes deployments

#### **Utilizing Kustomize with ArgoCD**
**Source**: https://medium.com/@kittipat_1413/utilizing-kustomize-with-argocd-for-application-deployment-df9ed22b04e0

**Key Features**:
- Kustomize integration with ApplicationSets
- Environment-based configuration management
- Automated deployment across multiple clusters
- Best practices for GitOps workflows

---

## 🏗️ **Architecture Patterns**

### **Pattern 1: File Generator Control (Our Choice)**
```bash
monitoring/
├── _enabled.yaml          # ← CONTROL FILE
├── application-set.yaml    # GoTemplate ApplicationSet
├── grafana/               # Component (if enabled: true)
├── prometheus/            # Component (if enabled: false)
└── jaeger/               # Component (if enabled: true)
```

**Workflow**:
1. Edit `_enabled.yaml`
2. Git commit
3. ApplicationSet reads file
4. Only enabled components deploy to ArgoCD

### **Pattern 2: Directory Generator + Conditional**
```bash
overlays/
├── enabled/
│   ├── grafana/          # Enabled components
│   └── jaeger/
└── disabled/
    └── prometheus/       # Disabled components
```

### **Pattern 3: List Generator + Environment Matrix**
```yaml
generators:
- list:
    elements:
    - name: grafana
      env: dev
      enabled: true
    - name: grafana
      env: prod
      enabled: false
```

---

## 🎛️ **Implementation Guide**

### **Step 1: Create Control File**
```yaml
# kubernetes/infrastructure/monitoring/_enabled.yaml
components:
  - name: grafana
    enabled: true
    description: "Grafana dashboards"
  - name: prometheus
    enabled: false
    description: "Prometheus monitoring"
```

### **Step 2: Create ApplicationSet**
```yaml
# kubernetes/infrastructure/monitoring/application-set.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
spec:
  goTemplate: true
  generators:
  - git:
      files:
      - path: kubernetes/infrastructure/monitoring/_enabled.yaml
  template:
    spec:
      {{- if .enabled }}
      # Deploy component
      {{- end }}
```

### **Step 3: Update Kustomization**
```yaml
# kubernetes/infrastructure/monitoring/kustomization.yaml
resources:
  - application-set.yaml    # ApplicationSet controls components
  # Components now controlled via _enabled.yaml!
```

---

## 🔗 **Additional Resources**

### **ArgoCD Official Documentation**
- **ApplicationSet Generators**: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
- **GoTemplate Support**: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Template/
- **Conditional Templates**: https://github.com/argoproj/argo-cd/discussions/16648

### **Enterprise Best Practices**
- **5 ApplicationSet Patterns**: https://devcurrent.com/5-argocd-applicationset-patterns/
- **GitOps Anti-Patterns**: https://codefresh.io/blog/argo-cd-anti-patterns-for-gitops/
- **Repository Structuring**: https://codefresh.io/blog/how-to-structure-your-argo-cd-repositories-using-application-sets/

### **Multi-Cluster Management**
- **ApplicationSet Best Practices**: https://akuity.io/blog/application-dependencies-with-argo-cd
- **Cluster Management**: https://redhat-scholars.github.io/argocd-tutorial/argocd-tutorial/03-kustomize.html

---

## 🚀 **Next Steps**

1. **Extend to Other Domains**: Apply pattern to `controllers/`, `network/`, `storage/`
2. **Environment Matrix**: Add dev/prod conditional deployment
3. **Multi-Cluster**: Extend pattern for multiple clusters
4. **Advanced Templating**: Use `templatePatch` for complex conditionals
5. **Monitoring**: Add ApplicationSet health monitoring

**Status**: ✅ Implemented for monitoring domain
**Pattern**: AWS/Amazon EKS Blueprints File Generator + GoTemplate
**Enterprise Grade**: Production-ready for multi-cluster GitOps
