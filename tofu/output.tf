resource "local_file" "talos_config" {
  content         = module.talos.client_configuration.talos_config
  filename        = "output/talos-config.yaml"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  content         = module.talos.kube_config.kubeconfig_raw
  filename        = "output/kube-config.yaml"
  file_permission = "0600"
}

output "kube_config" {
  description = "Kubernetes configuration for kubectl"
  value       = module.talos.kube_config.kubeconfig_raw
  sensitive   = true
}

output "talos_config" {
  description = "Talos client configuration for talosctl"
  value       = module.talos.client_configuration.talos_config
  sensitive   = true
}

output "cluster_info" {
  description = "Cluster information"
  value = {
    endpoint = module.talos.cluster_endpoint
    nodes    = module.talos.node_ips
  }
}

output "machine_configs" {
  description = "Machine configurations for all nodes"
  value       = module.talos.machine_config
  sensitive   = true
}
