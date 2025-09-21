# Claude Notes

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

### 🎯 **Nächste Session Priorities:**
1. **kubernetes/security** implementieren
2. **Network Policies** für N8N (dev→prod testing)
3. **Pod Security Standards** cluster-wide
4. **Enterprise Security Compliance** für alle 34 apps

### 💡 **Key Learnings:**
- **Manual fixes don't scale** - Platform patterns essential
- **Dev environment = Security testing ground**
- **Enterprise compliance** requires systematic approach
- **Layer separation critical** für maintainability