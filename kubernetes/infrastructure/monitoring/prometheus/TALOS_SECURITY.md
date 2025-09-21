# 🔒 Talos Linux Security Requirements for Prometheus Monitoring

## Problem Statement

Talos Linux enforces **Pod Security Standards** by default:
- **baseline** profile on all namespaces (except kube-system)
- **privileged** profile only on kube-system namespace

However, **Prometheus Node Exporter requires privileged access** to collect host-level metrics.

## Why Node Exporter Needs Privileged Access

**CRITICAL FOR TALOS LINUX VMs**: Talos Linux has an immutable, security-hardened OS design.
Without privileged access, Node Exporter cannot export ANY metrics from Talos nodes!

Node Exporter **must** access host resources to collect metrics:

```yaml
# These are unavoidable requirements:
hostNetwork: true    # Network statistics from host interface
hostPID: true        # Process metrics from host PID namespace
hostPath:           # Host filesystem access for metrics
  - /proc           # Process and system information
  - /sys            # System and kernel parameters
  - /              # Root filesystem metrics
```

## PodSecurity Violations

Without privileged namespace, Node Exporter fails with:

```
Error creating pod: violates PodSecurity "baseline:latest":
- host namespaces (hostNetwork=true, hostPID=true)
- hostPath volumes (volumes "proc", "sys", "root")
- hostPort (container "node-exporter" uses hostPort 9100)
```

## Solution: Infrastructure as Code

### 1. Namespace Configuration (Automated)

Our `ns.yaml` includes the required labels:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    # Required for node-exporter to run with hostNetwork, hostPID, hostPath
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

### 2. Manual Patch (If Namespace Exists)

If the namespace already exists without these labels:

```bash
kubectl patch namespace monitoring --patch '{
  "metadata": {
    "labels": {
      "pod-security.kubernetes.io/enforce": "privileged",
      "pod-security.kubernetes.io/audit": "privileged",
      "pod-security.kubernetes.io/warn": "privileged"
    }
  }
}'
```

### 3. Restart DaemonSet

After namespace update, restart the node-exporter:

```bash
kubectl rollout restart daemonset prometheus-operator-prometheus-node-exporter -n monitoring
```

## Security Considerations

### ✅ This is Standard Practice

- **Google GKE**: Uses privileged monitoring namespaces
- **AWS EKS**: Same approach for system monitoring
- **Azure AKS**: Standard for cluster monitoring
- **Enterprise Kubernetes**: Industry best practice

### ✅ Risk Mitigation

1. **Namespace Isolation**: Only monitoring namespace is privileged
2. **RBAC Controls**: Service accounts have minimal permissions
3. **Network Policies**: Can restrict inter-namespace communication
4. **Container Security**: Node-exporter runs read-only where possible

### ❌ Alternative Approaches (Not Viable)

- **SecurityContext hardening**: Breaks host metric collection
- **Sidecar pattern**: Host metrics unavailable from containers
- **Remote monitoring**: Defeats purpose of cluster monitoring
- **Disable node-exporter**: Loses critical node-level insights

## Verification

Check that Node Exporter pods are running:

```bash
kubectl get pods -n monitoring | grep node-exporter
# Should show Running status for all nodes
```

## References

- [Talos Pod Security Documentation](https://www.talos.dev/v1.10/kubernetes-guides/configuration/pod-security/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Prometheus Node Exporter Documentation](https://prometheus.io/docs/guides/node-exporter/)

---

**⚠️ Important**: This privileged access is **unavoidable** for proper node monitoring and follows **industry best practices** for Kubernetes monitoring stacks.