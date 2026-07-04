variable "prefix" {
  description = "Naming prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "workspace_id" {
  description = "Numeric Databricks workspace ID"
  type        = string
}

variable "storage_account_name" {
  description = "ADLS Gen2 storage account name"
  type        = string
}

variable "uc_container" {
  description = "Container name for Unity Catalog metastore root storage"
  type        = string
  default     = "unity-catalog"
}

variable "access_connector_id" {
  description = "Azure Databricks Access Connector resource ID (for Unity Catalog managed identity)"
  type        = string
}

variable "existing_metastore_id" {
  description = <<EOT
ID of an existing Unity Catalog metastore to adopt instead of creating a new one.
Databricks allows exactly one metastore per Azure region per account.  If your
account already has a metastore in this region, set this to its ID and Terraform
will skip creation and manage the assignment only.  Leave empty to create a new
metastore (only valid for a fresh account / region with no existing metastore).
EOT
  type    = string
  default = ""
}
