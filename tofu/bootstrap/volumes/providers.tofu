terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 1.19.1"
    }
  }
}