terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.1.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.60.0"
    }
  }
}