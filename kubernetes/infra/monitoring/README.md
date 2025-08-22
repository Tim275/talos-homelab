# Monitoring Stack

Production-ready monitoring for Talos Kubernetes cluster with Prometheus, Grafana, and Loki.

## Essential Grafana Dashboards

Import these dashboard IDs in Grafana for complete cluster monitoring:

### Core Monitoring (Required)
- **15757** - Talos Linux Dashboard (Cluster Health, Node Status)
- **15661** - Kubernetes Cluster Overview (Pods, Services, Resources)  
- **1860** - Node Exporter Full (CPU, Memory, Disk, Network)
- **12019** - Loki Dashboard quick search (Logs from all nodes)

### Additional Dashboards (Optional)
- **13639** - Logs App (Alternative log viewer)
- **11074** - Node Exporter for Prometheus Dashboard
- **15758** - Kubernetes cluster monitoring (via Prometheus)

## How to Import

1. Go to Grafana → Dashboards → Import
2. Enter the dashboard ID (e.g., `15757`)
3. Click "Load"
4. Select datasources:
   - **Prometheus**: `Prometheus`
   - **Loki**: `Loki` 
   - **Alertmanager**: `Alertmanager`

## Components

- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation and search
- **Promtail** - Log collection agent (DaemonSet)
- **Alertmanager** - Alert routing and notifications

## Log Queries

Use these LogQL queries in Grafana Explore:

```logql
# All cluster logs
{namespace=~"kube-system|monitoring"}

# Talos system logs
{namespace="kube-system"} |= "talos"

# Error logs only
{namespace=~".*"} |= "error" or "ERROR"

# Specific pod logs
{namespace="monitoring", pod=~"prometheus.*"}
```