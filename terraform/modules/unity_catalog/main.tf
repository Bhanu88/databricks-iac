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
# ============================================================

# ----- Unity Catalog Metastore ----------------------------------------------
# Databricks allows exactly one Unity Catalog metastore per Azure region per
# account.  When var.existing_metastore_id is supplied (discovered by the CI
# workflow before terraform runs), we skip creation entirely and adopt the
# existing metastore.  When it is empty we create a new one — only valid for
# accounts / regions that have no metastore yet.
locals {
  create_metastore = var.existing_metastore_id == ""
  metastore_id     = local.create_metastore ? databricks_metastore.this[0].id : var.existing_metastore_id
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
  # default_catalog_name is deprecated; set the default namespace via the
  # databricks_default_namespace_setting resource below instead.
}

# Replaces the deprecated default_catalog_name argument on the assignment.
resource "databricks_default_namespace_setting" "hive" {
  namespace {
    value = "hive_metastore"
  }

  depends_on = [databricks_metastore_assignment.this]
}

# ----- Storage Credential (Managed Identity) --------------------------------
resource "databricks_storage_credential" "datalake" {
  name = "${var.prefix}-storage-credential"

  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  comment    = "Managed identity credential for ADLS Gen2 access via Unity Catalog"
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
resource "databricks_catalog" "energy" {
  name    = "energy_${var.environment}"
  comment = "Main data catalog for energy platform (${var.environment})"

  storage_root = "abfss://silver@${var.storage_account_name}.dfs.core.windows.net/energy_catalog/"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_catalog" "models" {
  name    = "models_${var.environment}"
  comment = "ML model artefacts catalog (${var.environment})"

  storage_root = "abfss://models@${var.storage_account_name}.dfs.core.windows.net/models_catalog/"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_catalog" "shared" {
  name    = "shared_${var.environment}"
  comment = "Cross-team shared data exchange catalog (${var.environment})"

  storage_root = "abfss://shared@${var.storage_account_name}.dfs.core.windows.net/shared_catalog/"

  depends_on = [databricks_metastore_assignment.this]
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

# ----- Grants on External Locations ----------------------------------------
# Storage credential: admins only manage
resource "databricks_grants" "storage_credential" {
  storage_credential = databricks_storage_credential.datalake.name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
}

# Bronze: data engineers write, others read
resource "databricks_grants" "bronze_location" {
  external_location = databricks_external_location.zones["bronze"].name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
}

# Silver: data engineers write, data scientists read
resource "databricks_grants" "silver_location" {
  external_location = databricks_external_location.zones["silver"].name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["READ_FILES"]
  }
}

# Gold: data engineers write, all teams read
resource "databricks_grants" "gold_location" {
  external_location = databricks_external_location.zones["gold"].name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["READ_FILES"]
  }
  grant {
    principal  = "analysts"
    privileges = ["READ_FILES"]
  }
}

# Models: data scientists and engineers write, analysts read
resource "databricks_grants" "models_location" {
  external_location = databricks_external_location.zones["models"].name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = "analysts"
    privileges = ["READ_FILES"]
  }
}

# Shared: all teams read and write
resource "databricks_grants" "shared_location" {
  external_location = databricks_external_location.zones["shared"].name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["READ_FILES", "WRITE_FILES"]
  }
  grant {
    principal  = "analysts"
    privileges = ["READ_FILES"]
  }
}

# ----- Catalog Grants -------------------------------------------------------
resource "databricks_grants" "energy_catalog" {
  catalog = databricks_catalog.energy.name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_VOLUME"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = "analysts"
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "models_catalog" {
  catalog = databricks_catalog.models.name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_MODEL"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_MODEL"]
  }
  grant {
    principal  = "analysts"
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "shared_catalog" {
  catalog = databricks_catalog.shared.name

  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["USE_CATALOG", "CREATE_TABLE", "CREATE_SCHEMA"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["USE_CATALOG", "CREATE_TABLE"]
  }
  grant {
    principal  = "analysts"
    privileges = ["USE_CATALOG"]
  }
}

# Curated schema: analysts get SELECT
resource "databricks_grants" "curated_schema" {
  schema = "${databricks_catalog.energy.name}.curated"

  grant {
    principal  = "analysts"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = "data-scientists"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = "data-engineers"
    privileges = ["USE_SCHEMA", "SELECT", "MODIFY", "CREATE_TABLE"]
  }
  grant {
    principal  = "platform-admins"
    privileges = ["ALL_PRIVILEGES"]
  }

  depends_on = [databricks_schema.energy]
}
