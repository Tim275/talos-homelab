# ML Platform — GEPARKT (wartet auf Hardware)

**Status: Platzhalter, deployt NICHTS.** Dieser Ordner ist von keiner kustomization und
keinem AppSet referenziert — er dokumentiert nur, wo die ML-Platform-Tools hinkommen,
sobald neue Hardware (GPU-Node) da ist.

## Das Zwei-Hälften-Muster

| Hälfte | Pfad | Inhalt | Status |
|--------|------|--------|--------|
| Workspace | `kubernetes/tenants/ml/` | Namespace, Quota, LimitRange, RBAC | ✅ live (PR #508) |
| Tools (dieser Ordner) | `kubernetes/platform/ml/` + `infrastructure/operators/` | MLflow, KServe, Argo Workflows | ⏸️ geparkt |

Analog zum Rest des Repos: Strimzi-Operator (`infrastructure/operators/strimzi/`)
↔ drovas Kafka (`tenants/drova/kafka/`), CNPG-Operator ↔ n8ns Postgres.

## Geplanter Stack (CPU-first, siehe notes/CLAUDE-MLOPS.md)

```
platform/ml/mlflow/                      → Experiment-Tracking (zentraler Server)
infrastructure/operators/kserve/         → Model-Serving-Operator
infrastructure/operators/argo-workflows/ → Pipeline-Engine
```

**Bewusst KEIN Full-Kubeflow:** 10+ Komponenten, RAM-Fresser, eigener Istio-Zwang —
MLflow + KServe + Argo Workflows liefern dieselben Capabilities modular und leicht.

## Aktivierung (wenn Hardware da)

1. GPU-Node in tofu/tfvars aktivieren (FUTURE-NODES-Block, worker-6-ai)
2. Operator-Ordner hier + in `infrastructure/operators/` anlegen (base + overlays/prod)
3. In controllers-stack bzw. identity-stack-Muster als AppSet-Elemente verdrahten
4. GPU-Quota in `tenants/ml/resourcequota.yaml` einkommentieren
