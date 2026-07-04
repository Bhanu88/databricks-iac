output "data_engineering_policy_id" {
  value = databricks_cluster_policy.data_engineering.id
}

output "data_science_policy_id" {
  value = databricks_cluster_policy.data_science.id
}

output "analytics_policy_id" {
  value = databricks_cluster_policy.analytics.id
}

output "shared_interactive_policy_id" {
  value = databricks_cluster_policy.shared_interactive.id
}
