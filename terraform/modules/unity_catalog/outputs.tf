output "metastore_id" {
  value = databricks_metastore.this.id
}

output "energy_catalog_name" {
  value = databricks_catalog.energy.name
}

output "models_catalog_name" {
  value = databricks_catalog.models.name
}

output "shared_catalog_name" {
  value = databricks_catalog.shared.name
}

output "storage_credential_name" {
  value = databricks_storage_credential.datalake.name
}

output "external_location_names" {
  value = { for k, v in databricks_external_location.zones : k => v.name }
}
