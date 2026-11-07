output "client_configuration" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "kube_config" {
  value     = talos_cluster_kubeconfig.this
  sensitive = true
}

output "etcd_client_cert" {
  value = {
    ca   = base64decode(talos_machine_secrets.this.machine_secrets.certs.etcd.cert)
    cert = base64decode(talos_machine_secrets.this.machine_secrets.certs.etcd.cert)
    key  = base64decode(talos_machine_secrets.this.machine_secrets.certs.etcd.key)
  }
  sensitive = true
}

output "machine_config" {
  value = data.talos_machine_configuration.this
}