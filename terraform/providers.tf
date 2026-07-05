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

# Databricks provider – account-level operations (Unity Catalog metastore discovery)
# Uses the Databricks Accounts API with the same Azure AAD credentials as above.
# This lets Terraform auto-discover an existing metastore in the target region even
# when the pre-flight shell discovery step cannot authenticate to the accounts API.
#
# azure_client_id must be set explicitly (via TF_VAR_azure_client_id) so the provider
# uses the OIDC (v2) token-exchange path rather than falling back to Azure CLI.
# Azure CLI tokens obtained with --resource produce v1 JWTs that lack the 'tid' claim
# required by accounts.azuredatabricks.net, causing "Failed to retrieve tenant ID".
provider "databricks" {
  alias           = "mws"
  host            = "https://accounts.azuredatabricks.net"
  account_id      = var.databricks_account_id
  azure_tenant_id = var.azure_tenant_id
  azure_client_id = var.azure_client_id
}
