# Istio Certification Exam Scenarios

This directory contains **all** Istio features tested in the CNCF Certified Istio Administrator exam.

## Exam Topics Coverage:

### 1. Traffic Management (25% of exam)
-  Canary Deployments (traffic splitting)
-  A/B Testing (header-based routing)
-  Traffic Mirroring (dark launch)
-  Retry Policies
-  Timeout Configuration
-  Circuit Breaking
-  Load Balancing strategies

### 2. Security (25% of exam)
-  mTLS (Strict mode)
-  AuthorizationPolicies (service-to-service RBAC)
-  RequestAuthentication (JWT validation)
-  PeerAuthentication modes

### 3. Observability (20% of exam)
-  Distributed Tracing (Jaeger)
-  Metrics (Prometheus + Grafana)
-  Service Graph (Kiali)
-  Access Logs

### 4. Troubleshooting (15% of exam)
-  `istioctl analyze`
-  Envoy config dump
-  Proxy logs
-  Debugging traffic issues

### 5. Architecture & Installation (15% of exam)
-  Ambient vs Sidecar mode
-  Control Plane components
-  Data Plane (ztunnel, waypoint)
-  Gateway configuration

## Files in this directory:

| File | Exam Topic | Weight |
|------|------------|--------|
| `canary-deployment.yaml` | Traffic splitting 90/10 | ⭐⭐⭐⭐⭐ |
| `ab-testing.yaml` | Header-based routing | ⭐⭐⭐⭐ |
| `traffic-mirroring.yaml` | Dark launch pattern | ⭐⭐⭐ |
| `retry-timeout.yaml` | Resilience patterns | ⭐⭐⭐⭐⭐ |
| `circuit-breaking.yaml` | Fault tolerance | ⭐⭐⭐⭐⭐ |
| `mtls-strict.yaml` | Zero-trust security | ⭐⭐⭐⭐⭐ |
| `authorization-jwt.yaml` | Request authentication | ⭐⭐⭐⭐ |
| `fault-injection.yaml` | Chaos engineering | ⭐⭐⭐ |

## Usage:

```bash
# Apply specific scenario
kubectl apply -f canary-deployment.yaml

# Test with traffic
kubectl exec -n boutique-dev deploy/frontend -- curl http://checkout-service:5050

# View in Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Open: http://localhost:20001
```
