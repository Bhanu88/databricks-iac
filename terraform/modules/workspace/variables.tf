variable "prefix" {
  description = "Naming prefix for all resources (e.g. energy-dev)"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "vnet_cidr" {
  description = "CIDR block for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public (host) subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private (container) subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "enable_results_downloading" {
  description = "Allow users to download query results"
  type        = string
  default     = "false"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
