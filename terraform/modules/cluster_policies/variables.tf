variable "prefix" {
  description = "Naming prefix"
  type        = string
}

# Data Engineering
variable "de_allowed_node_types" {
  type    = list(string)
  default = ["Standard_DS3_v2", "Standard_DS4_v2", "Standard_DS5_v2", "Standard_E8s_v3", "Standard_E16s_v3"]
}

variable "de_default_node_type" {
  type    = string
  default = "Standard_DS4_v2"
}

variable "de_max_workers" {
  type    = number
  default = 20
}

# Data Science
variable "ds_allowed_node_types" {
  type    = list(string)
  default = ["Standard_DS3_v2", "Standard_DS4_v2", "Standard_NC6s_v3", "Standard_NC12s_v3"]
}

variable "ds_default_node_type" {
  type    = string
  default = "Standard_DS4_v2"
}

variable "ds_max_workers" {
  type    = number
  default = 8
}

# Analytics
variable "analytics_allowed_node_types" {
  type    = list(string)
  default = ["Standard_DS3_v2", "Standard_DS4_v2"]
}

variable "analytics_default_node_type" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "analytics_max_workers" {
  type    = number
  default = 4
}

# Shared Interactive
variable "shared_allowed_node_types" {
  type    = list(string)
  default = ["Standard_DS3_v2", "Standard_DS4_v2"]
}

variable "shared_default_node_type" {
  type    = string
  default = "Standard_DS3_v2"
}
