module "talos" {
  source = "../../modules/talos"

  providers = {
    proxmox = proxmox
  }

  image               = var.talos_image
  cluster             = var.talos_cluster_config
  nodes               = var.talos_nodes
  skip_cluster_health = var.skip_cluster_health
}

module "openbao" {
  depends_on = [module.talos]
  source     = "../../modules/openbao"

  providers = {
    kubernetes = kubernetes
  }

  seal             = var.openbao_seal_config
  values           = var.openbao_bootstrap_values
  etcd_client_cert = module.talos.etcd_client_cert
}

module "proxmox_csi_plugin" {
  depends_on = [module.talos]
  source     = "../../modules/proxmox-csi-plugin"

  providers = {
    proxmox    = proxmox
    kubernetes = kubernetes
  }

  proxmox           = var.proxmox
  proxmox_api_token = var.proxmox_api_token
}
