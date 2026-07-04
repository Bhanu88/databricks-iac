# ── Dev environment variables ──────────────────────────────────────────────
project     = "energy"
environment = "dev"
location    = "eastus2"

resource_group_name  = "energy-dev-rg"
storage_account_name = "energydevlake01" # must be globally unique

storage_replication_type = "LRS" # cheaper for dev

# Networking
vnet_cidr           = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# Cluster limits (relaxed for dev)
de_max_workers = 8
ds_max_workers = 4

# Seed admin users (replace with real emails)
admin_user_emails = [
  "pat.bhanu@outlook.com",
]

# databricks_account_id is loaded from TF_VAR_databricks_account_id env var

# ci trigger
