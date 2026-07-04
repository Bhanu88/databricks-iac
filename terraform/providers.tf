terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.38"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend is configured per environment via -backend-config or backend.tf
  backend "azurerm" {}
}

# Azure provider – authenticates via service principal env vars or workload identity
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Databricks provider – workspace-level operations
# Authenticates using the workspace URL + AAD token (set ARM_CLIENT_ID etc.)
provider "databricks" {
  host = module.workspace.workspace_url

  # When running in CI with a service principal:
  # azure_client_id     = var.azure_client_id
  # azure_client_secret = var.azure_client_secret
  # azure_tenant_id     = var.azure_tenant_id
}

# Databricks account-level provider for Unity Catalog metastore
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
}
