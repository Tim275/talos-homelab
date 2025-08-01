terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.5.0" # renovate: terraform=siderolabs/talos
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.61.1" # renovate: terraform=bpg/proxmox
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0" # renovate: terraform=hashicorp/kubernetes
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "1.19.1" # renovate: terraform=Mastercard/restapi
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.endpoint
  insecure = var.proxmox.insecure

  api_token = var.proxmox.api_token
  ssh {
    agent    = true
    username = var.proxmox.username
  }
}

provider "kubernetes" {
  host                   = module.talos.kube_config.kubernetes_client_configuration.host
  client_certificate     = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
}

provider "restapi" {
  uri                  = var.proxmox.endpoint
  insecure             = var.proxmox.insecure
  write_returns_object = true

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "PVEAPIToken=${var.proxmox.api_token}"
  }
}