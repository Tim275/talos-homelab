# Netflix-Style Smart ApplicationSet Pattern

## 🎯 Advanced GitOps Pattern - Enterprise Grade

### Overview
Netflix-Style pattern uses custom ArgoCD plugins to parse kustomization.yaml files and make intelligent deployment decisions based on complex logic, not just commenting/uncommenting resources.

### Architecture
```
kustomization.yaml → Custom Plugin → Smart Logic → ApplicationSet → ArgoCD Applications
```

## 🔧 Implementation

### 1. Custom ArgoCD Plugin (kustomize-parser)
```yaml
# argocd-config/plugins/kustomize-parser.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmp-kustomize-parser
  namespace: argocd
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: kustomize-parser
    spec:
      version: v1.0
      generate:
        command: [sh, -c]
        args:
          - |
            # Parse kustomization.yaml with advanced logic
            python3 /scripts/kustomize-parser.py --input kustomization.yaml --output /tmp/applications.json
      discover:
        find:
          command: [sh, -c, "find . -name kustomization.yaml"]
```

### 2. Smart Parser Script
```python
#!/usr/bin/env python3
# /scripts/kustomize-parser.py

import yaml
import json
import os
import sys

def parse_kustomization(kustomization_path):
    """Parse kustomization.yaml with Netflix-style intelligence"""

    with open(kustomization_path, 'r') as f:
        kustomize_config = yaml.safe_load(f)

    applications = []

    # 1. Parse resources (basic filtering)
    resources = kustomize_config.get('resources', [])
    for resource in resources:
        if not resource.startswith('#'):  # Not commented
            applications.append({
                'name': os.path.basename(resource),
                'path': resource,
                'enabled': True
            })

    # 2. Parse patches for conditional logic
    patches = kustomize_config.get('patches', [])
    for patch in patches:
        target = patch.get('target', {})
        patch_content = patch.get('patch', '')

        # Check for enabled: "false" annotations
        if 'enabled: "false"' in patch_content:
            app_name = target.get('name')
            # Disable application
            for app in applications:
                if app['name'] == app_name:
                    app['enabled'] = False

    # 3. Parse configMapGenerator for environment logic
    config_maps = kustomize_config.get('configMapGenerator', [])
    for cm in config_maps:
        literals = cm.get('literals', [])
        for literal in literals:
            if literal.startswith('environment='):
                env = literal.split('=')[1]
                # Enable/disable based on environment
                if env == 'production':
                    enable_production_apps(applications)
            elif literal.startswith('enable_monitoring='):
                enable_monitoring = literal.split('=')[1] == 'true'
                toggle_monitoring_apps(applications, enable_monitoring)

    # 4. Parse images for version-based deployment
    images = kustomize_config.get('images', [])
    for image in images:
        name = image.get('name')
        new_tag = image.get('newTag')

        # Skip alpha/beta versions in production
        if 'alpha' in new_tag or 'beta' in new_tag:
            disable_app_by_image(applications, name)

    return applications

def enable_production_apps(applications):
    """Enable production-grade applications only"""
    production_apps = ['prometheus', 'grafana', 'rook-ceph', 'cert-manager']
    for app in applications:
        if app['name'] not in production_apps:
            app['enabled'] = False

def toggle_monitoring_apps(applications, enable):
    """Enable/disable monitoring applications"""
    monitoring_apps = ['prometheus', 'grafana', 'alertmanager', 'jaeger']
    for app in applications:
        if app['name'] in monitoring_apps:
            app['enabled'] = enable

def disable_app_by_image(applications, image_name):
    """Disable applications using specific images"""
    for app in applications:
        if image_name in app.get('images', []):
            app['enabled'] = False

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    applications = parse_kustomization(args.input)

    # Filter only enabled applications
    enabled_apps = [app for app in applications if app['enabled']]

    with open(args.output, 'w') as f:
        json.dump(enabled_apps, f)
```

### 3. Smart ApplicationSet
```yaml
# infrastructure/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infrastructure-smart
  namespace: argocd
spec:
  generators:
    # 🧠 NETFLIX-STYLE: Smart Plugin-based Generator
    - plugin:
        configMapRef:
          name: kustomize-parser-config
        input:
          parameters:
            path: "kubernetes/infrastructure/kustomization.yaml"
            environment: "production"
            cluster: "homelab"
  template:
    metadata:
      name: '{{name}}'
      annotations:
        # Netflix-style metadata
        deployment.strategy: "smart"
        managed.by: "kustomize-parser"
        environment: "{{environment}}"
    spec:
      project: infrastructure
      source:
        repoURL: https://github.com/Tim275/talos-homelab
        targetRevision: HEAD
        path: 'kubernetes/infrastructure/{{path}}'
        kustomize: {}
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{name}}'
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
```

## 🎛️ Advanced Control Examples

### 1. Environment-Based Deployment
```yaml
# kustomization.yaml
configMapGenerator:
  - name: deployment-config
    literals:
      - environment=production        # → Only production-grade apps
      - enable_monitoring=true        # → Enable monitoring stack
      - enable_development=false      # → Disable dev tools

resources:
  - controllers/argocd/              # ✅ Always enabled
  - monitoring/prometheus/           # ✅ Enabled by enable_monitoring=true
  - development/jupyter/             # ❌ Disabled by enable_development=false
```

### 2. Version-Based Filtering
```yaml
# kustomization.yaml
images:
  - name: grafana/grafana
    newTag: 10.0.0                   # ✅ Stable version → Deploy
  - name: prometheus/prometheus
    newTag: 2.45.0-beta              # ❌ Beta version → Skip in production

resources:
  - monitoring/grafana/              # ✅ Deployed (stable image)
  - monitoring/prometheus/           # ❌ Skipped (beta image)
```

### 3. Conditional Patches
```yaml
# kustomization.yaml
patches:
  - target:
      name: cert-manager
    patch: |-
      metadata:
        annotations:
          enabled: "false"           # ❌ Plugin disables cert-manager
          reason: "external-cert-manager-exists"

resources:
  - controllers/cert-manager/        # ❌ Disabled by patch logic
  - controllers/sealed-secrets/      # ✅ Enabled normally
```

### 4. Dependency Management
```yaml
# kustomization.yaml
configMapGenerator:
  - name: dependencies
    literals:
      - cilium.required=true         # Cilium must be ready first
      - storage.required=true        # Storage must be ready before apps

# Plugin logic ensures:
# 1. Cilium deploys first (sync-wave: -10)
# 2. Storage deploys after Cilium (sync-wave: 0)
# 3. Applications deploy after storage (sync-wave: 10)
```

## 🏢 Netflix-Style Benefits

### 1. **Intelligent Deployment Logic**
- Environment-aware deployments
- Version compatibility checking
- Dependency management
- Resource availability checking

### 2. **Enterprise Features**
- Canary deployment support
- Blue-green deployment logic
- Multi-cluster awareness
- Cost optimization (disable expensive apps in dev)

### 3. **Advanced GitOps**
- Complex conditional logic
- Dynamic application generation
- Smart resource management
- Enterprise compliance checking

## ⚠️ Considerations

### Complexity
- Requires custom plugin development
- More debugging complexity
- Team training required

### Maintenance
- Plugin updates needed
- Custom logic maintenance
- ArgoCD version compatibility

### Alternative: Simpler Patterns
For most use cases, the **Gitiles Pattern** (Option 3) provides 95% of the benefits with much less complexity.

## 🎯 When to Use Netflix Style

✅ **Use when you have:**
- 50+ microservices
- Complex deployment requirements
- Multiple environments with different rules
- Enterprise compliance requirements
- Dedicated platform engineering team

❌ **Don't use when you have:**
- Simple infrastructure requirements
- Small team
- Prefer simplicity over advanced features
- Limited ArgoCD expertise

---

**Note**: This pattern is inspired by Netflix's actual deployment strategies but adapted for smaller scale implementations. For most homelab/startup scenarios, simpler patterns are recommended.
