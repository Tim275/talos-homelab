terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.73"
    }
  }
}

provider "azurerm" {
  features {}
}
