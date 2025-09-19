# Apps Structure Proposal

## Current Problems
- Overlays pattern creates confusion (base + overlays directories)
- ApplicationSets point to wrong paths
- Mix of patterns (some apps use base/overlays, others don't)
- Redundant demo apps (book-info, trading with only README)

## Proposed Clean Structure

```
kubernetes/
├── apps/                       # User-facing applications
│   ├── audiobookshelf/
│   │   ├── base/              # Shared base configuration
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   ├── environments/       # Environment-specific configs
│   │   │   ├── dev/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── patches.yaml
│   │   │   └── production/
│   │   │       ├── kustomization.yaml
│   │   │       └── patches.yaml
│   │   └── applicationset.yaml # Manages this app across environments
│   │
│   ├── n8n/                    # Same structure for each app
│   │   ├── base/
│   │   ├── environments/
│   │   └── applicationset.yaml
│   │
│   └── applicationsets.yaml    # Root ApplicationSet to discover apps
│
├── platform/                   # Platform services (Kafka, DBs, etc)
│   └── ...
│
└── infra/                     # Infrastructure (monitoring, networking)
    └── ...
```

## Benefits
1. **Clear separation**: Each app is self-contained
2. **Consistent pattern**: All apps follow same structure
3. **Easy discovery**: ApplicationSets automatically find apps
4. **Environment management**: Clear dev/production separation
5. **No conflicts**: Each app manages its own resources

## Migration Steps
1. Move `base/audiobookshelf` → `apps/audiobookshelf/base/`
2. Move `overlays/dev/audiobookshelf` → `apps/audiobookshelf/environments/dev/`
3. Create ApplicationSet per app
4. Remove redundant directories (book-info, trading)
5. Clean up quant apps (decide if production-ready)