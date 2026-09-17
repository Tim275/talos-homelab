terraform {
  # Separater State-Key — isoliert vom Cluster, kann Talos-VMs nie anfassen
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "tofustatehomelab"
    container_name       = "tfstate"
    key                  = "uptimerobot.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    subscription_id      = "72c89487-4bc9-4c91-a0f7-0cc51fc89336"
  }

  required_providers {
    uptimerobot = {
      source  = "uptimerobot/uptimerobot"
      version = "~> 1.11"
    }
  }
}

provider "uptimerobot" {
  api_key = var.uptimerobot_api_key
}
