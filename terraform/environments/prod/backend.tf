terraform {
  backend "azurerm" {
    resource_group_name  = "energy-tfstate-rg"
    storage_account_name = "energytfstateprod"
    container_name       = "tfstate"
    key                  = "energy/prod/terraform.tfstate"
    use_oidc             = true
  }
}
