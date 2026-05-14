talos_cluster_config = {
  name                         = "homelab-k8s"
  vip                          = "192.168.0.100"  # VIP managed by kube-vip
  gateway                      = "192.168.0.1"
  subnet_mask                  = "24"
  talos_machine_config_version = "v1.13.2"  # DO NOT change via Renovate - manual upgrade only (talosctl upgrade)
  proxmox_cluster              = "homelab"
  kubernetes_version           = "1.36.1"  # DO NOT change via Renovate - manual upgrade only (talosctl upgrade-k8s)
  gateway_api_version          = "v1.3.0"
  extra_manifests              = []
  kubelet                      = ""
  api_server                   = ""
  cilium = {
    bootstrap_manifest_path = "talos/inline-manifests/cilium-bootstrap.yaml"
    values_file_path       = "talos/inline-manifests/cilium-values.yaml"
  }
}