# ============================================================
# Module: rbac
# Provisions: Databricks groups, workspace-level permissions.
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
# NOTE — Unity Catalog grants are intentionally absent.
# `databricks_group` resources created via a workspace-scoped provider (host =
# workspace URL + PAT) produce workspace-local groups.  Unity Catalog grants
# require account-level principals, which must be created via the account API
# (accounts.azuredatabricks.net).  Account-level API access is blocked in this
# environment because the account owner is a personal Microsoft account
# (AADSTS500200).  Extend this module with a separate account-level provider
# alias to add UC grants once that constraint is lifted.
#
# NOTE — databricks_mws_permission_assignment is intentionally absent.
# That resource targets the account API, not the workspace API.  A workspace PAT
# cannot reach it (returns 404).  Workspace admin rights for platform-admins
# should be assigned via the Databricks account console or an account-level
# provider.
#
# NOTE — databricks_user / databricks_group_member are intentionally absent.
# The workspace was created by the account owner whose e-mail is already
# registered as a user.  Attempting to re-create that user via Terraform fails
# with "User already exists".  Admin users should be imported into state or
# managed outside this module.
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

# ----- Workspace-level folder permissions -----------------------------------
# Each team gets their own top-level folder in /Workspace/Teams/.
#
# group_name fields use resource references (not hardcoded strings) so Terraform
# creates implicit dependencies and does not race group creation against
# permission assignment.
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
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = databricks_group.platform_admins.display_name
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_permissions" "ds_folder" {
  directory_path = databricks_directory.team_folders["data-science"].path

  access_control {
    group_name       = databricks_group.data_scientists.display_name
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = databricks_group.platform_admins.display_name
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_permissions" "analytics_folder" {
  directory_path = databricks_directory.team_folders["analytics"].path

  access_control {
    group_name       = databricks_group.analysts.display_name
    permission_level = "CAN_MANAGE"
  }
  access_control {
    group_name       = databricks_group.platform_admins.display_name
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_permissions" "shared_folder" {
  directory_path = databricks_directory.team_folders["shared"].path

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_EDIT"
  }
  access_control {
    group_name       = databricks_group.data_scientists.display_name
    permission_level = "CAN_EDIT"
  }
  access_control {
    group_name       = databricks_group.analysts.display_name
    permission_level = "CAN_READ"
  }
  access_control {
    group_name       = databricks_group.platform_admins.display_name
    permission_level = "CAN_MANAGE"
  }
}

# ----- Secret Scopes --------------------------------------------------------
# Each team gets a private secret scope for credentials.
#
# principal fields use resource references (not hardcoded strings) so Terraform
# creates implicit dependencies and does not race group creation against ACL
# assignment.
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
  principal  = databricks_group.data_engineers.display_name
  permission = "WRITE"
}

resource "databricks_secret_acl" "ds_scope" {
  scope      = databricks_secret_scope.team_scopes["data-science"].name
  principal  = databricks_group.data_scientists.display_name
  permission = "WRITE"
}

resource "databricks_secret_acl" "analytics_scope" {
  scope      = databricks_secret_scope.team_scopes["analytics"].name
  principal  = databricks_group.analysts.display_name
  permission = "READ"
}

resource "databricks_secret_acl" "platform_scope" {
  scope      = databricks_secret_scope.team_scopes["platform"].name
  principal  = databricks_group.platform_admins.display_name
  permission = "MANAGE"
}

# Service principals also need to read platform secrets for jobs
resource "databricks_secret_acl" "sp_platform_scope" {
  scope      = databricks_secret_scope.team_scopes["platform"].name
  principal  = databricks_group.service_principals.display_name
  permission = "READ"
}
