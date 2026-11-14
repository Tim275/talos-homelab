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

data "terraform_remote_state" "unseal" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "tofustatehomelab"
    container_name       = "tfstate"
    key                  = "unseal.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    subscription_id      = "72c89487-4bc9-4c91-a0f7-0cc51fc89336"
  }
}

module "openbao" {
  depends_on = [module.talos]
  source     = "../../modules/openbao"

  providers = {
    kubernetes = kubernetes
  }

  unseal = data.terraform_remote_state.unseal.outputs.credentials
  values = var.openbao_bootstrap_values
}

module "rook_external" {
  depends_on = [module.talos]
  source     = "../../modules/rook-external"

  providers = {
    kubernetes = kubernetes
  }

  values = var.rook_external
}
