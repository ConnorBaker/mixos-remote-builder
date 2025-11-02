terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # version = "~> 4.4"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  use_cli         = true
  features {}
}

resource "azurerm_resource_group" "mixos_rg" {
  location = var.location
  name     = "mixos_rg"
}
