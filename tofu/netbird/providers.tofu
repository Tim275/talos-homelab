terraform {
  # SEPARATER State-Key — voll isoliert vom Cluster (talos-homelab.tfstate).
  # tofu apply hier kann die Talos-VMs NIE anfassen.
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "tofustatehomelab"
    container_name       = "tfstate"
    key                  = "netbird.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    subscription_id      = "72c89487-4bc9-4c91-a0f7-0cc51fc89336"
  }

  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "~> 0.0.9"
    }
  }
}

provider "netbird" {
  token = var.netbird_api_token
  # Cloud-Default: https://api.netbird.io. Self-hosted: eigene URL setzen.
  management_url = var.netbird_management_url
}
