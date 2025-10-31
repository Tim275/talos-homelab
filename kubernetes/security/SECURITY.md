# 🛡️ KUBERNETES SECURITY - KUBE-BENCH vs KUBESCAPE

**Last Updated**: 2025-10-03
**Cluster**: Talos Homelab (7 nodes)
**Goal**: 100% CIS Kubernetes Benchmark Compliance

---

## 🔍 **THE DIFFERENCE: KUBE-BENCH vs KUBESCAPE**

### **📋 KUBE-BENCH (Aqua Security)**

**What it scans:**
- ✅ **Node-Level Security** (Worker + Control Plane Nodes)
- ✅ **Cluster Infrastructure** (kubelet, API server, etcd, scheduler)
- ✅ **Host OS Configuration** (file permissions, process configs)
- ✅ **CIS Benchmark Only** (CIS Kubernetes Benchmark)

**How it works:**
1. Runs as **Job/DaemonSet** on EVERY node
2. Checks **system-level** configs (SSH into nodes, checks files)
3. Output: PASS/FAIL for each CIS control

**Example checks:**
- Is API server started with `--anonymous-auth=false`?
- Are etcd data files with correct permissions (0600)?
- Does kubelet run with `--protect-kernel-defaults=true`?

**What it CANNOT do:**
- ❌ Scan Kubernetes YAML manifests
- ❌ Check Pod/Deployment configs
- ❌ Other frameworks (NSA, MITRE)
- ❌ Real-time monitoring

---

### **🎯 KUBESCAPE (ARMO Security / CNCF Sandbox)**

**What it scans:**
- ✅ **Kubernetes Resources** (Pods, Deployments, Services)
- ✅ **YAML Manifests** (even before deployment!)
- ✅ **Helm Charts**
- ✅ **CI/CD Pipelines**
- ✅ **Multiple Frameworks** (CIS + NSA + MITRE ATT&CK + more)

**How it works:**
1. Runs **in-cluster** or as **CLI tool**
2. Analyzes **Kubernetes API** objects
3. Provides **risk score** (0-100) for cluster
4. Shows **exact YAML line** that's broken!

**Example checks:**
- Pod running as root? (securityContext.runAsNonRoot)
- Container has no resource limits?
- Privileged container without reason?
- ServiceAccount has too many permissions?

**What it CAN do:**
- ✅ Real-time monitoring (Kubescape Operator)
- ✅ Prometheus integration
- ✅ Compliance reports (JSON, HTML, PDF)
- ✅ Remediation suggestions

---

## 🤝 **HOW THEY WORK TOGETHER**

### **COMPLEMENTARY USE (They complement each other!):**

```
┌─────────────────────────────────────────────────────┐
│         KUBERNETES CLUSTER SECURITY                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐   │
│  │   KUBE-BENCH     │      │   KUBESCAPE      │   │
│  │   (Node-Level)   │      │ (Workload-Level) │   │
│  └──────────────────┘      └──────────────────┘   │
│           │                          │             │
│           ▼                          ▼             │
│  ┌──────────────────┐      ┌──────────────────┐   │
│  │ Control Plane    │      │ Pods/Deployments │   │
│  │ - API Server     │      │ - securityContext│   │
│  │ - etcd           │      │ - resources      │   │
│  │ - scheduler      │      │ - RBAC           │   │
│  │                  │      │ - NetworkPolicy  │   │
│  │ Worker Nodes     │      │                  │   │
│  │ - kubelet        │      │ Helm Charts      │   │
│  │ - kube-proxy     │      │ - values.yaml    │   │
│  │ - file perms     │      │ - templates/     │   │
│  └──────────────────┘      └──────────────────┘   │
│                                                     │
│  CIS Kubernetes Benchmark Coverage: 100%           │
│  (Both tools cover different sections!)            │
└─────────────────────────────────────────────────────┘
```

---

## 📊 **COMPARISON TABLE**

| Feature | kube-bench | Kubescape |
|---------|------------|-----------|
| **Scan Target** | Nodes (infrastructure) | Workloads (applications) |
| **Frameworks** | CIS only | CIS + NSA + MITRE + more |
| **Deployment** | Job/CronJob | Operator (continuous) |
| **Real-time** | ❌ No | ✅ Yes |
| **YAML Scan** | ❌ No | ✅ Yes |
| **Helm Scan** | ❌ No | ✅ Yes |
| **CI/CD Integration** | Manual | ✅ Native |
| **Remediation** | Manual | ✅ Automated suggestions |
| **Prometheus** | Manual export | ✅ Native integration |
| **CNCF Status** | Community | Sandbox Project |
| **Best For** | Cluster hardening | Application security |

---

## 🎯 **PRACTICAL EXAMPLE**

### **Scenario**: You want 100% CIS Kubernetes Benchmark compliance

**kube-bench checks** (Sections 1-4 of CIS Benchmark):
```bash
[FAIL] 1.2.1 Ensure that the --anonymous-auth argument is set to false
[PASS] 1.2.2 Ensure that the --basic-auth-file argument is not set
[FAIL] 4.2.1 Ensure that the kubelet --anonymous-auth is set to false
[FAIL] 4.2.6 Ensure that the --protect-kernel-defaults is set to true
```
→ Shows you: **Cluster infrastructure is insecure!**

**Kubescape checks** (Section 5 of CIS Benchmark + more):
```bash
[FAIL] C-0017: Privileged container detected
  ├─ Pod: my-app (namespace: default)
  └─ Fix: Set securityContext.privileged: false at line 23

[FAIL] C-0046: Insecure capabilities detected
  ├─ Pod: nginx (namespace: prod)
  └─ Fix: Drop ALL capabilities, add only NET_BIND_SERVICE

[FAIL] C-0055: Container resource limits not set
  ├─ Deployment: frontend
  └─ Fix: Add resources.limits.memory at line 45
```
→ Shows you: **Your workloads are insecure!**

---

## 🚀 **DEPLOYMENT STRATEGY**

### **Option 1: DEPLOY BOTH (Best Practice!)** ✅

**Why both?**
- kube-bench = **Infrastructure hardening** (one-time + periodic scans)
- Kubescape = **Continuous security** (real-time monitoring)

**Workflow:**
```
1. Deploy kube-bench as CronJob (daily scan)
   ├─ Scan all nodes
   ├─ Export results to JSON
   └─ Send to Prometheus/Wazuh

2. Deploy Kubescape Operator (continuous)
   ├─ Watch all Kubernetes resources
   ├─ Scan on every deployment
   ├─ Alert on policy violations
   └─ Prometheus metrics

3. Integrate both into Wazuh SIEM
   ├─ kube-bench alerts → Wazuh (infrastructure issues)
   ├─ Kubescape alerts → Wazuh (workload issues)
   └─ Combined compliance dashboard
```

---

### **Option 2: Deploy only ONE (for homelab OK)**

**If only ONE:**
→ **Deploy Kubescape!** (better coverage + real-time)

**Why?**
- ✅ Scans **workloads** (more important than nodes for apps)
- ✅ Multiple frameworks (CIS + NSA + MITRE)
- ✅ Real-time monitoring (Operator mode)
- ✅ Better UX (shows exact broken YAML line!)

**Skip kube-bench when:**
- You use managed Kubernetes (EKS, GKE, AKS)
- Cloud provider manages the nodes (kube-bench checks don't apply)
- You have no SSH access to nodes

---

## 📋 **DEPLOYMENT PHASES**

### **Phase 1** (This Week):
- ⏳ Deploy **Kubescape Operator** (2 hours)
- ⏳ Run first scan, get security score
- ⏳ Fix critical findings

### **Phase 2** (Next Month):
- ⏳ Deploy **kube-bench CronJob** (1 hour)
- ⏳ Integrate both → Prometheus
- ⏳ Create Grafana dashboard

### **Phase 3** (Later):
- ⏳ Integrate both → **Wazuh SIEM**
- ⏳ Compliance reports (CIS, NSA, MITRE)
- ⏳ Automated remediation workflows

---

## 🎓 **CIS KUBERNETES BENCHMARK COVERAGE**

### **kube-bench covers** (Sections 1-4):
- **Section 1**: Control Plane Components
  - 1.1: API Server
  - 1.2: Scheduler
  - 1.3: Controller Manager
  - 1.4: etcd

- **Section 2**: etcd Configuration
  - 2.1: etcd security settings
  - 2.2: etcd data encryption

- **Section 3**: Control Plane Configuration
  - 3.1: Authentication and Authorization
  - 3.2: Logging

- **Section 4**: Worker Nodes
  - 4.1: Node Configuration Files
  - 4.2: kubelet settings

### **Kubescape covers** (Section 5 + more):
- **Section 5**: Policies
  - 5.1: RBAC and Service Accounts
  - 5.2: Pod Security Policies/Standards
  - 5.3: Network Policies
  - 5.4: Secrets Management
  - 5.5: Extensible Admission Control
  - 5.6: General Policies

- **Additional Frameworks**:
  - NSA/CISA Kubernetes Hardening Guide
  - MITRE ATT&CK Framework
  - Custom security policies

---

## 🛡️ **CURRENT STATUS**

### **Deployed:**
- ❌ kube-bench (not deployed)
- ❌ Kubescape (not deployed)

### **Security Tools Already Running:**
- ✅ Cilium CNI (L3/L4 network policies)
- ✅ Istio Service Mesh (mTLS, AuthZ)
- ✅ Sealed Secrets (encrypted secrets)
- ✅ Cert-Manager (TLS automation)
- ✅ Pod Security Standards (privileged/baseline/restricted)

### **Next Steps:**
1. Deploy Kubescape Operator
2. Run initial security scan
3. Get baseline security score
4. Fix critical/high findings
5. Deploy kube-bench CronJob
6. Integrate with monitoring stack

---

## 📚 **REFERENCES**

- **kube-bench**: https://github.com/aquasecurity/kube-bench
- **Kubescape**: https://github.com/kubescape/kubescape
- **CIS Kubernetes Benchmark**: https://www.cisecurity.org/benchmark/kubernetes
- **NSA Kubernetes Hardening Guide**: https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/
- **MITRE ATT&CK for Kubernetes**: https://attack.mitre.org/matrices/enterprise/containers/

---

## 🎯 **QUICK SUMMARY**

**TL;DR:**
- **kube-bench** = Scans **NODES** (kubelet, API server, etcd configs)
- **Kubescape** = Scans **WORKLOADS** (Pods, Deployments, Helm charts)
- **Together** = 100% CIS Kubernetes Benchmark coverage!
- **Recommendation**: Deploy both! Kubescape first (more important), kube-bench later.

**Security Score Impact:**
- Current security maturity: **40%** (without these tools)
- After Kubescape: **60%** (+20% workload security)
- After kube-bench: **70%** (+10% infrastructure hardening)
- After Falco + Trivy + Kyverno + Wazuh: **85%+** (complete security stack)

---

**Status**: 📝 Documentation only - tools not yet deployed
**Next Action**: Deploy Kubescape Operator to get first security baseline
