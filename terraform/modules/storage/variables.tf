variable "prefix" {
  description = "Naming prefix"
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique Azure storage account name (max 24 chars, lowercase alphanumeric)"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "replication_type" {
  description = "Storage replication type (LRS, GRS, ZRS, GZRS)"
  type        = string
  default     = "ZRS"
}

variable "public_network_access_enabled" {
  description = "Allow public network access to storage (false in prod)"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic logging. Leave empty to skip."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
