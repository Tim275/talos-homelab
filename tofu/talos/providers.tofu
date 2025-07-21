terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.60.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">=3.4.0"
    }
  }
}