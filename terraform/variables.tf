variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "energy"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "storage_account_name" {
  description = "ADLS Gen2 storage account name (globally unique, max 24 chars)"
  type        = string
}

variable "storage_replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "ZRS"
}

variable "databricks_account_id" {
  description = "Databricks account ID (from accounts.azuredatabricks.net)"
  type        = string
  sensitive   = true
}

variable "vnet_cidr" {
  description = "CIDR block for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "de_max_workers" {
  description = "Max autoscale workers for data engineering clusters"
  type        = number
  default     = 20
}

variable "ds_max_workers" {
  description = "Max autoscale workers for data science clusters"
  type        = number
  default     = 8
}

variable "admin_user_emails" {
  description = "List of emails to seed into platform-admins group"
  type        = list(string)
  default     = []
}

variable "storage_public_network_access_enabled" {
  description = "Allow public network access to the ADLS Gen2 storage account. Enable in dev so CI runners can reach the DFS endpoint; disable in prod and use private endpoints instead."
  type        = bool
  default     = false
}

variable "databricks_metastore_id" {
  description = <<EOT
ID of an existing Unity Catalog metastore to adopt instead of creating a new one.
Databricks enforces one metastore per Azure region per account, so this must be
set if the account already has a metastore in the target region.
Supplied via TF_VAR_databricks_metastore_id from the DATABRICKS_METASTORE_ID
GitHub secret.  Leave empty only in a brand-new account with no existing metastore.
EOT
  type    = string
  default = ""
}

variable "databricks_token" {
  description = <<EOT
Personal Access Token of a Databricks account-admin user.  Used by the Databricks
Terraform provider so it can perform account-level operations (metastore assignment,
Unity Catalog grants) that require account-admin or metastore-admin privileges.
A service principal with only workspace-admin rights is insufficient for these
operations.  Supplied via TF_VAR_databricks_token from the DATABRICKS_TOKEN secret.
EOT
  type      = string
  sensitive = true
  default   = ""
}
