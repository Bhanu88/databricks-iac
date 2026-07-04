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

variable "azure_tenant_id" {
  description = <<EOT
Azure AD tenant ID for the Databricks account-level provider.  The accounts host
(accounts.azuredatabricks.net) is cloud-agnostic, so the provider cannot infer
Azure from the URL — azure_tenant_id must be supplied explicitly to force the
Azure auth code-path.
Set via TF_VAR_azure_tenant_id in CI (apply/plan).  Defaults to null for
destroy or other operations that don't set the var; the provider then falls back
to reading ARM_TENANT_ID from the environment, which is always set at the
workflow level.
EOT
  type      = string
  sensitive = true
  default   = null
}

variable "databricks_metastore_id" {
  description = <<EOT
Optional override: ID of an existing Unity Catalog metastore to adopt.
Normally left empty — Terraform auto-discovers the existing metastore via the
databricks_metastores data source using the account-level provider.  Set this
explicitly only when the account has multiple metastores and you need to target
a specific one (e.g. via TF_VAR_databricks_metastore_id in CI).
EOT
  type    = string
  default = ""
}
