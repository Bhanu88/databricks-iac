output "workspace_id" {
  description = "Databricks workspace resource ID"
  value       = azurerm_databricks_workspace.this.id
}

output "workspace_url" {
  description = "Databricks workspace URL"
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "workspace_name" {
  description = "Databricks workspace name"
  value       = azurerm_databricks_workspace.this.name
}

output "resource_group_name" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.this.location
}

output "databricks_workspace_id" {
  description = "Numeric Databricks workspace ID (used by Unity Catalog metastore)"
  value       = azurerm_databricks_workspace.this.workspace_id
}
