# ============================================================
# Module: unity_catalog
# Provisions: Unity Catalog metastore, storage credential,
#             external locations per data lake zone,
#             catalogs and schemas per team.
#
# Catalog layout:
#   energy_<env>         – main catalog (all teams)
#     └── raw            – landing zone schemas per team
#     └── processed      – cleansed data schemas
#     └── curated        – business-ready schemas
#   models_<env>         – ML model artefacts catalog
#   shared_<env>         – cross-team exchange catalog
#
# NOTE: All databricks_grants resources live in the rbac module.
# Groups (platform-admins, data-engineers, etc.) are created there,
# and Databricks rejects grants that reference non-existent principals.
# Since rbac depends_on unity_catalog, grants run after both the UC
# resources below AND the groups are provisioned.
# ============================================================

# ----- Unity Catalog Metastore ----------------------------------------------
# Databricks allows exactly one Unity Catalog metastore per Azure region per
# account.  When var.existing_metastore_id is supplied we skip creation and
# adopt the existing metastore.  When it is empty we create a new one.
locals {
  # trimspace guards against trailing newlines that can sneak in via GitHub
  # secrets or CI env-var interpolation (e.g. "uuid\n" -> 37 chars -> API error).
  _existing_id     = trimspace(var.existing_metastore_id)
  create_metastore = local._existing_id == ""
  metastore_id     = local.create_metastore ? databricks_metastore.this[0].id : local._existing_id
}

resource "databricks_metastore" "this" {
  count = local.create_metastore ? 1 : 0

  name          = "${var.prefix}-metastore"
  storage_root  = "abfss://${var.uc_container}@${var.storage_account_name}.dfs.core.windows.net/"
  region        = var.location
  force_destroy = false
}

resource "databricks_metastore_assignment" "this" {
  metastore_id = local.metastore_id
  workspace_id = var.workspace_id
}

# NOTE: databricks_default_namespace_setting is intentionally omitted.
# New Unity Catalog workspaces have legacy Hive metastore access disabled,
# and the API rejects attempts to set hive_metastore as the default namespace
# in that configuration.  The default namespace is left unset (UC default).

# ----- Storage Credential (Managed Identity) --------------------------------
resource "databricks_storage_credential" "datalake" {
  name = "${var.prefix}-storage-credential"

  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  comment      = "Managed identity credential for ADLS Gen2 access via Unity Catalog"
  metastore_id = local.metastore_id

  depends_on = [databricks_metastore_assignment.this]
}

# ----- External Locations per Data Lake Zone --------------------------------
locals {
  zones = ["bronze", "silver", "gold", "models", "shared"]
}

resource "databricks_external_location" "zones" {
  for_each = toset(local.zones)

  name            = "${var.prefix}-${each.key}-location"
  url             = "abfss://${each.key}@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.datalake.name
  comment         = "External location for ${each.key} data lake zone"

  depends_on = [databricks_metastore_assignment.this]
}

# ----- Catalogs -------------------------------------------------------------
# depends_on includes external locations because Databricks validates that the
# storage_root path falls within a registered external location at creation time.
resource "databricks_catalog" "energy" {
  name    = "energy_${var.environment}"
  comment = "Main data catalog for energy platform (${var.environment})"

  storage_root = "abfss://silver@${var.storage_account_name}.dfs.core.windows.net/energy_catalog/"

  depends_on = [
    databricks_metastore_assignment.this,
    databricks_external_location.zones,
  ]
}

resource "databricks_catalog" "models" {
  name    = "models_${var.environment}"
  comment = "ML model artefacts catalog (${var.environment})"

  storage_root = "abfss://models@${var.storage_account_name}.dfs.core.windows.net/models_catalog/"

  depends_on = [
    databricks_metastore_assignment.this,
    databricks_external_location.zones,
  ]
}

resource "databricks_catalog" "shared" {
  name    = "shared_${var.environment}"
  comment = "Cross-team shared data exchange catalog (${var.environment})"

  storage_root = "abfss://shared@${var.storage_account_name}.dfs.core.windows.net/shared_catalog/"

  depends_on = [
    databricks_metastore_assignment.this,
    databricks_external_location.zones,
  ]
}

# ----- Schemas in energy catalog -------------------------------------------
locals {
  energy_schemas = [
    "raw_data_engineering",
    "raw_data_science",
    "raw_analytics",
    "processed_data_engineering",
    "processed_data_science",
    "processed_analytics",
    "curated",
  ]

  model_schemas = ["experiments", "registry", "serving"]

  shared_schemas = ["cross_team"]
}

resource "databricks_schema" "energy" {
  for_each     = toset(local.energy_schemas)
  catalog_name = databricks_catalog.energy.name
  name         = each.key
  comment      = "Schema ${each.key} in energy catalog"
}

resource "databricks_schema" "models" {
  for_each     = toset(local.model_schemas)
  catalog_name = databricks_catalog.models.name
  name         = each.key
  comment      = "Schema ${each.key} in models catalog"
}

resource "databricks_schema" "shared" {
  for_each     = toset(local.shared_schemas)
  catalog_name = databricks_catalog.shared.name
  name         = each.key
  comment      = "Schema ${each.key} in shared catalog"
}
