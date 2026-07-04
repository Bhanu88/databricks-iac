# ── Prod environment variables ─────────────────────────────────────────────
project     = "energy"
environment = "prod"
location    = "eastus2"

resource_group_name  = "energy-prod-rg"
storage_account_name = "energyprodlake01" # must be globally unique

storage_replication_type = "ZRS" # zone-redundant for production

# Networking (separate CIDR space from dev)
vnet_cidr           = "10.1.0.0/16"
public_subnet_cidr  = "10.1.1.0/24"
private_subnet_cidr = "10.1.2.0/24"

# Cluster limits (production scale)
de_max_workers = 20
ds_max_workers = 8

# Seed admin users (replace with real emails)
admin_user_emails = [
  "platform-admin@energyco.com",
  "platform-lead@energyco.com",
]

# databricks_account_id is loaded from TF_VAR_databricks_account_id env var
