# Observability Documentation Index

## 📚 Dokumentations-Übersicht

Alle Markdown Dateien organisiert nach Relevanz und Aktualität.

---

## ⭐ START HIER (Wichtigste Docs)

### 1. **ELASTICSEARCH-COMPLETE-GUIDE.md**
**Was ist das?** Vollständige Elasticsearch Erklärung
**Wann lesen?** Wenn du verstehen willst:
- Was ist Elasticsearch?
- Was sind Data Streams vs Indices?
- Wie pflege ich den Cluster?
- Warum nutzen wir Data Streams?

**Themen:**
- ✅ Elasticsearch Basics (Index, Document, Shard, Mapping)
- ✅ Data Streams Konzept mit Diagrammen
- ✅ ILM (Index Lifecycle Management)
- ✅ Cluster Pflege (Monitoring, Backup, Troubleshooting)
- ✅ Best Practices Check

---

### 2. **LOG-COLLECTOR-COMPARISON.md**
**Was ist das?** Vector vs Fluentd vs Fluent Bit Vergleich
**Wann lesen?** Wenn du wissen willst:
- Warum Vector statt Fluentd?
- Performance Benchmarks
- Wann sollte ich wechseln?

**Themen:**
- ✅ Performance Tests (Vector 20x schneller als Fluentd)
- ✅ Memory Vergleich (Vector nutzt 2.5x weniger RAM)
- ✅ Config Vergleich (TOML vs Ruby DSL vs Lua)
- ✅ Migration Guides

---

### 3. **VECTOR-LOG-SOURCES.md** (NEU!)
**Was ist das?** Alle möglichen Log-Quellen für Vector
**Wann lesen?** Wenn du wissen willst:
- Welche Server/Devices kann ich zu Vector senden?
- Wie konfiguriere ich Syslog von Ubuntu/OPNsense/etc?
- Kann ich Docker/Home Assistant/etc integrieren?

**Themen:**
- ✅ 12 verschiedene Source-Typen (Syslog, HTTP, Kafka, MQTT, etc.)
- ✅ Konkrete Homelab Use Cases (Ubuntu Server, OPNsense, Nginx, Docker)
- ✅ Multi-Source Setup Beispiel
- ✅ Service Exposure (LoadBalancer Ports)

---

## 🏗️ Architektur & Setup

### 4. **ENTERPRISE-LOGGING-100-PERCENT.md**
**Was ist das?** Komplette Logging-Architektur Dokumentation
**Wann lesen?** Wenn du die gesamte Architektur verstehen willst

**Themen:**
- ✅ 6-Stage Log Journey (Kubernetes → Vector → Elasticsearch → Kibana)
- ✅ Data Stream Naming Convention
- ✅ Tier-0 Service Routing
- ✅ ECS 8.17 Field Mapping
- ✅ Why This Architecture? (Research from Elastic docs)

**Status:** ⭐ AKTUELL - Beschreibt das aktuelle Setup

---

### 5. **vector/PROXMOX-SYSLOG-SETUP.md**
**Was ist das?** Proxmox Syslog Integration Guide
**Wann lesen?** Wenn du Proxmox Hosts zu Vector senden willst

**Themen:**
- ✅ Step-by-Step Setup für nipogi und minisforum
- ✅ rsyslog Config
- ✅ Troubleshooting
- ✅ Test Commands

**Status:** ✅ KOMPLETT - Proxmox Integration läuft

---

## 📖 Legacy/Archiv Docs (Optional)

### 6. **ENTERPRISE-LOGGING-GUIDE.md**
**Was ist das?** Alte Version der Logging-Architektur
**Status:** ⚠️ VERALTET - Ersetzt durch ENTERPRISE-LOGGING-100-PERCENT.md
**Wann lesen?** Nur zur historischen Referenz

---

### 7. **elasticsearch/EFK-Pipeline-Tutorial.md**
**Was ist das?** Tutorial für EFK Stack (Elasticsearch, Fluentd, Kibana)
**Status:** ⚠️ VERALTET - Wir nutzen Vector statt Fluentd
**Wann lesen?** Nur wenn du zu Fluentd wechseln willst

---

### 8. **elasticsearch/EFK_STACK_SETUP_GUIDE.md**
**Was ist das?** Setup Guide für EFK Stack
**Status:** ⚠️ VERALTET - Gleiche Info wie EFK-Pipeline-Tutorial
**Wann lesen?** Nur zur Referenz

---

### 9. **elasticsearch/ENTERPRISE_LOGGING_ARCHITECTURE.md**
**Was ist das?** Alte Architektur-Beschreibung
**Status:** ⚠️ VERALTET - Ersetzt durch ENTERPRISE-LOGGING-100-PERCENT.md
**Wann lesen?** Nur zur historischen Referenz

---

### 10. **vector/LOGGING_PLAN.md**
**Was ist das?** Alter Logging Plan
**Status:** ⚠️ VERALTET - Plan ist jetzt implementiert
**Wann lesen?** Nur zur historischen Referenz

---

## 📂 Andere READMEs

### 11. **README.md** (Root Observability)
**Was ist das?** Overview der Observability Tools
**Status:** ⚠️ BASIC - Nur kurze Übersicht
**Wann lesen?** Quick Overview

---

### 12. **elasticsearch/README.md**
**Was ist das?** Elasticsearch Ordner README
**Status:** ⚠️ BASIC - Nur kurze Übersicht
**Wann lesen?** Quick Overview

---

### 13. **elasticsearch/operator/charts/eck-operator-3.1.0/eck-operator/README.md**
**Was ist das?** ECK Operator Helm Chart README
**Status:** ℹ️ REFERENZ - Helm Chart Dokumentation
**Wann lesen?** Wenn du ECK Operator Optionen brauchst

---

## 🗂️ Empfohlene Lesereihenfolge

### Für Anfänger:
1. **ELASTICSEARCH-COMPLETE-GUIDE.md** - Verstehe Elasticsearch
2. **ENTERPRISE-LOGGING-100-PERCENT.md** - Verstehe die Architektur
3. **VECTOR-LOG-SOURCES.md** - Lerne wie du mehr Quellen hinzufügst

### Für Fortgeschrittene:
1. **LOG-COLLECTOR-COMPARISON.md** - Verstehe warum Vector
2. **VECTOR-LOG-SOURCES.md** - Erweitere dein Setup
3. **PROXMOX-SYSLOG-SETUP.md** - Spezifische Integration

### Für Troubleshooting:
1. **ELASTICSEARCH-COMPLETE-GUIDE.md** → Cluster Pflege Sektion
2. **PROXMOX-SYSLOG-SETUP.md** → Troubleshooting Sektion
3. Check Vector Logs: `kubectl logs -n elastic-system -l app.kubernetes.io/name=vector`

---

## 🧹 Cleanup Empfehlung

**Diese Dateien kannst du löschen (veraltet):**
- ❌ `ENTERPRISE-LOGGING-GUIDE.md` → Ersetzt durch ENTERPRISE-LOGGING-100-PERCENT.md
- ❌ `elasticsearch/EFK-Pipeline-Tutorial.md` → Wir nutzen Vector, nicht Fluentd
- ❌ `elasticsearch/EFK_STACK_SETUP_GUIDE.md` → Duplikat
- ❌ `elasticsearch/ENTERPRISE_LOGGING_ARCHITECTURE.md` → Ersetzt
- ❌ `vector/LOGGING_PLAN.md` → Plan ist implementiert

**Behalten:**
- ✅ `ELASTICSEARCH-COMPLETE-GUIDE.md` - Basis-Wissen
- ✅ `LOG-COLLECTOR-COMPARISON.md` - Entscheidungs-Hilfe
- ✅ `VECTOR-LOG-SOURCES.md` - Praktischer Guide
- ✅ `ENTERPRISE-LOGGING-100-PERCENT.md` - Architektur
- ✅ `vector/PROXMOX-SYSLOG-SETUP.md` - Spezifische Integration

---

## 📊 Quick Reference Table

| Frage | Antwort in... |
|-------|---------------|
| Was ist Elasticsearch? | ELASTICSEARCH-COMPLETE-GUIDE.md |
| Warum Data Streams? | ELASTICSEARCH-COMPLETE-GUIDE.md → Data Streams Sektion |
| Warum Vector statt Fluentd? | LOG-COLLECTOR-COMPARISON.md |
| Wie füge ich Ubuntu Server hinzu? | VECTOR-LOG-SOURCES.md → Use Case 1 |
| Wie füge ich OPNsense hinzu? | VECTOR-LOG-SOURCES.md → Use Case 2 |
| Wie pflege ich Elasticsearch? | ELASTICSEARCH-COMPLETE-GUIDE.md → Cluster Pflege |
| Wie funktioniert ILM? | ELASTICSEARCH-COMPLETE-GUIDE.md → ILM Sektion |
| Was sind die Best Practices? | ENTERPRISE-LOGGING-100-PERCENT.md → Key Decisions |
| Wie migriere ich zu Fluentd? | LOG-COLLECTOR-COMPARISON.md → Migration Guide |

---

## 🔗 Externe Links

- [Vector Documentation](https://vector.dev/docs/)
- [Elasticsearch Data Streams](https://www.elastic.co/guide/en/elasticsearch/reference/current/data-streams.html)
- [ECS Field Reference](https://www.elastic.co/guide/en/ecs/current/ecs-field-reference.html)
- [Talos Homelab GitHub](https://github.com/Tim275/talos-homelab)

---

**Letzte Aktualisierung:** 2025-10-19
**Autor:** Claude + Tim275
**Cluster:** Talos Homelab
