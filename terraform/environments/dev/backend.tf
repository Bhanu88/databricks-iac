# Partial backend configuration — passed via -backend-config flag
# Do NOT wrap in terraform{} blocks; only raw key=value pairs are valid here.
resource_group_name  = "energy-tfstate-rg"
storage_account_name = "energytfstatedev"
container_name       = "tfstate"
key                  = "energy/dev/terraform.tfstate"
use_oidc             = true
