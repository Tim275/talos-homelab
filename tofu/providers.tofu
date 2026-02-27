terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.1"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "2.0.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.endpoint
  insecure = var.proxmox.insecure

  api_token = var.proxmox_api_token

  ssh {
    agent       = false
    username    = "root"
    private_key = file(pathexpand("~/.ssh/id_rsa_proxmox"))
  }
}

provider "kubernetes" {
  # Use existing kubeconfig file to avoid circular dependency during import
  config_path = "${path.module}/output/kube-config.yaml"
}

provider "restapi" {
  uri                  = var.proxmox.endpoint
  insecure             = var.proxmox.insecure
  write_returns_object = true

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "PVEAPIToken=${var.proxmox_api_token}"
  }
}