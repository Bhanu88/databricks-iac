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

# Databricks account-level provider for Unity Catalog metastore.
# The accounts host (accounts.azuredatabricks.net) is cloud-agnostic — the same
# URL serves AWS, Azure, and GCP accounts, so the provider cannot infer the cloud
# from the host alone.  Without azure_tenant_id the provider never enters the
# Azure auth code-path and raises "Failed to retrieve tenant ID for given token"
# when OIDC is in use.  ARM_TENANT_ID (consumed by azurerm) is NOT forwarded
# automatically; we must set azure_tenant_id explicitly here.
provider "databricks" {
  alias           = "account"
  host            = "https://accounts.azuredatabricks.net"
  account_id      = var.databricks_account_id
  azure_tenant_id = var.azure_tenant_id
}
