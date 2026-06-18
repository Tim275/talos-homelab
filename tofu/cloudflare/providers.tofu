terraform {
  # Eigener State — isoliert vom Cluster + von NetBird (Blast-Radius-Trennung).
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "tofustatehomelab"
    container_name       = "tfstate"
    key                  = "cloudflare.tfstate"
    use_azuread_auth     = true
    subscription_id      = "72c89487-4bc9-4c91-a0f7-0cc51fc89336"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.19.1"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
