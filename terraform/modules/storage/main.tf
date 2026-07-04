# ============================================================
# Module: storage
# Provisions: ADLS Gen2 storage account with hierarchical
#             namespaces, containers (zones + team areas),
#             and IAM role assignments for Databricks.
#
# Data lake zone layout:
#   bronze/   – raw ingest (append-only)
#   silver/   – cleaned / validated
#   gold/     – curated / aggregated
#   models/   – ML model artefacts
#   shared/   – cross-team exchange area
# ============================================================

resource "azurerm_storage_account" "datalake" {
  name                     = var.storage_account_name # globally unique, max 24 chars
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  is_hns_enabled           = true # enables ADLS Gen2
  min_tls_version          = "TLS1_2"

  # Disable anonymous public access
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = var.public_network_access_enabled

  blob_properties {
    # versioning_enabled is not supported when is_hns_enabled = true (ADLS Gen2)
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# ----- Self-grant data-plane access for the Terraform runner ----------------
# azurerm_storage_data_lake_gen2_filesystem calls the DFS data-plane API,
# which requires a Storage Blob Data* role — ARM Owner/Contributor alone is
# insufficient.  We grant the current SP (GitHub Actions OIDC identity) the
# Contributor role here, then sleep 30 s for RBAC to propagate before
# creating filesystems.

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "terraform_sp_storage_blob" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_rbac_propagation" {
  depends_on      = [azurerm_role_assignment.terraform_sp_storage_blob]
  create_duration = "30s"
}

# ----- Unity Catalog metastore container ------------------------------------
# Separate top-level container used exclusively by Unity Catalog.
resource "azurerm_storage_data_lake_gen2_filesystem" "unity_catalog" {
  name               = "unity-catalog"
  storage_account_id = azurerm_storage_account.datalake.id

  depends_on = [time_sleep.wait_for_rbac_propagation]
}

# ----- Data lake zone containers --------------------------------------------
locals {
  lake_zones = ["bronze", "silver", "gold", "models", "shared"]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "zones" {
  for_each           = toset(local.lake_zones)
  name               = each.key
  storage_account_id = azurerm_storage_account.datalake.id

  depends_on = [time_sleep.wait_for_rbac_propagation]
}

# ----- Managed Identity for Databricks → Storage ----------------------------
# Unity Catalog uses a service principal / managed identity to access ADLS.
# We create a user-assigned identity and grant it Storage Blob Data Contributor
# on the storage account. The UC storage credential references this identity.
resource "azurerm_user_assigned_identity" "databricks_uc" {
  name                = "${var.prefix}-uc-mi"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "uc_storage_contributor" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.databricks_uc.principal_id
}

# Reader role on the storage account lets Unity Catalog enumerate containers.
resource "azurerm_role_assignment" "uc_storage_reader" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.databricks_uc.principal_id
}

# ----- Diagnostic settings (optional: enable for audit logging) -------------
resource "azurerm_monitor_diagnostic_setting" "storage_audit" {
  count                      = var.log_analytics_workspace_id != "" ? 1 : 0
  name                       = "${var.prefix}-storage-diag"
  target_resource_id         = "${azurerm_storage_account.datalake.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
