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
}

module "rook_external" {
  depends_on = [module.talos]
  source     = "../../modules/rook-external"

  providers = {
    kubernetes = kubernetes
  }

  values = var.rook_external
}

removed {
  from = module.openbao.kubernetes_secret_v1.seal_key

  lifecycle {
    destroy = false
  }
}
