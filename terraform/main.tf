# ============================================================
# Root module – orchestrates all child modules
# ============================================================

# Discover every Unity Catalog metastore registered with this Databricks account.
# Databricks enforces exactly one metastore per Azure region per account; if the
# account already has one we must adopt it rather than attempt creation.
# Using the Databricks Terraform provider for discovery is more reliable than a
# shell script because it reuses the same account-level auth that the rest of the
# apply is already using.
data "databricks_metastores" "all" {
  provider = databricks.account
}

locals {
  prefix = "${var.project}-${var.environment}"
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    owner       = "platform-team"
  }

  # Prefer an explicitly-supplied override (e.g. var.databricks_metastore_id set
  # via TF_VAR_* or tfvars) — useful if the account has multiple metastores and
  # you need to pick a specific one.  Otherwise fall back to the first metastore
  # returned by the data source.  try() handles the case where the account has no
  # metastore yet (empty ids map → values()[0] would error without it).
  resolved_metastore_id = (
    var.databricks_metastore_id != ""
    ? var.databricks_metastore_id
    : try(values(data.databricks_metastores.all.ids)[0], "")
  )
}

# ----- Azure Databricks Access Connector ------------------------------------
# Required by Unity Catalog to authenticate with ADLS Gen2 via managed identity
resource "azurerm_databricks_access_connector" "uc" {
  name                = "${local.prefix}-uc-connector"
  resource_group_name = module.workspace.resource_group_name
  location            = var.location
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }

  depends_on = [module.workspace]
}

# Grant the access connector's managed identity access to storage
resource "azurerm_role_assignment" "connector_storage" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.uc.identity[0].principal_id
}

# ----- Modules --------------------------------------------------------------
module "workspace" {
  source = "./modules/workspace"

  prefix              = local.prefix
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  tags                = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  prefix                        = local.prefix
  storage_account_name          = var.storage_account_name
  resource_group_name           = module.workspace.resource_group_name
  location                      = var.location
  replication_type              = var.storage_replication_type
  public_network_access_enabled = var.storage_public_network_access_enabled
  tags                          = local.common_tags

  depends_on = [module.workspace]
}

module "unity_catalog" {
  source = "./modules/unity_catalog"

  prefix                = local.prefix
  environment           = var.environment
  location              = var.location
  workspace_id          = module.workspace.databricks_workspace_id
  storage_account_name  = module.storage.storage_account_name
  access_connector_id   = azurerm_databricks_access_connector.uc.id
  existing_metastore_id = local.resolved_metastore_id

  depends_on = [
    module.workspace,
    module.storage,
    azurerm_role_assignment.connector_storage,
  ]
}

module "rbac" {
  source = "./modules/rbac"

  prefix               = local.prefix
  admin_user_emails    = var.admin_user_emails
  workspace_numeric_id = module.workspace.databricks_workspace_id

  depends_on = [
    module.workspace,
    module.unity_catalog,
  ]
}

module "cluster_policies" {
  source = "./modules/cluster_policies"

  prefix         = local.prefix
  de_max_workers = var.de_max_workers
  ds_max_workers = var.ds_max_workers

  # rbac must run first — cluster policy permissions reference groups created by rbac
  depends_on = [
    module.workspace,
    module.rbac,
  ]
}
