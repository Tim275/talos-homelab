output "client_configuration" {
  description = "Talos client configuration for talosctl"
  value       = data.talos_client_configuration.this
  sensitive   = true
}

output "kube_config" {
  description = "Kubernetes configuration for kubectl"
  value       = data.talos_cluster_kubeconfig.this
  sensitive   = true
}

output "machine_config" {
  description = "Generated machine configurations for all nodes"
  value       = data.talos_machine_configuration.this
  sensitive   = true
}

output "cluster_health" {
  description = "Cluster health status"
  value       = data.talos_cluster_health.this
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = var.cluster.endpoint
}

output "node_ips" {
  description = "IP addresses of all nodes"
  value = {
    control_plane = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
    workers       = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  }
}
