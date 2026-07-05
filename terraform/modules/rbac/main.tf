# ============================================================
# Module: rbac
# Provisions: Databricks groups, workspace-level permissions,
#             and top-level Unity Catalog grants.
#
# Group hierarchy:
#
#   platform-admins      – Workspace admins, metastore admins.
#                          Infrastructure / platform engineers.
#
#   data-engineers       – Build and maintain pipelines.
#                          Write access to bronze→gold + models.
#
#   data-scientists      – Experimentation, ML training.
#                          Read silver/gold, write to models.
#
#   analysts             – BI / reporting, SQL consumers.
#                          Read gold / curated only.
#
#   service-principals   – Automated job runners (CI/CD, orchestration).
#                          Least-privilege job execution.
#
# Within each team, users can share notebooks/queries/dashboards
# with their own group. Cross-team sharing uses the shared catalog.
# ============================================================

# ----- Groups ---------------------------------------------------------------
resource "databricks_group" "platform_admins" {
  display_name               = "platform-admins"
  allow_cluster_create       = true
  allow_instance_pool_create = true
}

resource "databricks_group" "data_engineers" {
  display_name               = "data-engineers"
  allow_cluster_create       = true
  allow_instance_pool_create = false
}

resource "databricks_group" "data_scientists" {
  display_name               = "data-scientists"
  allow_cluster_create       = true
  allow_instance_pool_create = false
}

resource "databricks_group" "analysts" {
  display_name               = "analysts"
  allow_cluster_create       = false # analysts use SQL warehouses only
  allow_instance_pool_create = false
}

resource "databricks_group" "service_principals" {
  display_name               = "service-principals"
  allow_cluster_create       = true
  allow_instance_pool_create = false
}

# ----- Workspace Admin assignment -------------------------------------------
# databricks_mws_permission_assignment requires the account-level provider.
# Setting permissions = ["ADMIN"] grants the group workspace admin privileges,
# equivalent to adding it to the built-in workspace admins group.
resource "databricks_mws_permission_assignment" "platform_admins_admin" {
  workspace_id = var.workspace_numeric_id
  principal_id = databricks_group.platform_admins.id
  permissions  = ["ADMIN"]
}

# ----- Workspace Admin Users (seed list from variable) ----------------------
resource "databricks_user" "admin_users" {
  for_each  = toset(var.admin_user_emails)
  user_name = each.key
}

resource "databricks_group_member" "admins" {
  for_each  = toset(var.admin_user_emails)
  group_id  = databricks_group.platform_admins.id
  member_id = databricks_user.admin_users[each.key].id
}

# ----- SQL Warehouse for Analysts -------------------------------------------
resource "databricks_sql_endpoint" "analysts" {
  name             = "${var.prefix}-analysts-warehouse"
  cluster_size     = var.analyst_warehouse_size
  max_num_clusters = var.analyst_warehouse_max_clusters
  auto_stop_mins   = 20

  channel {
    name = "CHANNEL_NAME_CURRENT"
  }

  tags {
    custom_tags {
      key   = "team"
      value = "analysts"
    }
  }
}

resource "databricks_permissions" "analyst_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.analysts.id

  access_control {
    group_name       = "analysts"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "data-engineers"
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_MANAGE"
  }
}

# ----- Workspace-level folder permissions -----------------------------------
# Each team gets their own top-level folder in /Workspace/
resource "databricks_directory" "team_folders" {
  for_each = {
    "data-engineering" = "/Workspace/Teams/DataEngineering"
    "data-science"     = "/Workspace/Teams/DataScience"
    "analytics"        = "/Workspace/Teams/Analytics"
    "shared"           = "/Workspace/Teams/Shared"
  }
  path = each.value
}

resource "databricks_permissions" "de_folder" {
  directory_path = databricks_directory.team_folders["data-engineering"].path

  access_control {
    group_name       = "data-engineers"
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_permissions" "ds_folder" {
  directory_path = databricks_directory.team_folders["data-science"].path

  access_control {
    group_name       = "data-scientists"
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_permissions" "analytics_folder" {
  directory_path = databricks_directory.team_folders["analytics"].path

  access_control {
    group_name       = "analysts"
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_permissions" "shared_folder" {
  directory_path = databricks_directory.team_folders["shared"].path

  access_control {
    group_name       = "data-engineers"
    permission_level = "CAN_EDIT"
  }
  access_control {
    group_name       = "data-scientists"
    permission_level = "CAN_EDIT"
  }
  access_control {
    group_name       = "analysts"
    permission_level = "CAN_READ"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_MANAGE"
  }
}

# ----- Secret Scopes --------------------------------------------------------
# Each team gets a private secret scope for credentials.
resource "databricks_secret_scope" "team_scopes" {
  for_each = {
    "data-engineering" = "de-secrets"
    "data-science"     = "ds-secrets"
    "analytics"        = "analytics-secrets"
    "platform"         = "platform-secrets"
  }
  name = each.value
}

resource "databricks_secret_acl" "de_scope" {
  scope      = databricks_secret_scope.team_scopes["data-engineering"].name
  principal  = "data-engineers"
  permission = "WRITE"
}

resource "databricks_secret_acl" "ds_scope" {
  scope      = databricks_secret_scope.team_scopes["data-science"].name
  principal  = "data-scientists"
  permission = "WRITE"
}

resource "databricks_secret_acl" "analytics_scope" {
  scope      = databricks_secret_scope.team_scopes["analytics"].name
  principal  = "analysts"
  permission = "READ"
}

resource "databricks_secret_acl" "platform_scope" {
  scope      = databricks_secret_scope.team_scopes["platform"].name
  principal  = "platform-admins"
  permission = "MANAGE"
}

# Service principals also need to read platform secrets for jobs
resource "databricks_secret_acl" "sp_platform_scope" {
  scope      = databricks_secret_scope.team_scopes["platform"].name
  principal  = "service-principals"
  permission = "READ"
}

# ----- Unity Catalog Grants -------------------------------------------------
# These grants reference group display_names so Terraform creates an implicit
# dependency on the group resources above.  They are placed here (not in the
# unity_catalog module) because the Databricks API rejects grants whose
# principal does not yet exist.  The root module ensures rbac runs after
# unity_catalog via depends_on, so the UC objects are ready by the time these
# run.

resource "databricks_grants" "storage_credential" {
  storage_credential = "${var.prefix}-storage-credential"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

resource "databricks_grants" "bronze_location" {
  external_location = "${var.prefix}-bronze-location"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
}

resource "databricks_grants" "silver_location" {
  external_location = "${var.prefix}-silver-location"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["READ_FILES"]
  }
}

resource "databricks_grants" "gold_location" {
  external_location = "${var.prefix}-gold-location"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["READ_FILES"]
  }
  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["READ_FILES"]
  }
}

resource "databricks_grants" "models_location" {
  external_location = "${var.prefix}-models-location"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["READ_FILES"]
  }
}

resource "databricks_grants" "shared_location" {
  external_location = "${var.prefix}-shared-location"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["READ_FILES", "WRITE_FILES"]
  }
  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["READ_FILES"]
  }
}

resource "databricks_grants" "energy_catalog" {
  catalog = "energy_${var.environment}"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_VOLUME"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "models_catalog" {
  catalog = "models_${var.environment}"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_MODEL"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_MODEL"]
  }
  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "shared_catalog" {
  catalog = "shared_${var.environment}"

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["USE_CATALOG", "CREATE_TABLE", "CREATE_SCHEMA"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["USE_CATALOG", "CREATE_TABLE"]
  }
  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "curated_schema" {
  schema = "energy_${var.environment}.curated"

  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = databricks_group.data_scientists.display_name
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["USE_SCHEMA", "SELECT", "MODIFY", "CREATE_TABLE"]
  }
  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}
