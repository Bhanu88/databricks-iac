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

# Databricks provider – workspace-level and account-level operations
# Authenticates using the workspace URL + a PAT from an account-admin user
# (var.databricks_token → TF_VAR_databricks_token → DATABRICKS_TOKEN secret).
# A PAT is required because the service principal running the Azure/ARM steps
# does not have account-admin or metastore-admin rights in Databricks, and the
# Databricks account console rejects personal Microsoft accounts (AADSTS500200),
# preventing UI-based role assignment.  The PAT owner (the account admin who
# created the subscription) has full metastore admin rights by default.
provider "databricks" {
  host  = module.workspace.workspace_url
  token = var.databricks_token
}
