# ============================================================
# Root module – orchestrates all child modules
# ============================================================

# ----- Safety net: discover existing Unity Catalog metastore -----------------
# The deploy workflow pre-flight step sets TF_VAR_databricks_metastore_id when
# it can authenticate to the Databricks accounts API.  If that step fails
# (e.g. transient auth issue), fall back to querying the accounts API via the
# Terraform MWS provider alias which uses the same Azure SDK credential chain
# and handles tenant-ID resolution transparently.
data "databricks_metastores" "all" {
  provider = databricks.mws
}

locals {
  prefix = "${var.project}-${var.environment}"
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    owner       = "platform-team"
  }

  # Use the metastore ID surfaced by the pre-flight step; fall back to the
  # first metastore discovered via the MWS provider if the variable is empty.
  effective_metastore_id = (
    var.databricks_metastore_id != "" ? var.databricks_metastore_id :
    try(values(data.databricks_metastores.all.ids)[0], "")
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
  existing_metastore_id = local.effective_metastore_id

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
