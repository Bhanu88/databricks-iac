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
