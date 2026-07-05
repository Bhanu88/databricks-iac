output "workspace_url" {
  description = "Databricks workspace URL"
  value       = module.workspace.workspace_url
}

output "workspace_id" {
  description = "Databricks workspace resource ID"
  value       = module.workspace.workspace_id
}

output "storage_account_name" {
  description = "ADLS Gen2 storage account name"
  value       = module.storage.storage_account_name
}

output "storage_dfs_endpoint" {
  description = "ADLS Gen2 DFS endpoint"
  value       = module.storage.storage_account_primary_dfs_endpoint
}

output "energy_catalog_name" {
  value = module.unity_catalog.energy_catalog_name
}

output "models_catalog_name" {
  value = module.unity_catalog.models_catalog_name
}

output "shared_catalog_name" {
  value = module.unity_catalog.shared_catalog_name
}

output "group_ids" {
  description = "Databricks group IDs by team name"
  value       = module.rbac.group_ids
}
