output "storage_account_id" {
  value = azurerm_storage_account.datalake.id
}

output "storage_account_name" {
  value = azurerm_storage_account.datalake.name
}

output "storage_account_primary_dfs_endpoint" {
  description = "DFS endpoint (abfss://) for ADLS Gen2"
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
}

output "unity_catalog_container_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.unity_catalog.name
}

output "zone_container_names" {
  value = { for k, v in azurerm_storage_data_lake_gen2_filesystem.zones : k => v.name }
}

output "databricks_uc_managed_identity_id" {
  description = "Client ID of the managed identity used by Unity Catalog"
  value       = azurerm_user_assigned_identity.databricks_uc.client_id
}

output "databricks_uc_managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.databricks_uc.principal_id
}
