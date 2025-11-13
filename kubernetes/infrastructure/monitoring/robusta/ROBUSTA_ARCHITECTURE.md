# 🤖 Robusta Architecture & How It Works

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [Components](#components)
- [Alert Flow](#alert-flow)
- [AI Integration](#ai-integration)
- [Current Configuration](#current-configuration)

---

## Overview

**Robusta** ist ein Kubernetes alert enrichment platform das:
1. **Kubernetes Events überwacht** (CrashLoopBackOff, OOMKilled, etc.)
2. **Prometheus Alerts empfängt** (via Alertmanager webhook)
3. **Alerts anreichert** mit Logs, Metrics, Graphs, AI analysis
4. **Enriched alerts sendet** an Slack mit rich formatting

**Key Benefit**: Statt "Pod crashed" bekommst du "Pod crashed + logs + memory graph + AI root cause analysis + fix suggestions"

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          KUBERNETES CLUSTER                                  │
│                                                                              │
│  ┌──────────────────┐         ┌──────────────────┐                         │
│  │   Kubernetes     │         │   Prometheus      │                         │
│  │   API Server     │         │   + Alertmanager  │                         │
│  │                  │         │                   │                         │
│  │  • Pod Events    │         │  • Custom Alerts  │                         │
│  │  • Node Events   │         │  • HighCPU        │                         │
│  │  • Deployment    │         │  • HighMemory     │                         │
│  └────────┬─────────┘         └────────┬──────────┘                         │
│           │                            │                                     │
│           │ Watch Events               │ Webhook                             │
│           │                            │                                     │
│           v                            v                                     │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │                      ROBUSTA RUNNER POD                          │        │
│  │                                                                   │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  1. EVENT DETECTION                                         │ │        │
│  │  │  • Kubewatch: Watches K8s API for events                    │ │        │
│  │  │  • Webhook receiver: Receives Alertmanager alerts           │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  2. PLAYBOOK MATCHING                                       │ │        │
│  │  │  • Match event to playbooks (triggers)                      │ │        │
│  │  │  • Example: CrashLoopBackOff → crash_loop_playbook         │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  3. ENRICHMENT ACTIONS                                      │ │        │
│  │  │  ┌──────────────────────────────────────────────────────┐  │ │        │
│  │  │  │  a) Logs Enricher                                     │  │ │        │
│  │  │  │     → kubectl logs {pod} --tail=100                   │  │ │        │
│  │  │  │     → Gets logs from crashed container                │  │ │        │
│  │  │  └──────────────────────────────────────────────────────┘  │ │        │
│  │  │  ┌──────────────────────────────────────────────────────┐  │ │        │
│  │  │  │  b) Metrics Enricher                                  │  │ │        │
│  │  │  │     → Query Prometheus for CPU/Memory graphs          │  │ │        │
│  │  │  │     → Generate graph images                           │  │ │        │
│  │  │  └──────────────────────────────────────────────────────┘  │ │        │
│  │  │  ┌──────────────────────────────────────────────────────┐  │ │        │
│  │  │  │  c) Related Resources                                 │  │ │        │
│  │  │  │     → kubectl get deployment {name}                   │  │ │        │
│  │  │  │     → Get node status, events, etc.                   │  │ │        │
│  │  │  └──────────────────────────────────────────────────────┘  │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  4. AI ANALYSIS (HolmesGPT Integration)                    │ │        │
│  │  │                                                             │ │        │
│  │  │  Sends to HolmesGPT pod →                                  │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  └──────────────────────────┼──────────────────────────────────────┘        │
│                              │                                               │
│                              v                                               │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │                   ROBUSTA HOLMES POD (HolmesGPT)                 │        │
│  │                                                                   │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  AI Analysis Engine                                         │ │        │
│  │  │  • Receives: Logs + Metrics + Events + Context             │ │        │
│  │  │  • Connects to: Ollama (ai-inference namespace)            │ │        │
│  │  │  • Model: phi3:mini (2.2GB, Microsoft Phi-3)               │ │        │
│  │  │  • Analyzes: Root cause, patterns, recommendations         │ │        │
│  │  │  • Returns: AI insights + suggested fixes                  │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  └──────────────────────────┼──────────────────────────────────────┘        │
│                              │                                               │
│                              │ AI Insights                                   │
│                              v                                               │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │                      ROBUSTA RUNNER POD                          │        │
│  │  (continued)                                                      │        │
│  │                                                                   │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  5. FINDING CREATION                                        │ │        │
│  │  │  • Combine: Original event + Enrichments + AI insights      │ │        │
│  │  │  • Format: Slack blocks with rich formatting               │ │        │
│  │  │  • Add: Graphs as images, logs as code blocks              │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  │  ┌────────────────────────────────────────────────────────────┐ │        │
│  │  │  6. SINK ROUTING                                            │ │        │
│  │  │  • Match severity to sink                                   │ │        │
│  │  │  • Example: HIGH → #on-call, MEDIUM → #homelab-alerts      │ │        │
│  │  └────────────────────────────────────────────────────────────┘ │        │
│  │                            ↓                                      │        │
│  └──────────────────────────┼──────────────────────────────────────┘        │
│                              │                                               │
└──────────────────────────────┼───────────────────────────────────────────────┘
                               │
                               │ Slack API (OAuth Bot Token)
                               v
                    ┌──────────────────────┐
                    │   SLACK WORKSPACE    │
                    │                      │
                    │  #homelab-alerts     │
                    │  ┌────────────────┐  │
                    │  │ 🔴 Alert:      │  │
                    │  │ Pod crashed!   │  │
                    │  │                │  │
                    │  │ Logs:          │  │
                    │  │ [logs here]    │  │
                    │  │                │  │
                    │  │ Graph:         │  │
                    │  │ [graph image]  │  │
                    │  │                │  │
                    │  │ 🤖 AI Analysis:│  │
                    │  │ Root cause...  │  │
                    │  └────────────────┘  │
                    └──────────────────────┘
```

---

## Components

### 1️⃣ **Robusta Runner** (`robusta-runner` Deployment)

**Role**: Main orchestration engine

**What it does**:
- Watches Kubernetes API for events
- Receives Prometheus alerts via webhook
- Matches events to playbooks
- Executes enrichment actions
- Calls HolmesGPT for AI analysis
- Formats and sends to Slack

**Configuration**:
- `ENV: SLACK_API_KEY` - OAuth token from SealedSecret
- `ENV: HOLMES_ENABLED=True` - AI debugging enabled
- Connects to: Prometheus, Kubernetes API, HolmesGPT, Slack

**Resources**:
```yaml
requests:
  cpu: 100m
  memory: 256Mi
limits:
  cpu: 500m
  memory: 512Mi
```

---

### 2️⃣ **Robusta Holmes** (`robusta-holmes` Deployment)

**Role**: AI analysis engine (HolmesGPT)

**What it does**:
- Receives enriched context from runner
- Connects to Ollama (self-hosted LLM)
- Performs root cause analysis
- Detects patterns and anomalies
- Generates fix recommendations
- Returns AI insights to runner

**Configuration**:
```yaml
holmesGPT:
  apiUrl: "http://ollama.ai-inference.svc:11434/v1"
  model: "phi3:mini"
  temperature: 0.2  # Deterministic
  maxTokens: 2048
```

**Resources**:
```yaml
requests:
  cpu: 100m
  memory: 2048Mi  # 2GB for AI model context
limits:
  memory: 2048Mi
```

---

### 3️⃣ **Robusta Forwarder** (`robusta-forwarder` Deployment)

**Role**: Event forwarding for distributed setups

**What it does**:
- Watches Kubernetes events
- Forwards to runner
- Used in multi-cluster setups

**Note**: In single-cluster setup (wie bei dir), runner überwacht direkt via kubewatch.

---

### 4️⃣ **Kubewatch** (Sidecar in Runner)

**Role**: Kubernetes event watcher

**What it does**:
- Watches specific Kubernetes resources:
  - Pods
  - Deployments
  - StatefulSets
  - DaemonSets
  - Jobs
  - Nodes
  - Services
  - PersistentVolumeClaims
- Sends events to runner process

**Configuration** (in `robusta-kubewatch-config` ConfigMap):
```yaml
resource:
  pod: true
  deployment: true
  statefulset: true
  daemonset: true
  job: true
  node: true
  service: true
  persistentvolume: true

reason:
  BackOff: true
  Failed: true
  Killing: true
  Unhealthy: true
  FailedScheduling: true
  FailedMount: true
```

---

### 5️⃣ **External Dependencies**

#### **Ollama** (ai-inference namespace)
```
Service: ollama.ai-inference.svc:11434
Model: phi3:mini (2.2GB)
Purpose: Self-hosted LLM for AI analysis
```

#### **Prometheus** (monitoring namespace)
```
Service: kube-prometheus-stack-prometheus.monitoring.svc:9090
Purpose: Metrics queries for graphs and context
```

#### **Slack API**
```
Endpoint: https://slack.com/api/chat.postMessage
Auth: OAuth Bot Token (from SealedSecret)
Channel: #homelab-alerts
```

---

## Alert Flow

### 🔥 Example: Pod CrashLoopBackOff

```
STEP 1: EVENT DETECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Kubernetes API Server
  ↓
Pod Status Change: robusta-test-crashloop
  Status: CrashLoopBackOff
  Restarts: 2
  Reason: Error
  ↓
Kubewatch detects event
  ↓
Sends to Runner: {
  "event_type": "BackOff",
  "pod": "robusta-test-crashloop",
  "namespace": "monitoring",
  "reason": "CrashLoopBackOff"
}


STEP 2: PLAYBOOK MATCHING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Runner receives event
  ↓
Matches to built-in playbook:
  Trigger: on_pod_crash_loop
  Actions:
    - logs_enricher
    - pod_graph_enricher
    - related_pods
    - create_finding


STEP 3: ENRICHMENT ACTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────┐
│ Action 1: logs_enricher                         │
├─────────────────────────────────────────────────┤
│ kubectl logs robusta-test-crashloop \           │
│   --namespace=monitoring --tail=100             │
│                                                  │
│ Result:                                          │
│ "Error: exit code 1"                            │
│ "Container exited with status 1"                │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│ Action 2: pod_graph_enricher                    │
├─────────────────────────────────────────────────┤
│ Prometheus query:                                │
│ container_memory_usage_bytes{                   │
│   pod="robusta-test-crashloop",                 │
│   namespace="monitoring"                        │
│ }[1h]                                           │
│                                                  │
│ Result: Graph PNG image (base64)               │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│ Action 3: related_pods                          │
├─────────────────────────────────────────────────┤
│ kubectl get pods -n monitoring \                │
│   --selector=app=robusta-test                   │
│                                                  │
│ Result: List of related pods                    │
└─────────────────────────────────────────────────┘


STEP 4: AI ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Runner sends to HolmesGPT:
  ↓
{
  "context": {
    "pod_name": "robusta-test-crashloop",
    "namespace": "monitoring",
    "logs": "Error: exit code 1...",
    "status": "CrashLoopBackOff",
    "restarts": 2,
    "events": [...],
    "metrics": {...}
  },
  "question": "What is the root cause of this crash?"
}
  ↓
HolmesGPT → Ollama (phi3:mini):
  ↓
Prompt to AI:
  "Analyze this Kubernetes pod crash:
   - Pod: robusta-test-crashloop
   - Status: CrashLoopBackOff (2 restarts)
   - Logs: Error: exit code 1

   What is the root cause and how to fix it?"
  ↓
AI Response:
  "Root cause: Container command exits with non-zero status.
   The container is running 'sh -c exit 1' which immediately
   fails. This is a test scenario.

   Fix: Update container command to a valid long-running process,
   or fix the script that's causing the exit."
  ↓
HolmesGPT returns to Runner


STEP 5: FINDING CREATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Runner combines all data:
  ↓
{
  "title": "Crashing pod robusta-test-crashloop",
  "severity": "HIGH",
  "source": "timour-homelab-talos",
  "enrichments": [
    {
      "type": "crash_info",
      "data": {
        "container": "robusta-test-crashloop",
        "restarts": 2,
        "status": "WAITING",
        "reason": "CrashLoopBackOff"
      }
    },
    {
      "type": "logs",
      "data": "Error: exit code 1..."
    },
    {
      "type": "graph",
      "data": "<base64 PNG image>"
    },
    {
      "type": "ai_analysis",
      "data": "Root cause: Container command exits..."
    }
  ]
}
  ↓
Format as Slack Blocks:
[
  {
    "type": "section",
    "text": "🔴 *High* - Crashing pod robusta-test-crashloop"
  },
  {
    "type": "section",
    "text": "*Crash Info*\n• Container: robusta-test-crashloop\n..."
  },
  {
    "type": "image",
    "image_url": "<graph PNG>",
    "alt_text": "Memory usage graph"
  },
  {
    "type": "section",
    "text": "🤖 *AI Analysis*\nRoot cause: Container command exits..."
  }
]


STEP 6: SINK ROUTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Check severity: HIGH
  ↓
Match to sink: homelab_slack
  Channel: #homelab-alerts
  ↓
Send via Slack API:
  POST https://slack.com/api/chat.postMessage
  Headers:
    Authorization: Bearer xoxb-9682664117863-...
  Body:
    {
      "channel": "#homelab-alerts",
      "blocks": [...],
      "text": "Crashing pod robusta-test-crashloop"
    }
  ↓
Slack responds: {"ok": true, "ts": "1234567890.123456"}
  ↓
✅ Alert delivered to Slack!
```

---

## AI Integration

### How HolmesGPT Works

```
┌─────────────────────────────────────────────────────────────┐
│  ROBUSTA RUNNER                                              │
│  (Detected: Pod CrashLoopBackOff)                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ 1. Send enriched context
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│  ROBUSTA HOLMES POD (HolmesGPT)                              │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Input Context:                                         │ │
│  │  {                                                       │ │
│  │    "pod": "robusta-test-crashloop",                     │ │
│  │    "namespace": "monitoring",                           │ │
│  │    "status": "CrashLoopBackOff",                        │ │
│  │    "logs": "Error: exit code 1...",                     │ │
│  │    "restarts": 2,                                       │ │
│  │    "metrics": {                                         │ │
│  │      "memory_usage": "50Mi",                            │ │
│  │      "cpu_usage": "10m"                                 │ │
│  │    },                                                    │ │
│  │    "events": [...]                                      │ │
│  │  }                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  2. Build AI Prompt:                                    │ │
│  │                                                          │ │
│  │  "You are a Kubernetes expert. Analyze this pod crash:  │ │
│  │                                                          │ │
│  │   Pod: robusta-test-crashloop (monitoring namespace)    │ │
│  │   Status: CrashLoopBackOff (2 restarts)                │ │
│  │   Last logs: Error: exit code 1                         │ │
│  │   Memory: 50Mi, CPU: 10m                                │ │
│  │                                                          │ │
│  │   Question: What is the root cause and how to fix it?"  │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
└────────────────────────────┼────────────────────────────────┘
                             │
                             │ 3. HTTP Request
                             │
                             v
┌─────────────────────────────────────────────────────────────┐
│  OLLAMA POD (ai-inference namespace)                         │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  POST http://ollama.ai-inference.svc:11434/v1/chat      │ │
│  │  {                                                       │ │
│  │    "model": "phi3:mini",                                │ │
│  │    "messages": [                                        │ │
│  │      {                                                   │ │
│  │        "role": "system",                                │ │
│  │        "content": "You are a Kubernetes expert..."      │ │
│  │      },                                                  │ │
│  │      {                                                   │ │
│  │        "role": "user",                                  │ │
│  │        "content": "Analyze this pod crash..."           │ │
│  │      }                                                   │ │
│  │    ],                                                    │ │
│  │    "temperature": 0.2,                                  │ │
│  │    "max_tokens": 2048                                   │ │
│  │  }                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Phi3:mini AI Model (2.2GB, Microsoft)                  │ │
│  │  • Technical reasoning                                   │ │
│  │  • Pattern matching                                      │ │
│  │  • Code analysis                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  AI Response:                                            │ │
│  │  {                                                       │ │
│  │    "choices": [{                                        │ │
│  │      "message": {                                       │ │
│  │        "content": "Root cause: The container command   │ │
│  │         'sh -c exit 1' is designed to fail immediately.│ │
│  │         This causes Kubernetes to restart the pod      │ │
│  │         repeatedly, resulting in CrashLoopBackOff.     │ │
│  │                                                          │ │
│  │         Fix: Update the container command to a valid   │ │
│  │         long-running process, such as a web server or  │ │
│  │         daemon. If this is a test scenario, remove the │ │
│  │         pod or fix the script."                        │ │
│  │      }                                                   │ │
│  │    }]                                                    │ │
│  │  }                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
└────────────────────────────┼────────────────────────────────┘
                             │
                             │ 4. Return AI insights
                             │
                             v
┌─────────────────────────────────────────────────────────────┐
│  ROBUSTA HOLMES POD                                          │
│  • Parse AI response                                         │
│  • Extract key insights                                      │
│  • Return to Runner                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ 5. AI insights
                         │
                         v
┌─────────────────────────────────────────────────────────────┐
│  ROBUSTA RUNNER                                              │
│  • Add AI insights to finding                                │
│  • Format for Slack                                          │
│  • Send enriched alert                                       │
└─────────────────────────────────────────────────────────────┘
```

### AI Model: Phi3:mini

**Why Phi3:mini?**
- **Size**: 2.2GB (small enough for homelab)
- **Quality**: Microsoft's latest small model
- **Speed**: Fast inference (1-2 seconds)
- **Specialization**: Excellent for technical/code tasks
- **Cost**: FREE (self-hosted with Ollama)
- **Privacy**: All data stays in cluster

**Alternatives**:
- `llama3:8b` - Larger, more general-purpose (8GB)
- `codellama:7b` - Better for code debugging (7GB)
- `mistral:7b` - Good balance (7GB)

---

## Current Configuration

### 📁 File Structure

```
kubernetes/infrastructure/monitoring/robusta/
├── application.yaml                    # ArgoCD Application
├── kustomization.yaml                  # Kustomize config
├── manifests.yaml                      # Pre-rendered Helm manifests (900 lines)
├── slack-token-sealed-secret.yaml     # Encrypted Slack OAuth token
├── values.yaml                         # Helm values (local only, not in Git)
└── ROBUSTA_ARCHITECTURE.md            # This file
```

### ⚙️ Configuration Highlights

#### **Slack Integration**
```yaml
# values.yaml (local)
sinksConfig:
  - slack_sink:
      name: homelab_slack
      api_key: "{{ env.SLACK_API_KEY }}"
      slack_channel: "#homelab-alerts"

runner:
  additional_env_vars:
    - name: SLACK_API_KEY
      valueFrom:
        secretKeyRef:
          name: robusta-slack-token
          key: api_key
```

**Secret Flow**:
1. Raw token: `xoxb-9682664117863-...`
2. Create K8s secret (dry-run)
3. Seal with `kubeseal` → `slack-token-sealed-secret.yaml`
4. Commit encrypted secret to Git
5. SealedSecret controller decrypts in cluster
6. Runner reads from `robusta-slack-token` secret

#### **HolmesGPT Configuration**
```yaml
enableHolmesGPT: true

holmesGPT:
  apiUrl: "http://ollama.ai-inference.svc:11434/v1"
  model: "phi3:mini"
  temperature: 0.2
  maxTokens: 2048
  timeout: 60

aiAnalysis:
  enabled: true
  alertTypes:
    - "CrashLoopBackOff"
    - "OOMKilled"
    - "ImagePullBackOff"
    - "NodeNotReady"
    - "PodPending"
    - "DeploymentReplicasMismatch"
  enrichSlackAlerts: true
```

#### **Prometheus Integration**
```yaml
globalConfig:
  prometheus_url: "http://kube-prometheus-stack-prometheus.monitoring.svc:9090"
  alertmanager_url: "http://kube-prometheus-stack-alertmanager.monitoring.svc:9093"
```

**Note**: Alertmanager webhook not yet configured. When configured, Prometheus alerts will be sent to Robusta for enrichment.

#### **Resource Limits**
```yaml
runner:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

holmesGPT:
  resources:
    requests:
      cpu: 100m
      memory: 2048Mi
    limits:
      memory: 2048Mi
```

---

## Deployment Pattern: Pre-rendered Manifests

### Why Pre-rendered?

**Problem**: ArgoCD's Kustomize + helmCharts integration doesn't work reliably with external `valuesFile`

**Solution**: Use `helm template` locally to pre-render manifests, then commit to Git

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│  LOCAL MACHINE                                               │
│                                                               │
│  1. Edit values.yaml (local file, not in Git)               │
│     • Update Slack channel                                   │
│     • Change AI model                                        │
│     • Add custom playbooks                                   │
│                                                               │
│  2. Run: helm template robusta robusta/robusta \            │
│          --version 0.28.1 \                                  │
│          --namespace monitoring \                            │
│          --values values.yaml \                              │
│          --include-crds > manifests.yaml                     │
│                                                               │
│  3. Commit: manifests.yaml + slack-token-sealed-secret.yaml │
│                                                               │
│  4. Push to GitHub                                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Git push
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│  ARGOCD (Kubernetes Cluster)                                 │
│                                                               │
│  1. Detects Git change                                       │
│  2. Runs kustomize build                                     │
│     • Loads manifests.yaml                                   │
│     • Loads slack-token-sealed-secret.yaml                  │
│     • Applies labels & annotations                           │
│  3. kubectl apply -f                                         │
│  4. Sync Status: Synced ✅                                   │
└─────────────────────────────────────────────────────────────┘
```

### Advantages
- ✅ **Deterministic**: manifests.yaml is exactly what gets deployed
- ✅ **Git-trackable**: Can see exact changes in PR diffs
- ✅ **No ArgoCD magic**: No hidden Helm rendering issues
- ✅ **Fast sync**: No Helm chart download during sync

### Disadvantages
- ❌ **Manual regeneration**: Must run `helm template` after every values.yaml change
- ❌ **Large diffs**: manifests.yaml is 900 lines
- ❌ **Linter conflicts**: Pre-commit yamllint doesn't like Helm-generated YAML

**Solution**: Skip linters for manifests.yaml:
```bash
SKIP=yamllint,check-yaml git commit -m "..."
```

---

## What Gets Alerted?

### 🔴 **Currently Active (Default Playbooks)**

| Event Type | Trigger | Actions | Slack Message |
|-----------|---------|---------|---------------|
| CrashLoopBackOff | Pod restarts > 2 | Logs + Graph + AI | "🔴 Crashing pod {name}" |
| ImagePullBackOff | Pod can't pull image | Image info + Events | "⚠️ Image pull failed: {image}" |
| OOMKilled | Pod killed by OOM | Memory graph + Limits | "💥 OOMKilled: {pod}" |
| PodPending | Pod stuck pending | Node status + Events | "⏳ Pod pending: {pod}" |
| NodeNotReady | Node down | Node events + Pods | "🚨 Node not ready: {node}" |

### ⚪ **Not Yet Configured (Easy to Add)**

| Alert Type | Source | Setup Required |
|-----------|--------|----------------|
| HighMemory | Prometheus | Add Alertmanager webhook |
| HighCPU | Prometheus | Add Alertmanager webhook |
| DiskFull | Prometheus | Add Alertmanager webhook |
| CertExpiring | Prometheus/Custom | Add playbook |
| DeploymentUpdate | Kubernetes | Add playbook |
| JobFailure | Kubernetes | Add playbook |

---

## Next Steps

### 🎯 **Recommended Enhancements**

1. **Prometheus Integration** (30 min)
   - Add Alertmanager webhook to Robusta
   - Existing HighCPU/HighMemory alerts get AI enrichment
   - See metrics graphs in Slack

2. **Tier System** (45 min)
   - Create 3 Slack channels: #incidents-critical, #on-call, #homelab-info
   - Route by severity
   - Different enrichment per tier

3. **Custom Playbooks** (1 hour)
   - Deployment notifications
   - Certificate expiry warnings
   - Weekly resource usage reports

4. **Proactive Scans** (30 min)
   - KRR resource recommendations (weekly cron)
   - Popeye cluster health checks
   - Security CVE scanning

---

## Troubleshooting

### Common Issues

**1. No alerts in Slack**
```bash
# Check runner logs
kubectl logs -n monitoring deployment/robusta-runner --tail=50

# Look for:
# - "Adding slack_sink named homelab_slack" ✅
# - "channel_not_found" ❌ (bot not in channel)
# - "invalid_auth" ❌ (wrong token)
```

**2. AI analysis not working**
```bash
# Check Holmes logs
kubectl logs -n monitoring deployment/robusta-holmes --tail=50

# Check Ollama connectivity
kubectl exec -n monitoring deployment/robusta-holmes -- \
  curl -v http://ollama.ai-inference.svc:11434/v1/models
```

**3. Manifests out of sync**
```bash
# Regenerate manifests
cd kubernetes/infrastructure/monitoring/robusta
helm template robusta robusta/robusta \
  --version 0.28.1 \
  --namespace monitoring \
  --values values.yaml \
  --include-crds > manifests.yaml

# Commit
SKIP=yamllint,check-yaml git commit -m "regenerate manifests"
```

---

## Resources

- **Official Docs**: https://docs.robusta.dev
- **Helm Chart**: https://github.com/robusta-dev/robusta/tree/master/helm/robusta
- **HolmesGPT**: https://github.com/robusta-dev/holmesgpt
- **Playbooks**: https://docs.robusta.dev/master/playbook-reference/index.html

---

**Last Updated**: 2025-10-17
**Author**: Claude + Tim275
**Version**: v1.0 (Initial deployment with HolmesGPT + Ollama)
