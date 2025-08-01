talos_cluster_config = {
  name            = "homelab-k8s"
  endpoint        = "192.168.68.101"  # First control plane IP (ctrl-00)
  gateway         = "192.168.68.1"
  subnet_mask     = "24"
  talos_version   = "v1.10"
  proxmox_cluster = "homelab"
  gateway_api_version = "v1.3.0"
  extra_manifests = []
  api_server      = ""
  cilium = {
    bootstrap_manifest_path = "talos/inline-manifests/cilium-bootstrap.yaml"
    values_file_path       = "talos/inline-manifests/cilium-values.yaml"
  }
}