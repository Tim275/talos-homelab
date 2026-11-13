talos_cluster_config = {
  name                          = "homelab-k8s"
  vip                           = "192.168.0.100" # VIP managed by kube-vip
  gateway                       = "192.168.0.1"
  subnet_mask                   = "24"
  talos_machine_config_version  = "v1.14.6" # renovate: github-releases=siderolabs/talos
  proxmox_cluster               = "homelab"
  kubernetes_version            = "v1.37.2" # renovate: docker=registry.k8s.io/kube-apiserver
  gateway_api_version           = "v1.7.0"
  kube_prometheus_stack_version = "93.3.0" # renovate: helm=kube-prometheus-stack registry=https://prometheus-community.github.io/helm-charts
  extra_manifests               = []
  kubelet                       = ""
  api_server                    = ""
  cilium = {
    bootstrap_manifest_path = "../../modules/talos/inline-manifests/cilium-bootstrap.yaml"
    values_file_path        = "../../modules/talos/inline-manifests/cilium-values.yaml"
  }
}