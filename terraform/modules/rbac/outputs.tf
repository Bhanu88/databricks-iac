output "group_ids" {
  description = "Map of group display name to Databricks group ID"
  value = {
    platform_admins    = databricks_group.platform_admins.id
    data_engineers     = databricks_group.data_engineers.id
    data_scientists    = databricks_group.data_scientists.id
    analysts           = databricks_group.analysts.id
    service_principals = databricks_group.service_principals.id
  }
}

output "secret_scope_names" {
  value = { for k, v in databricks_secret_scope.team_scopes : k => v.name }
}
