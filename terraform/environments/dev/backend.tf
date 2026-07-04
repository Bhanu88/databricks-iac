# Remote state stored in Azure Blob Storage (bootstrapped separately)
terraform {
  backend "azurerm" {
    resource_group_name  = "energy-tfstate-rg"
    storage_account_name = "energytfstatedev"
    container_name       = "tfstate"
    key                  = "energy/dev/terraform.tfstate"
    use_oidc             = true # Use GitHub OIDC for CI authentication
  }
}
