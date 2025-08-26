kubernetes_volumes = {
  "argocd-data" = {
    node = "homelab"
    size = "10G"
  }
  "prometheus-data" = {
    node = "homelab"
    size = "20G"
  }
  "grafana-data" = {
    node = "homelab"
    size = "5G"
  }
  "storage-loki-0" = {
    node = "homelab"
    size = "10G"
  }
  "storage-monitoring-stack-alertmanager-0" = {
    node = "homelab"
    size = "5G"
  }
}