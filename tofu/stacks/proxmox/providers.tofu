terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "tofustatehomelab"
    container_name       = "tfstate"
    key                  = "proxmox.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    subscription_id      = "72c89487-4bc9-4c91-a0f7-0cc51fc89336"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.120.0"
    }
  }
}

# PROXMOX_VE_API_TOKEN (iac_token), nur beim allerersten apply root@pam per Passwort
provider "proxmox" {
  endpoint = "https://192.168.0.50:8006/"
  insecure = true
}
