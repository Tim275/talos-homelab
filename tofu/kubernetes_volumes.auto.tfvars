kubernetes_volumes = {
  "argocd-data" = {
    node = "nipogi"
    size = "10G"
  }
  "prometheus-data" = {
    node = "nipogi"
    size = "20G"
  }
  "grafana-data" = {
    node = "nipogi"
    size = "5G"
  }
  "storage-loki-0" = {
    node = "msa2proxmox"
    size = "10G"
  }
  "storage-monitoring-stack-alertmanager-0" = {
    node = "msa2proxmox"
    size = "5G"
  }
  "velero-backup-data" = {
    node = "msa2proxmox"
    size = "20G"
  }
}