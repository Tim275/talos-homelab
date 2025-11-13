# Kyverno vs Native Kubernetes Admission Webhooks

## Overview

This document compares Kyverno (declarative policy engine) with native Kubernetes admission webhooks for policy enforcement in production clusters.

---

## Native Kubernetes Admission Webhooks (Without Kyverno)

### What You Need to Build Yourself

```yaml
# Example: ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: custom-webhook
webhooks:
  - name: validate.example.com
    clientConfig:
      service:
        name: webhook-service
        namespace: webhooks
        path: "/validate"
      caBundle: <base64-encoded-CA-cert>
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
```

### Required Components

1. **Webhook Server Implementation** (Go/Python/Node.js)
   - HTTP server with TLS
   - AdmissionReview request/response handling
   - Business logic for validation/mutation

2. **TLS Certificate Management**
   - Generate certificates (cert-manager integration)
   - Certificate rotation
   - CA bundle management

3. **Policy Logic**
   - Write all validation rules in code
   - Implement mutation patches manually
   - Handle all edge cases

4. **Operational Concerns**
   - Error handling and retries
   - Logging and debugging
   - Metrics and monitoring (Prometheus)
   - High availability deployment

---

## Kyverno (Declarative Policy Engine)

### Simple YAML-Based Approach

```yaml
# Same functionality - Pure YAML, no code
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-privileged
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: false
```

### What Kyverno Provides Out-of-the-Box

- **Webhook Server**: Built-in, production-ready
- **TLS Management**: Automatic certificate generation and rotation
- **Policy Engine**: Declarative YAML syntax
- **Error Handling**: Built-in retry and failure modes
- **Metrics**: Prometheus metrics exposed automatically
- **Testing**: `kyverno test` CLI command
- **Reporting**: PolicyReport CRDs for audit
- **Exceptions**: PolicyException CRD for exemptions

---

## Feature Comparison

| Feature | Native Webhooks | Kyverno |
|---------|----------------|---------|
| **Development** | Go/Python/Node.js code | Pure YAML |
| **Deployment** | Custom Helm chart + Service | `helm install kyverno` |
| **TLS Management** | Manual cert-manager setup | Auto-managed |
| **Policy Updates** | Code → Build → Test → Deploy | `kubectl apply -f policy.yaml` |
| **Testing** | Custom test framework | `kyverno test` CLI |
| **Reporting** | Custom logging/metrics | PolicyReport CRDs |
| **Mutations** | JSON Patch in code (100+ lines) | YAML patch (5-10 lines) |
| **Exceptions** | Hard-coded in logic | PolicyException CRD |
| **Audit Mode** | Self-implement | Built-in `Audit` mode |
| **Dry-Run** | Custom implementation | Built-in `--dry-run` |
| **Time to Production** | Weeks/Months | Hours |
| **Maintenance** | Code + Dependencies + Tests | YAML files only |

---

## Practical Example: Mutation

### Native Webhook Implementation (Go)

```go
package main

import (
    "encoding/json"
    "net/http"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/api/admission/v1"
)

func mutatePod(pod *corev1.Pod) []map[string]interface{} {
    var patches []map[string]interface{}

    // Add runAsNonRoot if missing
    if pod.Spec.SecurityContext == nil {
        patches = append(patches, map[string]interface{}{
            "op":    "add",
            "path":  "/spec/securityContext",
            "value": map[string]interface{}{},
        })
    }

    if pod.Spec.SecurityContext.RunAsNonRoot == nil {
        patches = append(patches, map[string]interface{}{
            "op":    "add",
            "path":  "/spec/securityContext/runAsNonRoot",
            "value": true,
        })
    }

    // 50+ more lines for container-level mutations...
    return patches
}

func serveMutate(w http.ResponseWriter, r *http.Request) {
    // Decode AdmissionReview
    // Validate request
    // Apply mutations
    // Encode response
    // Handle errors
    // ... 200+ lines of boilerplate ...
}

func main() {
    http.HandleFunc("/mutate", serveMutate)
    // TLS setup, cert loading, server config...
    // ... 100+ lines ...
}
```

**Total: ~500 lines of Go code + tests + deployment manifests**

---

### Kyverno Implementation (YAML)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-runasnonroot
spec:
  rules:
    - name: add-runasnonroot
      match:
        any:
          - resources:
              kinds: [Pod]
      mutate:
        patchStrategicMerge:
          spec:
            securityContext:
              runAsNonRoot: true
```

**Total: 15 lines of YAML**

---

## When to Use Native Webhooks

Use native Kubernetes admission webhooks **ONLY** when:

1. **Complex External Integrations**
   - Need to call external APIs (billing, CMDB, etc.)
   - Complex business logic that can't be expressed declaratively

2. **Extreme Performance Requirements**
   - Sub-millisecond latency critical
   - Processing millions of requests/second

3. **Custom Protocol Requirements**
   - Non-standard authentication mechanisms
   - Custom serialization formats

**For 99% of use cases: Kyverno is the better choice!**

---

## Production Deployment Comparison

### Native Webhook Deployment Steps

1. Write webhook server code (Go/Python)
2. Write unit tests
3. Write integration tests
4. Build container image
5. Push to registry
6. Create Helm chart (Deployment, Service, RBAC)
7. Setup cert-manager for TLS
8. Create ValidatingWebhookConfiguration
9. Create MutatingWebhookConfiguration
10. Deploy and monitor
11. **Repeat 1-10 for every policy update**

**Time: 2-4 weeks for first policy, 1-2 days per update**

---

### Kyverno Deployment Steps

1. `helm install kyverno kyverno/kyverno`
2. Write policy YAML
3. `kubectl apply -f policy.yaml`

**Time: 1 hour for setup, 5 minutes per policy**

---

## Kyverno Advantages Summary

- **No Code Required**: Pure declarative YAML
- **Instant Updates**: kubectl apply (no build/deploy cycle)
- **Built-in Testing**: `kyverno test` command
- **Audit Mode**: Non-blocking policy testing
- **Policy Reports**: Automated compliance reporting
- **Exceptions**: Easy exemption management
- **Community Policies**: 200+ pre-built policies available
- **GitOps Ready**: Native ArgoCD/FluxCD support
- **Low Maintenance**: No code dependencies to update

---

## Conclusion

**Kyverno is the recommended solution for:**
- Pod Security Standards enforcement
- Resource management policies
- Best practices enforcement
- Image validation
- Label requirements
- Network policy generation
- Security context mutations

**Native webhooks are only needed for:**
- Complex business logic with external systems
- Custom protocols or extreme performance requirements

For production Kubernetes clusters, **Kyverno provides enterprise-grade policy enforcement with minimal operational overhead**.
