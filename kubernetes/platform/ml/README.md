# ML Platform

**Status: Phase 1 LIVE (MLflow).** Deployed über die `ml-stack` AppSet (project `ml`,
manual-sync/DAX-Gate). GPU-gebundene Tools (Training-Workloads) warten weiter auf Hardware.

## Das Zwei-Hälften-Muster

| Hälfte | Pfad | Inhalt | Status |
|--------|------|--------|--------|
| Workspace | `kubernetes/tenants/ml/` | Namespace, Quota, LimitRange, RBAC | ✅ live (PR #508) |
| Tools (dieser Ordner) | `kubernetes/platform/ml/` + `infrastructure/operators/` | MLflow, KServe, Argo Workflows | ⏸️ geparkt |

Analog zum Rest des Repos: Strimzi-Operator (`infrastructure/operators/strimzi/`)
↔ drovas Kafka (`tenants/drova/kafka/`), CNPG-Operator ↔ n8ns Postgres.

## Geplanter Stack (CPU-first, siehe notes/CLAUDE-MLOPS.md)

```
platform/ml/mlflow/                      → ✅ LIVE: Tracking+Registry, sqlite auf Ceph-PVC,
                                           Artefakte → Ceph-RGW S3 (OBC mlflow-artifacts),
                                           https://mlflow.timourhomelab.org (VPN-only)
infrastructure/operators/kserve/         → ⏸️ kommt mit dem ERSTEN Modell (keine leere Hülle)
infrastructure/operators/argo-workflows/ → ⏸️ kommt mit der ERSTEN Pipeline
```

**Bewusst KEIN Full-Kubeflow:** 10+ Komponenten, RAM-Fresser, eigener Istio-Zwang —
MLflow + KServe + Argo Workflows liefern dieselben Capabilities modular und leicht.

## Aktivierung (wenn Hardware da)

1. GPU-Node in tofu/tfvars aktivieren (FUTURE-NODES-Block, worker-6-ai)
2. Operator-Ordner hier + in `infrastructure/operators/` anlegen (base + overlays/prod)
3. In controllers-stack bzw. identity-stack-Muster als AppSet-Elemente verdrahten
4. GPU-Quota in `tenants/ml/resourcequota.yaml` einkommentieren
