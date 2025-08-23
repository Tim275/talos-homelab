locals {
  first_control_plane_node_ip = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  kubernetes_endpoint         = coalesce(var.cluster.endpoint, local.first_control_plane_node_ip)
  extra_manifests = concat(var.cluster.extra_manifests, [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster.gateway_api_version}/standard-install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${var.cluster.gateway_api_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml"
  ])
}

resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

resource "terraform_data" "cilium_bootstrap_inline_manifests" {
  input = [
    {
      name     = "cilium-bootstrap"
      contents = file("${path.root}/${var.cluster.cilium.bootstrap_manifest_path}")
    },
    {
      name = "cilium-values"
      contents = yamlencode({
        apiVersion = "v1"
        kind       = "ConfigMap"
        metadata = {
          name      = "cilium-values"
          namespace = "kube-system"
        }
        data = {
          "values.yaml" = file("${path.root}/${var.cluster.cilium.values_file_path}")
        }
      })
    }
  ]
}

data "talos_machine_configuration" "this" {
  for_each     = var.nodes
  cluster_name = var.cluster.name
  cluster_endpoint = "https://${local.kubernetes_endpoint}:6443"
  talos_version = var.image.talos_machine_config_version != null ? var.image.talos_machine_config_version : (each.value.update == true ? var.image.update_version : var.image.version)
  machine_type    = each.value.machine_type
  machine_secrets = talos_machine_secrets.this.machine_secrets
  config_patches = [
    # Common configuration for ALL nodes (following @vehagn's pattern)
    templatefile("${path.module}/machine-config/common.yaml.tftpl", {
      hostname     = each.key
      cluster_name = var.cluster.proxmox_cluster
      node_name    = each.value.host_node
    }),
    # Node-type specific configuration
    each.value.machine_type == "controlplane" ?
    templatefile("${path.module}/machine-config/control-plane.yaml.tftpl", {
      hostname       = each.key
      cluster_name   = var.cluster.proxmox_cluster  
      node_name      = each.value.host_node
      ip             = each.value.ip
      mac_address    = lower(each.value.mac_address)
      gateway        = var.cluster.gateway
      subnet_mask    = var.cluster.subnet_mask
      vip              = var.cluster.endpoint
      extra_manifests  = jsonencode(local.extra_manifests)
      inline_manifests = jsonencode(terraform_data.cilium_bootstrap_inline_manifests.output)
    }) :
    templatefile("${path.module}/machine-config/worker.yaml.tftpl", {
      hostname     = each.key
      cluster_name = var.cluster.proxmox_cluster
      node_name    = each.value.host_node
      ip           = each.value.ip
      mac_address  = lower(each.value.mac_address)
      gateway      = var.cluster.gateway
      subnet_mask  = var.cluster.subnet_mask
    })
  ]
}

resource "talos_machine_configuration_apply" "this" {
  depends_on                  = [proxmox_virtual_environment_vm.this]
  for_each                    = var.nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  
  
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]
  node                 = local.first_control_plane_node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]
  client_configuration   = data.talos_client_configuration.this.client_configuration
  control_plane_nodes    = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
  worker_nodes           = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  endpoints              = data.talos_client_configuration.this.endpoints
  timeouts = {
    read = "20m"
  }
}

data "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  node                 = local.first_control_plane_node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
  timeouts = {
    read = "5m"
  }
}