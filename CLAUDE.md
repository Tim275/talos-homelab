# Claude Notes

## Enterprise GitOps Pattern
```
ApplicationSet → findet Apps
     ↓
Kustomize → baut dev/prod Varianten
     ↓
ArgoCD → deployed
```

**KUSTOMIZE IST DER KERN!** ApplicationSets nur für Discovery, Kustomize macht die Arbeit!

## Commit Style
- NIEMALS diese Tags hinzufügen:
  - `🤖 Generated with [Claude Code]`
  - `Co-Authored-By: Claude`
- Einfache, saubere Commit-Messages ohne Claude-Referenzen

## Vector Logo Issue
- Original Vector logo URL war kaputt: `https://vector.dev/img/logos/vector-logo.svg`
- Ersetzt durch Rust Crab Emoji: 🦀
- Vector ist in Rust geschrieben, daher passt das Crab-Emoji perfekt

---

## Session 2025-09-21: Enterprise Architecture & Security Planning

### 🎯 **Hauptziele erreicht:**
1. **Enterprise Tier-0 Architecture** - Netflix/Google/Meta patterns implementiert
2. **N8N Infrastructure** - Vollständig funktionsfähig mit PostgreSQL
3. **Clean Layer Separation** - Apps/Platform/Infrastructure richtig getrennt

### 🔧 **Fixes & Improvements:**

#### **Metrics Server Problem gelöst:**
- **Problem**: `kubectl top nodes` Error - Metrics API not available
- **Ursache**: `infrastructure-monitoring.yaml` ApplicationSet war nicht in kustomization.yaml
- **Fix**: ApplicationSet zu infrastructure/kustomization.yaml hinzugefügt

#### **N8N Development Environment:**
- **Problem**: N8N-dev hatte CrashLoopBackOff (20+ restarts)
- **Ursachen**:
  1. Fehlende PostgreSQL Database für dev
  2. File permissions issue (`N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`)
  3. Password mismatch zwischen N8N und PostgreSQL
- **Lösung**: Separate CloudNativePG cluster für n8n-dev erstellt

#### **Enterprise Architecture Refactoring:**
- **Problem**: Resource quotas, Argo Rollouts in apps/ layer störten ApplicationSets
- **Lösung**: Clean separation implementiert:
  - **Apps Layer**: Nur einfache deployments, services, configs (developer-focused)
  - **Platform Layer**: Databases, quotas, progressive delivery (platform engineering)
  - **Infrastructure Layer**: Cluster-wide services, operators

### 🏗️ **Aktuelle Struktur:**
```
├── kubernetes/security/               # 🛡️ NEXT: Security layer (geplant)
│   ├── pod-security-standards/      #     Baseline + Restricted policies
│   ├── network-policies/            #     Dev + Prod N8N policies
│   │   ├── dev/                     #     Testing ground für policies
│   │   └── prod/                    #     Proven security policies
│   └── rbac/                        #     Access control
├── kubernetes/platform/data/
│   ├── n8n-dev-cnpg/               # ✅ N8N Dev PostgreSQL
│   └── n8n-prod-cnpg/              # ✅ N8N Prod PostgreSQL
└── kubernetes/apps/base/n8n/
    ├── environments/dev/            # ✅ Clean N8N dev app
    └── environments/production/     # ✅ Clean N8N prod app
```

### 🚨 **Security Insights:**
- **Pod Security Standards Violations** entdeckt bei N8N:
  ```
  Warning: securityContext.capabilities.drop=["ALL"] missing
  Warning: securityContext.seccompProfile.type missing
  ```
- **Network Policies** - Dev→Prod testing pipeline geplant
- **Enterprise Security Layer** - kubernetes/security/ vorbereitet

### 📊 **Deployment Status:**
- **Applications**: 34/34 deployed ✅
- **N8N-dev**: PostgreSQL + App running ✅
- **N8N-prod**: PostgreSQL + App running ✅
- **Metrics Server**: ApplicationSet deployed (wird ready)

---

## Session 2025-09-21 Part 2: GitOps Security Architecture Planning

### 🔍 **Enterprise GitOps Research Results:**
- **ArgoCD Best Practice**: Security policies direkt in App-Overlays (nicht separate ApplicationSets)
- **Anti-Pattern**: Separate ApplicationSets für jede Policy-Kategorie
- **Recommended**: "Security as Code" - Security deployed mit Application

### 🏗️ **NEUE ARCHITEKTUR - GitOps Best Practice:**

#### **Apps ApplicationSet (erweitert um Platform):**
```yaml
# kubernetes/apps/applications.yaml
spec:
  template:
    spec:
      sources:
      - path: kubernetes/apps/overlays/{{values.environment}}/{{values.name}}
      - path: kubernetes/platform/security-platform    # Platform Security
      - path: kubernetes/platform/monitoring-platform  # Platform Monitoring
```

#### **🎯 VORTEILE:**
✅ **Kein neues ApplicationSet** - alles in Apps integriert
✅ **Platform Services sichtbar** in ArgoCD Apps
✅ **Raw YAML deployment** - einfach und direkt
✅ **Zentrale Platform Policies** - gelten für alle Apps

#### **📁 GEPLANTE STRUKTUR:**
```bash
kubernetes/
├── apps/overlays/prod/n8n/patches/
│   ├── prod-resources.yaml        # App scaling
│   ├── network-policy.yaml        # App-specific traffic rules
│   ├── pod-disruption-budget.yaml # App availability
│   └── hpa.yaml                   # App autoscaling
├── platform/
│   ├── security-platform/         # Raw YAML Platform Services
│   │   ├── kyverno-policies.yaml  # Policy engine
│   │   ├── resource-quotas.yaml   # Namespace limits
│   │   └── falco-config.yaml      # Runtime security
│   └── monitoring-platform/       # Raw YAML Monitoring
└── security/
    ├── COMPREHENSIVE_SECURITY.md  # Documentation only
    └── policy-templates/           # Templates für Apps
```

### 🤔 **OFFENE FRAGE:**
**Network Policies**: App-spezifisch (in Overlays) vs Platform-wide (in security-platform)?
- **App-spezifisch**: Jede App definiert eigene Network Policy
- **Platform-wide**: Zentrale Network Policies für alle Apps

### 🎯 **Nächste Session Priorities:**
1. **kubernetes/platform/security-platform** aufbauen (Raw YAML)
2. **Apps ApplicationSet** erweitern um Platform Sources
3. **Network Policies** Strategie entscheiden (App vs Platform)
4. **Resource Quotas** + **PodDisruptionBudgets** implementieren

### 💡 **Key Learnings:**
- **GitOps Best Practice**: Security bei Apps, Platform Services zentral
- **ArgoCD UI stays clean**: Keine separaten Security ApplicationSets
- **Enterprise Pattern**: Apps + Platform in einem ApplicationSet
- **Raw YAML Platform Services**: Einfacher als separate Applications