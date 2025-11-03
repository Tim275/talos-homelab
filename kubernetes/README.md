# Kubernetes Homelab

## Bootstrap

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

kubectl apply -k bootstrap/
kubectl get applications -n argocd -w
```

## ArgoCD

```bash
# Password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# UI
kubectl port-forward svc/argocd-server -n argocd 8080:80
# http://localhost:8080
```

## Infrastructure

**Layer 1 - Security (Wave 0)**
- Sealed Secrets
- Cert Manager
- Kyverno

**Layer 2 - Foundation (Wave 1-6)**
- Cilium CNI
- Rook Ceph Storage
- Istio Service Mesh
- PostgreSQL Operator (CNPG)

**Layer 3 - Observability (Wave 6-10)**
- Prometheus + Grafana
- Jaeger Tracing
- Alertmanager
- Elasticsearch + Kibana
- Velero Backups

**Layer 4 - Platform (Wave 15-18)**
- Authelia (SSO)
- Keycloak (Identity)
- LLDAP (LDAP)
- Kafka
- N8N Workflows
- Infisical Secrets

## Useful Commands

```bash
# Application status
kubectl get applications -n argocd

# Sync application
kubectl patch application <app> -n argocd --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'

# Check all pods
kubectl get pods -A

# Logs
kubectl logs -n <namespace> <pod>
```
