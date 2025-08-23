# Kubernetes Overlays System

This overlay system provides granular control over your homelab infrastructure components, inspired by modern GitOps practices.

## Quick Start - Enable/Disable Components

Edit `toggles.yaml` to control what gets deployed:

```yaml
monitoring:
  grafana: enabled        # ← Change to 'disabled' to turn off
  loki: disabled          # ← Change to 'enabled' to turn on
```

## Structure

```
overlays/
├── components/          # Individual component overlays
│   ├── infrastructure/ 
│   │   ├── monitoring/  # grafana, loki, jaeger, prometheus
│   │   └── storage/     # longhorn, rook-ceph, proxmox-csi
│   └── platform/
│       └── data/        # cloudnative-pg, mongodb, kafka, redis
├── profiles/           # Pre-configured component bundles
│   ├── homelab/        # Homelab-optimized settings
│   ├── minimal/        # Minimal footprint
│   └── enterprise/     # Full-featured
├── environments/       # Complete environment configs
│   ├── development/    
│   ├── staging/        
│   └── production/     
└── toggles.yaml       # Central component control
```

## Usage Examples

### Disable Resource-Intensive Components
```bash
# Edit toggles.yaml
monitoring:
  loki: disabled        # Saves 2GB+ memory
  jaeger: disabled      # Saves 1GB+ memory

# Commit and push - ArgoCD auto-syncs
git commit -am "disable loki and jaeger to save resources"
git push
```

### Enable Data Platform
```bash
# Edit toggles.yaml  
data:
  cloudnative-pg: enabled   # PostgreSQL operator
  mongodb: enabled          # MongoDB operator

# Apply changes
git commit -am "enable data platforms"
git push
```

### Switch Profiles
```bash
# Use minimal profile for testing
kustomize build overlays/profiles/minimal

# Use enterprise profile for production  
kustomize build overlays/profiles/enterprise
```

## Component Resource Usage

| Component | CPU | Memory | Storage | Notes |
|-----------|-----|--------|---------|--------|
| **HIGH USAGE** |
| jaeger | 1-2 cores | 2-4GB | 10GB+ | Distributed tracing |
| loki | 0.5-1 core | 1-2GB | 50GB+ | Log retention |
| rook-ceph | 2-4 cores | 4-8GB | Raw disks | Advanced storage |
| **MEDIUM USAGE** |
| grafana | 0.2-0.5 core | 500MB-1GB | 5GB | Dashboards |
| longhorn | 0.5-1 core | 1-2GB | Host storage | Simple storage |
| **LOW USAGE** |
| prometheus | 0.5 core | 1GB | 20GB | Core metrics |
| cert-manager | 0.1 core | 100MB | - | SSL certificates |

## Advanced Usage

### Custom Component Overlay
```yaml
# overlays/components/custom/my-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../../infra/my-app

patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1  # Homelab-optimized
```

### Environment-Specific Overrides
```yaml
# overlays/environments/production/kustomization.yaml
resources:
  - ../../profiles/enterprise

patches:
  - target:
      kind: Application
      labelSelector: "component=grafana"
    patch: |-
      - op: replace
        path: /spec/source/helm/values
        value:
          resources:
            requests:
              cpu: "1"
              memory: "2Gi"
```

## Troubleshooting

### Application Won't Sync
```bash
# Check application status
kubectl get applications -n argocd

# Force sync specific application
kubectl patch application <app-name> -n argocd \
  --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Resource Constraints
1. Check `toggles.yaml` - disable non-essential components
2. Use `profiles/minimal` for resource-constrained environments
3. Monitor resource usage: `kubectl top nodes`

### Component Dependencies
Some components depend on others:
- `grafana` requires `prometheus`
- `loki` needs persistent storage
- `jaeger` requires `opentelemetry-operator`

Check component kustomization files for requirements.