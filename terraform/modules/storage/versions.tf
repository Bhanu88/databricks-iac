terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
