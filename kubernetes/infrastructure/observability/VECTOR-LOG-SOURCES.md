# Vector Log Sources - Alle Möglichkeiten

## 📚 Übersicht

Vector kann Logs von **VIELEN verschiedenen Quellen** empfangen. Hier ist die komplette Liste für dein Homelab.

---

## Aktuell konfiguriert ✅

| Quelle | Typ | Port | Status |
|--------|-----|------|--------|
| **Kubernetes Pods** | Vector Protocol | 6000 | ✅ AKTIV |
| **Proxmox (nipogi)** | Syslog UDP | 514 | ✅ AKTIV |
| **Proxmox (msa2proxmox)** | Syslog UDP | 514 | ✅ AKTIV |

---

## Möglich: Weitere Server/Services

### 1. Syslog (UDP/TCP) - Universal

**Use Case:** Jeder Linux Server, Router, Firewall

```toml
# In vector-aggregator.toml
[sources.generic_syslog]
type = "syslog"
address = "0.0.0.0:514"
mode = "udp"  # oder "tcp"
```

**Konfiguration auf dem Server:**
```bash
# /etc/rsyslog.d/50-vector.conf
*.* @192.168.68.151:514  # UDP
# ODER
*.* @@192.168.68.151:514  # TCP
```

**Beispiele:**
- ✅ Ubuntu Server
- ✅ Debian Server
- ✅ CentOS/RHEL
- ✅ OPNsense/pfSense (Router)
- ✅ UniFi Controller
- ✅ Docker Host (außerhalb Kubernetes)

---

### 2. Journald (systemd logs)

**Use Case:** Direkt systemd Journal von Servern

```toml
[sources.journald]
type = "journald"
journal_directory = "/var/log/journal"
```

**Anwendung:**
- Talos Nodes (falls du direkt auf Nodes zugreifst)
- Ubuntu/Debian Server mit systemd

---

### 3. File Tailing (Log-Dateien)

**Use Case:** Lese spezifische Log-Dateien

```toml
[sources.nginx_access_logs]
type = "file"
include = ["/var/log/nginx/access.log"]
read_from = "end"
```

**Beispiele:**
- ✅ Nginx Access Logs
- ✅ Apache Logs
- ✅ Custom Application Logs
- ✅ MySQL Slow Query Logs
- ✅ PostgreSQL Logs

---

### 4. HTTP/HTTPS (Webhook)

**Use Case:** Apps die Logs per HTTP POST senden

```toml
[sources.http_logs]
type = "http_server"
address = "0.0.0.0:8080"
encoding = "json"
```

**Beispiele:**
- ✅ Webhooks von GitHub/GitLab
- ✅ Custom Apps mit HTTP Logging
- ✅ AWS Lambda Logs (via HTTP)

---

### 5. Kafka (Streaming)

**Use Case:** Logs aus Kafka Topics

```toml
[sources.kafka_logs]
type = "kafka"
bootstrap_servers = "my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
topics = ["application-logs"]
group_id = "vector-consumer"
```

**Anwendung:**
- ✅ Wenn du bereits Kafka nutzt (du hast Strimzi!)
- ✅ High-throughput Applications
- ✅ Event-Driven Architecture

---

### 6. Docker Logs (Socket)

**Use Case:** Docker Container außerhalb Kubernetes

```toml
[sources.docker_logs]
type = "docker_logs"
docker_host = "unix:///var/run/docker.sock"
```

**Beispiele:**
- ✅ Standalone Docker Hosts
- ✅ Docker Compose Stacks
- ✅ Portainer Containers

---

### 7. Exec (Command Output)

**Use Case:** Führe Command aus und parse Output

```toml
[sources.custom_command]
type = "exec"
mode = "scheduled"
command = ["bash", "-c", "echo 'Custom log message'"]
scheduled.exec_interval_secs = 60
```

**Beispiele:**
- ✅ Script Output
- ✅ Database Queries (MySQL/PostgreSQL CLI)
- ✅ Custom Monitoring Scripts

---

### 8. AWS CloudWatch Logs

**Use Case:** Logs von AWS Services

```toml
[sources.cloudwatch_logs]
type = "aws_cloudwatch_logs"
region = "eu-central-1"
group_name = "/aws/lambda/my-function"
```

**Beispiele:**
- ✅ AWS Lambda
- ✅ ECS/Fargate
- ✅ RDS Logs

---

### 9. Prometheus Exporter Logs

**Use Case:** Logs von Prometheus Exporters

```toml
[sources.prometheus_scrape]
type = "prometheus_scrape"
endpoints = ["http://node-exporter:9100/metrics"]
scrape_interval_secs = 15
```

**Beispiele:**
- ✅ Node Exporter
- ✅ Blackbox Exporter
- ✅ Custom Exporters

---

### 10. MQTT (IoT)

**Use Case:** IoT Devices via MQTT

```toml
[sources.mqtt_logs]
type = "mqtt"
host = "mqtt.example.com"
port = 1883
topics = ["sensors/#"]
```

**Beispiele:**
- ✅ IoT Sensors
- ✅ Home Assistant
- ✅ Zigbee/Z-Wave Devices

---

### 11. Statsd/Dogstatsd (Metrics → Logs)

**Use Case:** Metrics als Logs speichern

```toml
[sources.statsd]
type = "statsd"
address = "0.0.0.0:8125"
mode = "udp"
```

**Beispiele:**
- ✅ Application Metrics
- ✅ Custom Counters/Gauges

---

### 12. Windows Event Logs

**Use Case:** Windows Server Logs

```toml
[sources.windows_events]
type = "windows_event_log"
channels = ["Application", "System", "Security"]
```

**Beispiele:**
- ✅ Windows Server
- ✅ Active Directory Events

---

## Konkrete Homelab Use Cases

### Use Case 1: Standalone Ubuntu Server

**Szenario:** Du hast einen Ubuntu Server außerhalb Kubernetes.

**Lösung:**
```bash
# Auf dem Ubuntu Server
echo "*.* @192.168.68.151:514" > /etc/rsyslog.d/50-vector.conf
systemctl restart rsyslog
```

**Vector Config:**
```toml
[sources.ubuntu_servers]
type = "syslog"
address = "0.0.0.0:515"  # Anderer Port als Proxmox
mode = "udp"
tag = "ubuntu-server"

[transforms.enrich_ubuntu]
type = "remap"
inputs = ["ubuntu_servers"]
source = '''
.source = "ubuntu-server"
.namespace_suffix = .hostname
'''
```

**Data Stream:** `logs-ubuntu-server.info-<hostname>`

---

### Use Case 2: OPNsense/pfSense Firewall

**Szenario:** Router/Firewall Logs zu Vector senden.

**Lösung:**
1. OPNsense UI: **System → Settings → Logging/Targets**
2. Add Remote Syslog: `192.168.68.151:514`

**Vector Config:**
```toml
[sources.firewall_logs]
type = "syslog"
address = "0.0.0.0:516"  # Dedizierter Port
mode = "udp"
tag = "firewall"

[transforms.enrich_firewall]
type = "remap"
inputs = ["firewall_logs"]
source = '''
.source = "opnsense"
.namespace_suffix = "firewall"
.service_name = "firewall"
'''
```

**Data Stream:** `logs-firewall.warn-firewall`

---

### Use Case 3: Nginx Reverse Proxy (außerhalb K8s)

**Szenario:** Nginx auf separatem Server.

**Lösung:**
```bash
# Install Vector Agent auf dem Nginx Server
curl -1sLf 'https://repositories.timber.io/public/vector/setup.deb.sh' | sudo bash
sudo apt install vector

# /etc/vector/vector.toml
[sources.nginx_access]
type = "file"
include = ["/var/log/nginx/access.log"]

[sources.nginx_error]
type = "file"
include = ["/var/log/nginx/error.log"]

[sinks.to_aggregator]
type = "vector"
inputs = ["nginx_access", "nginx_error"]
address = "192.168.68.151:6000"
```

**Data Stream:** `logs-nginx.info-nginx-host`

---

### Use Case 4: Docker Compose Stack

**Szenario:** Docker Compose außerhalb Kubernetes.

**Lösung:**
```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    image: myapp:latest
    logging:
      driver: syslog
      options:
        syslog-address: "udp://192.168.68.151:514"
        tag: "myapp"
```

**Data Stream:** `logs-docker.info-myapp`

---

### Use Case 5: Home Assistant

**Szenario:** Home Assistant Logs zu Vector.

**Lösung:**
```yaml
# configuration.yaml
logger:
  default: info
  logs:
    homeassistant.core: debug

# Vector Integration via syslog
system_log:
  fire_event: true

automation:
  - alias: Send logs to Vector
    trigger:
      platform: event
      event_type: system_log_event
    action:
      service: notify.syslog
      data:
        message: "{{ trigger.event.data.message }}"
```

---

### Use Case 6: UniFi Controller

**Szenario:** UniFi Logs zu Vector.

**Lösung:**
```bash
# SSH zu UniFi Controller
ssh ubnt@unifi-controller

# Configure syslog
echo "*.* @192.168.68.151:514" >> /etc/rsyslog.conf
service rsyslog restart
```

**Data Stream:** `logs-unifi.info-unifi-controller`

---

## Komplettes Beispiel: Multi-Source Setup

```toml
# vector-aggregator.toml

# ═══════════════════════════════════════════════════════════════
# SOURCES - Multiple Inputs
# ═══════════════════════════════════════════════════════════════

# 1. Kubernetes Pods
[sources.kubernetes_logs]
type = "vector"
address = "0.0.0.0:6000"

# 2. Proxmox Hosts
[sources.proxmox_syslog]
type = "syslog"
address = "0.0.0.0:514"
mode = "udp"

# 3. Ubuntu Servers
[sources.ubuntu_servers]
type = "syslog"
address = "0.0.0.0:515"
mode = "udp"

# 4. Firewall (OPNsense)
[sources.firewall_logs]
type = "syslog"
address = "0.0.0.0:516"
mode = "udp"

# 5. Nginx Servers
[sources.nginx_logs]
type = "vector"
address = "0.0.0.0:6001"

# 6. Docker Compose
[sources.docker_logs]
type = "syslog"
address = "0.0.0.0:517"
mode = "udp"

# 7. Home Assistant
[sources.homeassistant]
type = "syslog"
address = "0.0.0.0:518"
mode = "udp"

# ═══════════════════════════════════════════════════════════════
# TRANSFORMS - Tag and Route
# ═══════════════════════════════════════════════════════════════

[transforms.enrich_all]
type = "remap"
inputs = [
  "kubernetes_logs",
  "proxmox_syslog",
  "ubuntu_servers",
  "firewall_logs",
  "nginx_logs",
  "docker_logs",
  "homeassistant"
]
source = '''
# Detect source type
.source_type = if exists(.kubernetes) {
  "kubernetes"
} else if contains(string!(.hostname), "pve") {
  "proxmox"
} else if contains(string!(.hostname), "ubuntu") {
  "ubuntu-server"
} else if contains(string!(.message), "firewall") {
  "firewall"
} else if contains(string!(.message), "nginx") {
  "nginx"
} else if contains(string!(.appname), "docker") {
  "docker"
} else if contains(string!(.hostname), "homeassistant") {
  "homeassistant"
} else {
  "unknown"
}

# Set service_name
.service_name = .source_type

# Set namespace_suffix
.namespace_suffix = .hostname || "default"
'''

# ═══════════════════════════════════════════════════════════════
# SINK - Elasticsearch Data Streams
# ═══════════════════════════════════════════════════════════════

[sinks.elasticsearch]
type = "elasticsearch"
inputs = ["enrich_all"]
mode = "data_stream"
data_stream.type = "logs"
data_stream.dataset = "{{ service_name }}.{{ severity }}"
data_stream.namespace = "{{ namespace_suffix }}"
```

---

## Service Exposure (LoadBalancer)

**Aktuell:**
- Port 514: Proxmox Syslog

**Erweitert:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: vector-multi-syslog-lb
  namespace: elastic-system
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: vector
    app.kubernetes.io/component: aggregator
  ports:
  - name: proxmox-syslog
    port: 514
    targetPort: 5140
    protocol: UDP
  - name: ubuntu-syslog
    port: 515
    targetPort: 5150
    protocol: UDP
  - name: firewall-syslog
    port: 516
    targetPort: 5160
    protocol: UDP
  - name: docker-syslog
    port: 517
    targetPort: 5170
    protocol: UDP
  - name: homeassistant-syslog
    port: 518
    targetPort: 5180
    protocol: UDP
```

---

## Zusammenfassung

### ✅ **Vector kann empfangen von:**

| Quelle | Protokoll | Komplexität |
|--------|-----------|-------------|
| Kubernetes Pods | Vector Protocol (gRPC) | ⭐ Einfach (schon aktiv) |
| Proxmox | Syslog UDP | ⭐ Einfach (schon aktiv) |
| Linux Server | Syslog UDP/TCP | ⭐ Einfach |
| Firewall (OPNsense) | Syslog UDP | ⭐ Einfach |
| Nginx | File Tailing | ⭐⭐ Mittel |
| Docker Compose | Syslog Driver | ⭐ Einfach |
| Home Assistant | Syslog | ⭐⭐ Mittel |
| Kafka | Kafka Consumer | ⭐⭐⭐ Komplex |
| AWS CloudWatch | AWS API | ⭐⭐⭐ Komplex |
| Windows Server | Event Log | ⭐⭐⭐ Komplex |

### 🎯 **Empfehlung für Homelab:**

**Einfach hinzufügen:**
1. ✅ **Linux Server** → Syslog UDP (wie Proxmox)
2. ✅ **OPNsense/pfSense** → Syslog UDP
3. ✅ **Docker Compose** → Syslog Driver

**Fortgeschritten:**
4. ⚠️ **Nginx/Apache** → Vector Agent mit File Tailing
5. ⚠️ **Home Assistant** → Syslog oder HTTP Webhook

**Nur wenn nötig:**
6. ❌ **Kafka** → Nur wenn du bereits Kafka für andere Zwecke nutzt
7. ❌ **AWS CloudWatch** → Nur wenn du AWS Services hast

---

**Erstellt für:** Talos Homelab
**Datum:** 2025-10-19
**Vector Version:** 0.43 (nightly)
