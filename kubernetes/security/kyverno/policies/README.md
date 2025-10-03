# 🛡️ Kyverno Policies

**Policy Engine**: Kyverno v3.5.2
**Mode**: Audit (change to Enforce when ready)
**Coverage**: Pod Security Standards (PSS) Restricted Profile

---

## 📋 DEPLOYED POLICIES

### **1. require-non-root.yaml** 🔐
**Category**: Pod Security Standards (Restricted)
**Severity**: Medium

**What it does**:
- Ensures containers run as non-root user
- Validates `runAsNonRoot: true` in securityContext

**Example failure**:
```yaml
# ❌ BAD
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    # Missing runAsNonRoot!

# ✅ GOOD
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: nginx
    image: nginx:1.21
    securityContext:
      runAsNonRoot: true
```

---

### **2. require-resource-limits.yaml** 📊
**Category**: Best Practices
**Severity**: Medium

**What it does**:
- Requires CPU and memory limits for all containers
- Prevents resource exhaustion

**Example failure**:
```yaml
# ❌ BAD
spec:
  containers:
  - name: app
    image: myapp:1.0
    # Missing resource limits!

# ✅ GOOD
spec:
  containers:
  - name: app
    image: myapp:1.0
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

---

### **3. disallow-latest-tag.yaml** 🏷️
**Category**: Best Practices
**Severity**: Medium

**What it does**:
- Prevents use of `:latest` image tag
- Ensures reproducible deployments

**Example failure**:
```yaml
# ❌ BAD
spec:
  containers:
  - name: app
    image: myapp:latest  # ❌ Not allowed!

# ✅ GOOD
spec:
  containers:
  - name: app
    image: myapp:1.2.3  # ✅ Specific version
```

---

### **4. drop-all-capabilities.yaml** 🔒
**Category**: Pod Security Standards (Restricted)
**Severity**: Medium

**What it does**:
- Requires dropping ALL Linux capabilities
- Only add back specific capabilities if needed

**Example failure**:
```yaml
# ❌ BAD
spec:
  containers:
  - name: app
    image: myapp:1.0
    # Missing capabilities drop!

# ✅ GOOD
spec:
  containers:
  - name: app
    image: myapp:1.0
    securityContext:
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE  # Only if needed!
```

---

## 🎯 USAGE

### **Check Policy Violations**
```bash
# Get policy reports for all namespaces
kubectl get polr -A

# Get cluster-wide policy reports
kubectl get cpolr

# Describe specific policy report
kubectl describe polr <name> -n <namespace>
```

### **Change to Enforce Mode**
When ready to enforce (after fixing violations), edit each policy:
```yaml
spec:
  validationFailureAction: Enforce  # Changed from Audit
```

### **Exclude Namespaces**
Already excluded in Kyverno values.yaml:
- kube-system
- kube-public
- kube-node-lease
- argocd

---

## 📊 POLICY REPORTS

Kyverno generates two types of reports:

**PolicyReport** (namespace-scoped):
```bash
kubectl get polr -n boutique-dev
```

**ClusterPolicyReport** (cluster-wide):
```bash
kubectl get cpolr
```

Example report:
```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-ns-boutique-dev
  namespace: boutique-dev
summary:
  pass: 15
  fail: 3
  warn: 0
  error: 0
  skip: 2
results:
- policy: require-resource-limits
  rule: check-resource-limits
  result: fail
  message: "Resource limits are required for all containers"
  resources:
  - kind: Pod
    name: frontend-abc123
    namespace: boutique-dev
```

---

## 🚀 NEXT STEPS

### **Phase 1: Audit Mode** (Current)
- ✅ Policies deployed in Audit mode
- ⏳ Monitor violations via PolicyReports
- ⏳ Fix violations in workloads

### **Phase 2: Enforce Mode**
- Change `validationFailureAction: Enforce`
- Block non-compliant deployments
- Monitor blocked deployments

### **Phase 3: Additional Policies**
- Add more PSS policies (seccomp, AppArmor)
- Add image signature validation (Cosign)
- Add supply chain policies

---

## 📚 RESOURCES

- **Kyverno Docs**: https://kyverno.io/docs/
- **Policy Library**: https://kyverno.io/policies/
- **PSS Policies**: https://kyverno.io/policies/pod-security/
- **Best Practices**: https://kyverno.io/policies/best-practices/

---

**Status**: 📝 Policies created, not yet deployed (waiting for Kyverno installation)
**Mode**: Audit only (no blocking yet)
**Next Action**: Deploy Kyverno, then apply policies
