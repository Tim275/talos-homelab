# Istio Production Configuration for Order Management Microservices

Production-ready Istio Service Mesh configuration with **mTLS, Multi-Tenant Isolation, Circuit Breakers, and Distributed Tracing**.

## 🎯 What This Provides

### ✅ Automatic mTLS (Zero-Config Security)
```bash
# ALL service-to-service communication is encrypted with mTLS
# No code changes needed in your microservices!
order-service → payment-service  (mTLS ✅)
payment-service → inventory-service  (mTLS ✅)
```

### ✅ Multi-Tenant Isolation
```bash
# Each tenant is 100% isolated
tenant-a-orders → tenant-b-orders  (BLOCKED ❌)
tenant-a-orders → tenant-a-payments  (ALLOWED ✅)
```

### ✅ Zero Trust Network (Default Deny)
```bash
# By default, NO service can talk to ANY other service
# You MUST explicitly allow communication with AuthorizationPolicies
```

### ✅ Production Resilience
- **Circuit Breakers**: Prevent cascading failures
- **Automatic Retries**: Transient failures are retried
- **Timeouts**: Prevent hanging requests
- **Load Balancing**: LEAST_REQUEST algorithm

### ✅ Distributed Tracing (Jaeger Integration)
- 10% sampling for Order Management services
- Custom tags: `tenant`, `order_id`, `service_type`
- Full request flow visibility

## 🚀 How to Deploy Your Order Management Microservices

### Step 1: Create Your Namespace with Istio Injection

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: order-management
  labels:
    istio-injection: enabled  # ← This enables auto-sidecar injection!
    tenant: tenant-a
```

```bash
kubectl apply -f your-namespace.yaml
```

### Step 2: Deploy Your Microservices (Example)

```yaml
# order-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: order-management
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
      version: stable
  template:
    metadata:
      labels:
        app: order-service
        version: stable
    spec:
      serviceAccountName: order-service  # ← Required for mTLS identity!
      containers:
        - name: order-service
          image: your-registry/order-service:v1.0.0
          ports:
            - containerPort: 8080
              name: http
          env:
            # Your microservice talks to localhost:8080
            # Istio sidecar handles mTLS transparently!
            - name: PAYMENT_SERVICE_URL
              value: "http://payment-service:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: order-management
spec:
  selector:
    app: order-service
  ports:
    - port: 8080
      targetPort: 8080
      name: http  # ← Name is required for Istio protocol detection
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-service
  namespace: order-management
```

### Step 3: Create Authorization Policies (Who Can Talk to Who)

```yaml
# allow-order-to-payment.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-order-to-payment
  namespace: order-management
spec:
  selector:
    matchLabels:
      app: payment-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/order-management/sa/order-service"]
      to:
        - operation:
            methods: ["POST", "GET"]
            paths: ["/api/v1/payments/*"]
```

### Step 4: Verify mTLS is Working

```bash
# Check that pods have Istio sidecar injected
kubectl get pods -n order-management
# You should see 2/2 READY (app + istio-proxy)

# Check mTLS status
kubectl exec -n order-management deploy/order-service -c istio-proxy -- \
  pilot-agent request GET stats | grep ssl.handshake

# Test service-to-service communication
kubectl exec -n order-management deploy/order-service -c order-service -- \
  curl http://payment-service:8080/health
# This request is automatically encrypted with mTLS!
```

### Step 5: View Distributed Tracing in Jaeger

```bash
# Access Jaeger UI
kubectl port-forward -n jaeger svc/jaeger-query 16686:16686

# Open: http://localhost:16686
# Search for service: order-service
# You'll see the full request flow: order → payment → inventory
```

## 🔒 mTLS Certificate Management

Istio **automatically** handles all certificates:

```
✅ Certificate Generation: Automatic
✅ Certificate Rotation: Every 24 hours (automatic)
✅ Root CA: Managed by Istiod
✅ Service Identity: Based on ServiceAccount
✅ Certificate Storage: Kubernetes Secrets (per-pod)
```

**You don't need to do ANYTHING!** Just label your namespace with `istio-injection: enabled`.

## 🎨 Example: Full Order Management Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Tenant A - Order Management (Namespace: tenant-a-orders)│
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  mTLS   ┌──────────────┐  mTLS       │
│  │ order-service│ ──────→ │payment-service│ ────┐       │
│  └──────────────┘         └──────────────┘      │       │
│         │                                        │       │
│         │ mTLS                          mTLS     ↓       │
│         ↓                              ┌─────────────┐   │
│  ┌──────────────┐                     │inventory-svc│   │
│  │ notify-service│                    └─────────────┘   │
│  └──────────────┘                                        │
│                                                           │
│  All communication: mTLS encrypted ✅                    │
│  Authorization: Explicit allow policies ✅               │
│  Tracing: Jaeger (10% sampling) ✅                       │
│  Circuit Breaker: Enabled ✅                             │
└─────────────────────────────────────────────────────────┘
```

## 📊 Production Features Included

| Feature | Status | Configuration File |
|---------|--------|-------------------|
| **Strict mTLS** | ✅ | `peerauthentication-strict-mtls.yaml` |
| **Zero Trust (Default Deny)** | ✅ | `authorizationpolicy-default-deny.yaml` |
| **Multi-Tenant Isolation** | ✅ | `multi-tenant-isolation.yaml` |
| **Circuit Breaker** | ✅ | `destinationrule-circuit-breaker.yaml` |
| **Automatic Retries** | ✅ | `virtualservice-retry-timeout.yaml` |
| **Canary Deployments** | ✅ | `virtualservice-retry-timeout.yaml` |
| **Distributed Tracing (Jaeger)** | ✅ | `observability-telemetry.yaml` |
| **Prometheus Metrics** | ✅ | `observability-telemetry.yaml` |
| **Load Balancing (LEAST_REQUEST)** | ✅ | `destinationrule-circuit-breaker.yaml` |

## 🔧 Customization

### Change mTLS Sampling Rate
Edit `observability-telemetry.yaml`:
```yaml
randomSamplingPercentage: 10.0  # 10% = balance between cost and visibility
```

### Add New Tenant
Copy `tenant-a-orders` section in `multi-tenant-isolation.yaml` and rename to your tenant.

### Adjust Circuit Breaker
Edit `destinationrule-circuit-breaker.yaml`:
```yaml
consecutive5xxErrors: 5  # Lower = more aggressive
baseEjectionTime: 30s    # How long to eject unhealthy pods
```

## 🚨 Common Issues

### Pods stuck in Init:0/1
**Cause**: Istio sidecar not injecting
```bash
# Check namespace label
kubectl get namespace order-management -o yaml | grep istio-injection
# Should show: istio-injection: enabled

# If missing, add label:
kubectl label namespace order-management istio-injection=enabled

# Restart pods to inject sidecar
kubectl rollout restart deployment -n order-management
```

### Service returns 403 (RBAC: access denied)
**Cause**: Missing AuthorizationPolicy
```bash
# Check if default-deny is blocking traffic
kubectl get authorizationpolicy -A

# Create explicit allow policy (see Step 3 above)
```

### mTLS handshake failures
**Cause**: Clock skew or certificate issues
```bash
# Check Istiod logs
kubectl logs -n istio-system -l app=istiod --tail=100

# Verify mTLS config
kubectl get peerauthentication -A
```

## 📚 Next Steps

1. ✅ Deploy this configuration: `kubectl apply -k .`
2. ✅ Create your `order-management` namespace with `istio-injection: enabled`
3. ✅ Deploy your microservices (see Step 2)
4. ✅ Create AuthorizationPolicies for service-to-service communication
5. ✅ Test mTLS: `kubectl exec ... curl http://other-service`
6. ✅ View traces in Jaeger UI

## 🎓 Learn More

- [Istio Security Best Practices](https://istio.io/latest/docs/ops/best-practices/security/)
- [Authorization Policy Examples](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
- [Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
