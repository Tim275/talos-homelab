terraform {
  # Eigener State-Key — hat mit Talos/Cluster nichts zu tun
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "tofustatehomelab"
    container_name       = "tfstate"
    key                  = "uptime-kuma.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    subscription_id      = "72c89487-4bc9-4c91-a0f7-0cc51fc89336"
  }

  required_providers {
    uptimekuma = {
      source  = "breml/uptimekuma"
      version = "~> 0.4"
    }
  }
}

provider "uptimekuma" {
  endpoint = var.uptime_kuma_url
  username = var.uptime_kuma_username
  password = var.uptime_kuma_password
}
