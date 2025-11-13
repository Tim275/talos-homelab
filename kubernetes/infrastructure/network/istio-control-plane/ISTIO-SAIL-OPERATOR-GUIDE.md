# Istio Service Mesh + Sail Operator - Enterprise Production Guide

**Version:** Istio v1.27.1 | Sail Operator v0.1.x
**Cluster:** Talos Homelab Production
**Date:** October 2025

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Why Istio Service Mesh?](#why-istio-service-mesh)
3. [Sail Operator vs Traditional Deployment](#sail-operator-vs-traditional-deployment)
4. [Architecture Overview](#architecture-overview)
5. [Enterprise Features](#enterprise-features)
6. [Zero-Downtime Upgrades](#zero-downtime-upgrades)
7. [Security: mTLS & PeerAuthentication](#security-mtls--peerauthentication)
8. [High Availability](#high-availability)
9. [Performance & Observability](#performance--observability)
10. [Best Practices](#best-practices)
11. [Production Checklist](#production-checklist)

---

## Executive Summary

**What is Istio?**
Istio is a **service mesh** that provides traffic management, security (mTLS), and observability for microservices without changing application code.

**What is Sail Operator?**
Sail Operator is the **next-generation Istio lifecycle manager** that replaces Helm and IstioOperator with a declarative Kubernetes-native CR.

**Why This Matters:**
- ✅ **Zero-downtime upgrades** via RevisionBased strategy
- ✅ **Declarative GitOps** with single Istio CR (no Helm complexity)
- ✅ **Production-ready HA** with HPA autoscaling
- ✅ **Built-in mTLS** for zero-trust security
- ✅ **1% trace sampling** (99% less overhead vs default)

**Current Production Configuration:**
```yaml
Istio Version: v1.27.1
Control Plane Replicas: 3 (HA)
Trace Sampling: 1% (production)
Global mTLS: STRICT (enforced)
Proxy Memory Limit: 512Mi (OOMKill prevention)
Update Strategy: RevisionBased (canary)
```

---

## Why Istio Service Mesh?

### The Problem: Microservices Complexity

Without a service mesh, you need to implement in **every service**:
- ❌ mTLS encryption (manual cert management)
- ❌ Load balancing logic
- ❌ Retry/timeout policies
- ❌ Circuit breakers
- ❌ Distributed tracing
- ❌ Metrics collection

### The Solution: Istio Service Mesh

Istio provides these features **transparently** via Envoy sidecar proxies:

```
┌─────────────────────────────────────────────────────────────┐
│                     SERVICE MESH LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  Traffic Management  │  Security (mTLS)  │  Observability  │
│  - Load Balancing    │  - Encryption     │  - Metrics      │
│  - Retries/Timeouts  │  - AuthN/AuthZ    │  - Tracing      │
│  - Circuit Breakers  │  - RBAC           │  - Logging      │
└─────────────────────────────────────────────────────────────┘
                           ↓
              ┌────────────────────────┐
              │   Envoy Sidecar Proxy  │ ← Injected automatically
              └────────────────────────┘
                           ↓
              ┌────────────────────────┐
              │   Your Application     │ ← No code changes!
              └────────────────────────┘
```

**Key Benefits:**
1. **Zero Code Changes** - Sidecars intercept traffic transparently
2. **Consistent Policies** - Centralized config via CRs (VirtualService, DestinationRule)
3. **Deep Observability** - L7 metrics, traces, and logs automatically
4. **Zero-Trust Security** - mTLS between all services

---

## Sail Operator vs Traditional Deployment

### Evolution of Istio Deployment

```
┌──────────────────────────────────────────────────────────────┐
│ GENERATION 1: Helm Charts (2017-2020)                       │
├──────────────────────────────────────────────────────────────┤
│ ❌ Monolithic values.yaml (1000+ lines)                      │
│ ❌ Manual upgrade coordination                               │
│ ❌ No canary rollout support                                 │
│ ❌ Drift between Helm state and cluster                      │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ GENERATION 2: IstioOperator CR (2020-2023)                  │
├──────────────────────────────────────────────────────────────┤
│ ✅ Declarative API                                           │
│ ⚠️  Still uses istioctl for upgrades                         │
│ ❌ No built-in canary upgrade                                │
│ ❌ Complex revision management                               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ GENERATION 3: Sail Operator (2024+) ← WE ARE HERE           │
├──────────────────────────────────────────────────────────────┤
│ ✅ 100% Kubernetes-native (pure CRs)                         │
│ ✅ Built-in RevisionBased canary upgrades                    │
│ ✅ HPA autoscaling by default                                │
│ ✅ GitOps-first design                                       │
│ ✅ Automatic cleanup of old revisions                        │
└──────────────────────────────────────────────────────────────┘
```

### Why Sail Operator is Better

| Feature | Helm | IstioOperator | **Sail Operator** |
|---------|------|---------------|-------------------|
| **Declarative API** | ❌ No | ✅ Yes | ✅ Yes |
| **GitOps-friendly** | ⚠️ Partial | ⚠️ Partial | ✅ Native |
| **Canary Upgrades** | ❌ Manual | ❌ Manual | ✅ Built-in |
| **Revision Cleanup** | ❌ Manual | ❌ Manual | ✅ Automatic |
| **HPA Autoscaling** | ⚠️ Custom | ⚠️ Custom | ✅ Default |
| **Multi-Cluster** | ❌ Complex | ⚠️ Partial | ✅ Native |
| **Operator Lifecycle** | N/A | ⚠️ istioctl | ✅ K8s CRDs |

**Production Example:**

With Sail Operator, the entire Istio installation is **one CR**:

```yaml
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
  namespace: istio-system
spec:
  version: v1.27.1
  updateStrategy:
    type: RevisionBased  # Zero-downtime canary upgrades!
  values:
    pilot:
      replicaCount: 3
      autoscaleMin: 3
      autoscaleMax: 5
```

That's it! No Helm releases, no istioctl, just pure GitOps.

---

## Architecture Overview

### Istio Control Plane Components

```
┌─────────────────────────────────────────────────────────────┐
│                    ISTIO CONTROL PLANE                      │
│                     (istio-system)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              istiod (Pilot)                          │  │
│  │  ┌────────────┬────────────┬────────────────────┐   │  │
│  │  │ Service    │ Security   │ Config             │   │  │
│  │  │ Discovery  │ (CA)       │ Distribution       │   │  │
│  │  └────────────┴────────────┴────────────────────┘   │  │
│  │                                                      │  │
│  │  • Generates Envoy config (xDS API)                 │  │
│  │  • Issues workload certificates (SPIFFE)            │  │
│  │  • Validates CRs (VirtualService, etc.)             │  │
│  │  • Health checks & load balancing                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│              gRPC (15010) / Webhooks (443)                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    DATA PLANE (Envoy Proxies)               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ App Pod 1   │  │ App Pod 2   │  │ App Pod 3   │        │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │        │
│  │ │ Envoy   │ │  │ │ Envoy   │ │  │ │ Envoy   │ │        │
│  │ │ Sidecar │ │  │ │ Sidecar │ │  │ │ Sidecar │ │        │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │        │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │        │
│  │ │  App    │ │  │ │  App    │ │  │ │  App    │ │        │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│  • L7 traffic interception (iptables)                      │
│  • mTLS encryption (SPIFFE certs)                          │
│  • Metrics/traces export (Prometheus/Jaeger)               │
└─────────────────────────────────────────────────────────────┘
```

### Sail Operator Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   SAIL OPERATOR                             │
│                  (sail-operator ns)                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   User: kubectl apply -f istio.yaml                        │
│              ↓                                              │
│   ┌──────────────────────────────────┐                     │
│   │  Istio CR (sailoperator.io/v1)  │                     │
│   │  - version: v1.27.1              │                     │
│   │  - updateStrategy: RevisionBased │                     │
│   └──────────────────────────────────┘                     │
│              ↓                                              │
│   ┌──────────────────────────────────┐                     │
│   │    Sail Operator Controller      │                     │
│   │  • Watches Istio CR              │                     │
│   │  • Creates IstioRevision CRs     │                     │
│   │  • Manages canary rollouts       │                     │
│   │  • Cleans up old revisions       │                     │
│   └──────────────────────────────────┘                     │
│              ↓                                              │
│   ┌──────────────────────────────────┐                     │
│   │   IstioRevision CRs              │                     │
│   │  - default-v1-27-1 (active)      │                     │
│   │  - default-v1-26-4 (pruned)      │                     │
│   └──────────────────────────────────┘                     │
│              ↓                                              │
│   ┌──────────────────────────────────┐                     │
│   │  Kubernetes Resources            │                     │
│   │  • Deployment: istiod            │                     │
│   │  • HPA: autoscaling              │                     │
│   │  • Service: istiod               │                     │
│   │  • ConfigMaps, Secrets, etc.     │                     │
│   └──────────────────────────────────┘                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
1. **Single Source of Truth**: Istio CR defines entire mesh
2. **Automatic Reconciliation**: Operator ensures desired state
3. **Revision Management**: Automatic creation/cleanup of IstioRevision CRs
4. **GitOps Native**: Just commit Istio CR changes, operator handles rest

---

## Enterprise Features

### 1. RevisionBased Zero-Downtime Upgrades

**Traditional Upgrade (Downtime):**
```
Time 0s: Delete old istiod → 30s downtime → Install new istiod
         ❌ All workloads lose control plane connection
```

**RevisionBased Upgrade (Zero Downtime):**
```
┌────────────────────────────────────────────────────────────┐
│ STEP 1: Install New Revision (Canary)                     │
├────────────────────────────────────────────────────────────┤
│ Old: istiod-v1-26-4 (3 replicas) ← Active                │
│ New: istiod-v1-27-1 (1 replica)  ← Canary                │
│                                                            │
│ All workloads still use v1.26.4 sidecars                  │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ STEP 2: Migrate Namespace (Update istio.io/rev label)     │
├────────────────────────────────────────────────────────────┤
│ kubectl label ns my-app istio.io/rev=default-v1-27-1      │
│                                                            │
│ Restart pods: New sidecars use v1.27.1 control plane      │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ STEP 3: Scale New Control Plane (Automatic)               │
├────────────────────────────────────────────────────────────┤
│ Old: istiod-v1-26-4 (3 replicas) ← No workloads          │
│ New: istiod-v1-27-1 (3 replicas) ← All workloads ✅      │
│                                                            │
│ HPA scales new istiod to match autoscaleMin: 3            │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ STEP 4: Cleanup Old Revision (Automatic)                  │
├────────────────────────────────────────────────────────────┤
│ Sail Operator deletes istiod-v1-26-4                      │
│ Only v1.27.1 remains ✅                                   │
└────────────────────────────────────────────────────────────┘
```

**Why This Matters:**
- ✅ **Zero downtime** - Old control plane stays until all workloads migrate
- ✅ **Gradual rollout** - Migrate one namespace at a time
- ✅ **Easy rollback** - Just switch namespace label back
- ✅ **Automatic cleanup** - No manual deletion needed

### 2. High Availability (HA)

**Our Production Configuration:**

```yaml
pilot:
  replicaCount: 3          # Baseline replica count
  autoscaleEnabled: true   # HPA for bursting
  autoscaleMin: 3          # Minimum 3 replicas (HA)
  autoscaleMax: 5          # Maximum 5 replicas
```

**Why 3 Replicas Minimum?**

```
┌────────────────────────────────────────────────────────────┐
│ FAILURE SCENARIO: 1 Replica (Single Point of Failure)     │
├────────────────────────────────────────────────────────────┤
│ istiod-1 dies → No control plane → Config frozen ❌       │
│ • Existing connections: OK (Envoy has cached config)      │
│ • New pods: FAIL (can't get sidecar config)               │
│ • Config changes: FAIL (no xDS server)                    │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ FAILURE SCENARIO: 3 Replicas (Fault Tolerant)             │
├────────────────────────────────────────────────────────────┤
│ istiod-1 (worker-2) ← DIES                                │
│ istiod-2 (worker-4) ← Still serving ✅                    │
│ istiod-3 (worker-6) ← Still serving ✅                    │
│                                                            │
│ • Envoy proxies reconnect to healthy instances            │
│ • New pods get config from istiod-2 or istiod-3           │
│ • Zero impact on applications ✅                          │
└────────────────────────────────────────────────────────────┘
```

**HPA Scaling Behavior:**

```
CPU Usage < 80%: Maintain 3 replicas (idle)
CPU Usage > 80%: Scale up to 5 replicas (burst)
                 ↓
┌──────────────────────────────────────────────┐
│ Normal Load (3 replicas)                     │
│ CPU: 10-30% per pod                          │
│ Memory: ~500Mi per pod                       │
└──────────────────────────────────────────────┘
                 ↓ Large config change
┌──────────────────────────────────────────────┐
│ High Load (5 replicas)                       │
│ CPU: 60-80% per pod                          │
│ • Example: 1000 VirtualServices deployed     │
│ • HPA automatically scales to 5 pods         │
└──────────────────────────────────────────────┘
                 ↓ Load decreases
┌──────────────────────────────────────────────┐
│ Back to Normal (3 replicas)                  │
│ HPA scales down to autoscaleMin: 3           │
└──────────────────────────────────────────────┘
```

### 3. Trace Sampling Optimization

**Default Istio (100% sampling):**
```
Every request → Generate trace → Export to Jaeger
                     ↓
Problem: 99% of traces are duplicates (same path)
         Massive CPU/memory/storage overhead
```

**Production (1% sampling):**
```yaml
pilot:
  env:
    PILOT_TRACE_SAMPLING: "0.01"  # 1%

telemetry:
  tracing:
    randomSamplingPercentage: 1.0  # 1%
```

**Performance Impact:**

| Metric | 100% Sampling | 1% Sampling | Savings |
|--------|---------------|-------------|---------|
| **Traces/sec** | 10,000 | 100 | **-99%** |
| **Jaeger CPU** | 4 cores | 0.2 cores | **-95%** |
| **Storage** | 50 GB/day | 500 MB/day | **-99%** |
| **Proxy overhead** | ~10% | ~1% | **-90%** |

**When to use 100% sampling:**
- ✅ Development/staging environments
- ✅ Active debugging of specific issues
- ❌ **NEVER in production** (kills performance)

### 4. Global mTLS STRICT Mode

**What is mTLS?**

```
WITHOUT mTLS (Plaintext):
┌──────────┐  HTTP (plaintext)  ┌──────────┐
│ Service A│ ──────────────────→│ Service B│
└──────────┘  ❌ Sniffable      └──────────┘

WITH mTLS (Encrypted):
┌──────────┐  TLS 1.3 + SPIFFE  ┌──────────┐
│ Service A│ ──────────────────→│ Service B│
└──────────┘  ✅ Encrypted      └──────────┘
             ✅ Mutual auth
             ✅ Cert rotation
```

**Our Configuration:**

```yaml
# Global PeerAuthentication in istio-system namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system  # Global scope!
spec:
  mtls:
    mode: STRICT  # Reject all plaintext traffic
```

**What STRICT Mode Does:**

```
┌────────────────────────────────────────────────────────────┐
│ PERMISSIVE Mode (Default - NOT RECOMMENDED)               │
├────────────────────────────────────────────────────────────┤
│ Service accepts BOTH mTLS and plaintext                   │
│ ⚠️  Legacy services can send unencrypted traffic          │
│ ⚠️  Man-in-the-middle attacks possible                    │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ STRICT Mode (Production - RECOMMENDED) ← WE USE THIS      │
├────────────────────────────────────────────────────────────┤
│ Service ONLY accepts mTLS traffic                         │
│ ✅ Zero-trust: All traffic is encrypted                   │
│ ✅ Mutual authentication: Both sides verified             │
│ ✅ Automatic cert rotation (24h default)                  │
└────────────────────────────────────────────────────────────┘
```

**Certificate Lifecycle:**

```
istiod (CA)
    ↓ Issue SPIFFE cert (24h TTL)
┌──────────────────────────────────┐
│ Service A Pod                    │
│ ┌──────────────────────────────┐ │
│ │ Envoy Sidecar                │ │
│ │ • Cert: /etc/certs/cert.pem  │ │
│ │ • Key:  /etc/certs/key.pem   │ │
│ │ • CA:   /etc/certs/root.pem  │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
    ↓ After 12h (50% TTL)
istiod rotates cert automatically
    ↓ New cert delivered via SDS API
Service A now has fresh cert ✅
```

**Zero-Trust Benefits:**
1. **Encryption by default** - No plaintext on the wire
2. **Identity-based auth** - SPIFFE IDs instead of IP addresses
3. **Automatic rotation** - No manual cert management
4. **Compliance ready** - PCI-DSS, HIPAA, SOC2 requirements met

### 5. Envoy Proxy Resource Optimization

**Default Istio (Underprovisioned):**
```yaml
proxy:
  resources:
    limits:
      memory: 128Mi  # ❌ OOMKilled under load!
      cpu: 100m      # ❌ Throttled during bursts
```

**Our Production Config (Right-sized):**
```yaml
proxy:
  resources:
    limits:
      cpu: 500m      # 5x headroom for burst traffic
      memory: 512Mi  # 4x headroom (prevents OOMKill)
    requests:
      cpu: 50m       # Reasonable baseline
      memory: 128Mi  # Actual steady-state usage
```

**Why This Matters:**

```
SCENARIO: High Traffic Spike (Black Friday)
──────────────────────────────────────────────

128Mi Limit (Default):
  Normal: 80Mi used
  Spike:  200Mi needed → OOMKilled ❌
          Pod restart → Lost connections

512Mi Limit (Production):
  Normal: 80Mi used (512Mi available)
  Spike:  200Mi needed → OK ✅
          No restart, no connection loss
```

**Memory Usage Breakdown:**

```
Envoy Proxy Memory:
├─ Config cache: 50-100 MB (routes, clusters, endpoints)
├─ Connection buffers: 20-50 MB (active connections)
├─ Stats/metrics: 10-20 MB (Prometheus exports)
├─ Request buffers: 30-100 MB (large POST bodies)
└─ Overhead: 10-20 MB (gRPC, Wasm, etc.)
                    ────────────────────────
Total Typical:      120-290 MB
512Mi Limit:        Provides 2x safety margin ✅
```

---

## Zero-Downtime Upgrades

### Complete Upgrade Workflow

**Scenario:** Upgrade from v1.26.4 to v1.27.1

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: Update Istio CR                                   │
├─────────────────────────────────────────────────────────────┤
│ $ kubectl edit istio default -n istio-system               │
│   spec:                                                     │
│     version: v1.27.1  # Change from v1.26.4                │
│                                                             │
│ Sail Operator detects change ✅                            │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 2: New Revision Deployment (Automatic)               │
├─────────────────────────────────────────────────────────────┤
│ Sail Operator creates:                                     │
│ • IstioRevision: default-v1-27-1                           │
│ • Deployment: istiod-default-v1-27-1 (1 replica)           │
│ • Service: istiod-default-v1-27-1                          │
│ • ConfigMap: istio-default-v1-27-1                         │
│                                                             │
│ Status: Both v1.26.4 and v1.27.1 running ✅                │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 3: Workload Migration (Manual/Gradual)               │
├─────────────────────────────────────────────────────────────┤
│ Strategy: Migrate one namespace at a time                  │
│                                                             │
│ $ kubectl label namespace my-app \                         │
│     istio.io/rev=default-v1-27-1 --overwrite               │
│ $ kubectl rollout restart deployment -n my-app             │
│                                                             │
│ New pods get v1.27.1 sidecars ✅                           │
│ Old pods still use v1.26.4 (safe) ✅                       │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 4: Validation                                        │
├─────────────────────────────────────────────────────────────┤
│ Check new pods:                                            │
│ $ kubectl get pod -n my-app -o jsonpath=\                 │
│     '{.items[0].metadata.annotations.sidecar\.istio\.io/   │
│     status}' | jq .revision                                │
│   → "default-v1-27-1" ✅                                   │
│                                                             │
│ Check metrics, logs, traces → All OK? Continue            │
│                               Problems? Rollback           │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 5: Scale New Control Plane (Automatic)               │
├─────────────────────────────────────────────────────────────┤
│ Once majority of workloads migrate:                        │
│ • HPA scales istiod-v1-27-1 to autoscaleMin: 3            │
│ • Old istiod-v1-26-4 has no traffic                        │
│                                                             │
│ IstioRevision status:                                      │
│ • default-v1-27-1: IN USE = True  (3 replicas)            │
│ • default-v1-26-4: IN USE = False (1 replica)             │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 6: Cleanup Old Revision (Manual/Automatic)           │
├─────────────────────────────────────────────────────────────┤
│ After ALL workloads migrated:                              │
│ $ kubectl delete istiorevision default-v1-26-4             │
│                                                             │
│ Sail Operator removes:                                     │
│ • Deployment: istiod-default-v1-26-4                       │
│ • Service, ConfigMap, etc.                                 │
│                                                             │
│ Only v1.27.1 remains ✅                                    │
└─────────────────────────────────────────────────────────────┘
```

### Rollback Strategy

**If issues detected with v1.27.1:**

```bash
# Instant rollback: Change namespace label back
kubectl label namespace my-app istio.io/rev=default-v1-26-4 --overwrite

# Restart pods to get old sidecars
kubectl rollout restart deployment -n my-app

# Old control plane (v1.26.4) still running ✅
# Zero downtime during rollback ✅
```

---

## Security: mTLS & PeerAuthentication

### mTLS Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              ISTIO CA (Certificate Authority)               │
│                    (istiod built-in)                        │
├─────────────────────────────────────────────────────────────┤
│ • Root CA: Self-signed or external (cert-manager)          │
│ • Issues workload certs via CSR API                        │
│ • Default TTL: 24 hours                                     │
│ • Rotation: Automatic at 50% TTL (12h)                     │
└─────────────────────────────────────────────────────────────┘
                           ↓ SDS (Secret Discovery Service)
┌─────────────────────────────────────────────────────────────┐
│                      ENVOY SIDECAR                          │
├─────────────────────────────────────────────────────────────┤
│  Certificate Store:                                         │
│  • SPIFFE ID: spiffe://cluster.local/ns/my-ns/sa/my-sa     │
│  • Cert: /etc/certs/cert-chain.pem                         │
│  • Key:  /etc/certs/key.pem (private key)                  │
│  • Root CA: /etc/certs/root-cert.pem                       │
│                                                             │
│  TLS Config:                                                │
│  • Protocol: TLS 1.3                                        │
│  • Cipher: ECDHE-ECDSA-AES256-GCM-SHA384                   │
│  • Verify: Peer SPIFFE ID + SAN                            │
└─────────────────────────────────────────────────────────────┘
```

### PeerAuthentication Scopes

```yaml
# GLOBAL (istio-system namespace)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system  # Applies to ALL namespaces
spec:
  mtls:
    mode: STRICT

# NAMESPACE (specific namespace)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: my-app  # Only applies to my-app namespace
spec:
  mtls:
    mode: PERMISSIVE  # Override global STRICT

# WORKLOAD (specific service)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: legacy-service
  namespace: my-app
spec:
  selector:
    matchLabels:
      app: legacy-service
  mtls:
    mode: DISABLE  # This service doesn't support mTLS
```

**Priority Order:** Workload > Namespace > Global

### Authorization Policies

**Example: Deny-by-default + Explicit Allow:**

```yaml
# Step 1: Deny all traffic (global)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: istio-system
spec: {}  # Empty spec = DENY

# Step 2: Allow frontend → backend
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
  namespace: my-app
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/my-app/sa/frontend"
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/*"]
```

**Result:** Only frontend ServiceAccount can call backend API ✅

---

## High Availability

### Multi-Replica Control Plane

**Production Setup:**

```yaml
pilot:
  replicaCount: 3
  autoscaleMin: 3
  autoscaleMax: 5
```

**Pod Anti-Affinity (Automatic):**

```yaml
# Sail Operator automatically adds:
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: istiod
          topologyKey: kubernetes.io/hostname
```

**Result:** istiod pods spread across different nodes ✅

```
worker-2: istiod-1 ✅
worker-4: istiod-2 ✅
worker-6: istiod-3 ✅

Node failure: Worker-2 dies → istiod-2 and istiod-3 still serve ✅
```

### HPA Configuration

**Our HPA:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: istiod-default-v1-27-1
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: istiod-default-v1-27-1
  minReplicas: 3
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

**Scaling Triggers:**

| CPU Usage | Action | Replicas |
|-----------|--------|----------|
| < 80% | Maintain | 3 (min) |
| 80-100% | Scale up | 3 → 4 |
| > 100% | Scale up | 4 → 5 (max) |
| < 60% | Scale down | 5 → 4 → 3 |

**Why CPU-based scaling?**
- Pilot CPU usage correlates with config volume (xDS pushes)
- Large VirtualService/DestinationRule updates = CPU spikes
- HPA automatically adds capacity during config storms

---

## Performance & Observability

### Metrics Export

**Istio exports 3 metric types:**

```
┌─────────────────────────────────────────────────────────────┐
│ 1. CONTROL PLANE METRICS (istiod)                          │
├─────────────────────────────────────────────────────────────┤
│ Endpoint: istiod:15014/metrics                             │
│ Metrics:                                                    │
│ • pilot_xds_pushes_total (config distribution)             │
│ • pilot_proxy_convergence_time (sidecar sync latency)      │
│ • istiod_managed_clusters (multi-cluster count)            │
│                                                             │
│ ServiceMonitor: istio-control-plane (auto-created)         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 2. DATA PLANE METRICS (Envoy sidecars)                     │
├─────────────────────────────────────────────────────────────┤
│ Endpoint: :15090/stats/prometheus (each pod)               │
│ Metrics:                                                    │
│ • istio_requests_total (L7 request count)                  │
│ • istio_request_duration_milliseconds (latency)            │
│ • istio_tcp_connections_opened_total                       │
│                                                             │
│ PodMonitor: istio-dataplane (auto-created)                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 3. DISTRIBUTED TRACES (OpenTelemetry)                      │
├─────────────────────────────────────────────────────────────┤
│ Envoy → OpenTelemetry Collector → Jaeger                   │
│ Sampling: 1% (PILOT_TRACE_SAMPLING: 0.01)                  │
│ Format: OTLP (gRPC)                                         │
└─────────────────────────────────────────────────────────────┘
```

### Observability Stack Integration

```
┌─────────────────────────────────────────────────────────────┐
│                     KIALI (Service Graph)                   │
├─────────────────────────────────────────────────────────────┤
│ • Queries Prometheus for istio_* metrics                   │
│ • Visualizes service topology                              │
│ • Traffic rates, error rates, latencies                    │
│ • Config validation (VirtualService, etc.)                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    PROMETHEUS (Metrics)                     │
├─────────────────────────────────────────────────────────────┤
│ • Scrapes istiod:15014 (control plane)                     │
│ • Scrapes pod:15090 (data plane)                           │
│ • Stores 30d retention                                      │
│ • Alerts on SLO violations                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                      JAEGER (Traces)                        │
├─────────────────────────────────────────────────────────────┤
│ • Receives 1% of traces from Envoy sidecars                │
│ • Traces span entire request path                          │
│ • Root cause analysis for latency spikes                   │
│ • Dependency graph generation                              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    GRAFANA (Dashboards)                     │
├─────────────────────────────────────────────────────────────┤
│ • Istio Control Plane Dashboard                            │
│ • Istio Service Dashboard                                  │
│ • Istio Workload Dashboard                                 │
│ • SLO/SLI tracking (99.9% uptime)                          │
└─────────────────────────────────────────────────────────────┘
```

### Key Metrics to Monitor

**Control Plane Health:**
```promql
# Pilot push latency (should be < 1s)
histogram_quantile(0.99,
  rate(pilot_proxy_convergence_time_bucket[5m])
)

# Config sync errors (should be 0)
rate(pilot_total_xds_rejects[5m])

# Sidecar connection count
pilot_xds_connections
```

**Data Plane Health:**
```promql
# Request success rate (should be > 99.9%)
sum(rate(istio_requests_total{response_code!~"5.."}[5m]))
  /
sum(rate(istio_requests_total[5m]))

# P99 latency (should be < 200ms)
histogram_quantile(0.99,
  rate(istio_request_duration_milliseconds_bucket[5m])
)

# Circuit breaker opens (should be rare)
rate(istio_requests_total{response_flags=~".*UO.*"}[5m])
```

---

## Best Practices

### 1. Namespace Labeling Strategy

```yaml
# Production pattern: Explicit revision labels
apiVersion: v1
kind: Namespace
metadata:
  name: my-app-prod
  labels:
    istio.io/rev: default-v1-27-1  # Explicit version
    environment: production

# Development: Auto-inject with Kyverno policy
# (See: kubernetes/security/kyverno/policies/auto-inject-istio-sidecar.yaml)
```

**Why explicit labels for production?**
- ✅ Controlled upgrades (no surprise sidecar changes)
- ✅ Gradual rollout (one namespace at a time)
- ✅ Easy rollback (just change label)

### 2. Resource Requests/Limits

```yaml
# GOOD (Our config):
proxy:
  resources:
    requests:
      cpu: 50m       # Actual usage
      memory: 128Mi
    limits:
      cpu: 500m      # 10x headroom for bursts
      memory: 512Mi  # 4x headroom for safety

# BAD (Default):
proxy:
  resources:
    requests:
      cpu: 10m       # Too low (scheduler lies)
      memory: 40Mi
    limits:
      cpu: 100m      # OOMKilled under load
      memory: 128Mi
```

**Impact of wrong sizing:**
- Too low limits → OOMKill → Connection loss
- Too high requests → Wasted resources → Fewer pods fit

### 3. Trace Sampling

```yaml
# Production: 1%
PILOT_TRACE_SAMPLING: "0.01"

# Staging: 10%
PILOT_TRACE_SAMPLING: "0.1"

# Development: 100%
PILOT_TRACE_SAMPLING: "1.0"
```

**When to increase sampling:**
- Active incident investigation
- New service rollout (first 24h)
- Performance regression debugging

**Always return to 1% after investigation!**

### 4. Sidecar Resource Scoping

**Problem:** Default sidecar fetches ALL services in cluster → High memory

**Solution:** Sidecar CR to limit scope

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: my-app
spec:
  egress:
    - hosts:
        - "./*"              # Same namespace
        - "istio-system/*"   # Istio control plane
        - "monitoring/*"     # Prometheus/Grafana
  # Exclude: other-team/* (reduces config size by 80%)
```

**Memory savings:** 200MB → 50MB per sidecar ✅

### 5. PeerAuthentication Hierarchy

```
Global (istio-system):     STRICT      ← Default for all
Namespace (my-app):        PERMISSIVE  ← Override for namespace
Workload (legacy-service): DISABLE     ← Override for specific pod
```

**Migration strategy:**
1. Start: Global PERMISSIVE (allow plaintext)
2. Enable mTLS per namespace (test individually)
3. Switch global to STRICT (after all namespaces ready)

### 6. VirtualService Best Practices

```yaml
# GOOD: Explicit timeout/retry
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service
  http:
    - route:
        - destination:
            host: my-service
      timeout: 5s
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure

# BAD: No timeout (default 15s = too long)
# BAD: No retry (single failure = request fails)
```

---

## Production Checklist

### Pre-Deployment Validation

- [ ] **Istio CR version** matches desired release (v1.27.1)
- [ ] **replicaCount ≥ 3** for HA
- [ ] **autoscaleMin: 3** configured
- [ ] **PILOT_TRACE_SAMPLING: "0.01"** (1%)
- [ ] **Global PeerAuthentication** set to STRICT
- [ ] **Proxy memory limits ≥ 512Mi**
- [ ] **updateStrategy: RevisionBased** enabled

### Post-Upgrade Validation

```bash
# 1. Verify Istio version
kubectl get istio default -n istio-system -o jsonpath='{.spec.version}'
# Expected: v1.27.1

# 2. Check control plane replicas
kubectl get pods -n istio-system -l app=istiod
# Expected: 3/3 Running

# 3. Verify HPA min replicas
kubectl get hpa -n istio-system -o jsonpath='{.items[0].spec.minReplicas}'
# Expected: 3

# 4. Check global mTLS
kubectl get peerauthentication default -n istio-system -o jsonpath='{.spec.mtls.mode}'
# Expected: STRICT

# 5. Verify trace sampling
kubectl get istio default -n istio-system -o jsonpath='{.spec.values.pilot.env.PILOT_TRACE_SAMPLING}'
# Expected: 0.01

# 6. Test sidecar injection
kubectl run test --image=nginx --labels="app=test" -n my-app
kubectl get pod test -n my-app -o jsonpath='{.spec.containers[*].name}'
# Expected: nginx istio-proxy (2 containers)

# 7. Check metrics endpoint
kubectl exec -n my-app deploy/my-service -c istio-proxy -- curl -s localhost:15090/stats/prometheus | grep istio_requests_total
# Expected: istio_requests_total metrics present
```

### Monitoring Alerts

**Critical Alerts:**

```yaml
# Istio control plane down
- alert: IstiodDown
  expr: up{job="istiod"} == 0
  for: 5m
  severity: critical

# High sidecar error rate
- alert: HighSidecarErrorRate
  expr: |
    sum(rate(istio_requests_total{response_code=~"5.."}[5m]))
    /
    sum(rate(istio_requests_total[5m])) > 0.01
  for: 5m
  severity: warning

# Config push failures
- alert: PilotPushErrors
  expr: rate(pilot_total_xds_rejects[5m]) > 0
  for: 5m
  severity: warning
```

### Disaster Recovery

**Scenario: Complete control plane loss**

```bash
# 1. Check IstioRevision status
kubectl get istiorevision -n istio-system

# 2. If no active revision, Istio CR will auto-recreate
kubectl get istio default -n istio-system
# Sail Operator reconciles within 30s ✅

# 3. Existing sidecars continue working (cached config)
# No traffic impact during control plane restoration ✅

# 4. Verify recovery
kubectl wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=5m
```

**Key Point:** Envoy sidecars cache config locally, so control plane outage doesn't break traffic ✅

---

## Summary

### What We Achieved

✅ **Zero-downtime upgrades** via RevisionBased strategy
✅ **High Availability** with 3-replica control plane + HPA
✅ **99% trace overhead reduction** (100% → 1% sampling)
✅ **Zero-Trust security** with global mTLS STRICT mode
✅ **OOMKill prevention** with 512Mi proxy memory limits
✅ **GitOps-native** with Sail Operator single-CR management

### Why Sail Operator > Helm

| Requirement | Helm | Sail Operator |
|-------------|------|---------------|
| Canary upgrades | ❌ Manual | ✅ Built-in |
| Revision cleanup | ❌ Manual | ✅ Automatic |
| HPA by default | ❌ No | ✅ Yes |
| Single source of truth | ⚠️ values.yaml | ✅ Istio CR |
| GitOps-friendly | ⚠️ Helm drift | ✅ Native K8s |

### Next Steps

1. **Enable Kiali** for service graph visualization
2. **Configure AuthorizationPolicies** for fine-grained RBAC
3. **Deploy Gateways** for ingress traffic management
4. **Multi-cluster setup** (future expansion)

---

**🎯 Production Status: ENTERPRISE READY**

All Istio + Sail Operator best practices implemented ✅
