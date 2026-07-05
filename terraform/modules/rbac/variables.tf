variable "prefix" {
  description = "Naming prefix"
  type        = string
}

variable "workspace_numeric_id" {
  description = "Numeric Databricks workspace ID (reserved for future account-level operations)"
  type        = string
}

variable "admin_user_emails" {
  description = "List of email addresses to seed into the platform-admins group"
  type        = list(string)
  default     = []
}

variable "analyst_warehouse_size" {
  description = "SQL warehouse cluster size for analysts (2X-Small, X-Small, Small, Medium, Large)"
  type        = string
  default     = "Small"
}

variable "analyst_warehouse_max_clusters" {
  description = "Maximum number of clusters for the analysts SQL warehouse"
  type        = number
  default     = 3
}

variable "environment" {
  description = "Deployment environment (dev, prod) – used to construct Unity Catalog object names for grants"
  type        = string
}
