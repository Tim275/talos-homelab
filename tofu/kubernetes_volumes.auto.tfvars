kubernetes_volumes = {
  "argocd-data" = {
    node    = "homelab"
    size    = "10G"
    storage = "local-zfs"
  }
  "prometheus-data" = {
    node    = "homelab"
    size    = "20G"
    storage = "local-zfs"
  }
  "grafana-data" = {
    node    = "homelab"
    size    = "5G"
    storage = "local-zfs"
  }
  "storage-loki-0" = {
    node    = "homelab"
    size    = "10G"
    storage = "local-zfs"
  }
  "storage-monitoring-stack-alertmanager-0" = {
    node    = "homelab"
    size    = "5G"
    storage = "local-zfs"
  }
}