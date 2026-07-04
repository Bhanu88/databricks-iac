# ============================================================
# Module: cluster_policies
# Provisions: Databricks cluster policies per team type.
#
# Policies enforce cost guardrails (DBU limits, instance
# types, auto-termination) without restricting what teams
# can compute.
#
# Policies created:
#   data-engineering-policy  – job clusters, high-memory nodes allowed
#   data-science-policy      – interactive/ML clusters, GPU allowed
#   analytics-policy         – lightweight interactive / SQL clusters
#   shared-interactive-policy – catch-all for ad-hoc work
# ============================================================

# ----- Data Engineering Policy ----------------------------------------------
# Optimised for ETL job clusters. Auto-termination enforced.
resource "databricks_cluster_policy" "data_engineering" {
  name = "${var.prefix}-data-engineering-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.de_allowed_node_types,
      "defaultValue" : var.de_default_node_type
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 120,
      "defaultValue" : 30
    },
    "autoscale.min_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 4
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : 2,
      "maxValue" : var.de_max_workers
    },
    "cluster_type" : {
      "type" : "fixed",
      "value" : "job"
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "SINGLE_USER"
    },
    "runtime_engine" : {
      "type" : "unlimited",
      "defaultValue" : "PHOTON"
    },
    "spark_conf.spark.databricks.cluster.profile" : {
      "type" : "fixed",
      "value" : "serverless"
    }
  })
}

# ----- Data Science Policy --------------------------------------------------
# Interactive clusters for experimentation. GPU instance types allowed.
resource "databricks_cluster_policy" "data_science" {
  name = "${var.prefix}-data-science-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-ml"
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.ds_allowed_node_types,
      "defaultValue" : var.ds_default_node_type
    },
    "driver_node_type_id" : {
      "type" : "allowlist",
      "values" : var.ds_allowed_node_types
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 20,
      "maxValue" : 240,
      "defaultValue" : 60
    },
    "autoscale.min_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 2
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : var.ds_max_workers
    },
    "cluster_type" : {
      "type" : "fixed",
      "value" : "all-purpose"
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "SINGLE_USER"
    },
    "spark_conf.spark.databricks.mlflow.trackMLflowRuns" : {
      "type" : "fixed",
      "value" : "true"
    }
  })
}

# ----- Analytics Policy -----------------------------------------------------
# Lightweight clusters for SQL / BI workloads; no large instance types.
resource "databricks_cluster_policy" "analytics" {
  name = "${var.prefix}-analytics-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.analytics_allowed_node_types,
      "defaultValue" : var.analytics_default_node_type
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 60,
      "defaultValue" : 20
    },
    "num_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : var.analytics_max_workers
    },
    "cluster_type" : {
      "type" : "fixed",
      "value" : "all-purpose"
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "USER_ISOLATION" # shared cluster mode for SQL analysts
    }
  })
}

# ----- Shared Interactive Policy --------------------------------------------
# Catch-all for ad-hoc / cross-team work. Conservative limits.
resource "databricks_cluster_policy" "shared_interactive" {
  name = "${var.prefix}-shared-interactive-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.shared_allowed_node_types,
      "defaultValue" : var.shared_default_node_type
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 60,
      "defaultValue" : 30
    },
    "num_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 4
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "USER_ISOLATION"
    }
  })
}

# ----- Policy Permissions ---------------------------------------------------
resource "databricks_permissions" "de_policy" {
  cluster_policy_id = databricks_cluster_policy.data_engineering.id

  access_control {
    group_name       = "data-engineers"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_USE"
  }
}

resource "databricks_permissions" "ds_policy" {
  cluster_policy_id = databricks_cluster_policy.data_science.id

  access_control {
    group_name       = "data-scientists"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_USE"
  }
}

resource "databricks_permissions" "analytics_policy" {
  cluster_policy_id = databricks_cluster_policy.analytics.id

  access_control {
    group_name       = "analysts"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_USE"
  }
}

resource "databricks_permissions" "shared_policy" {
  cluster_policy_id = databricks_cluster_policy.shared_interactive.id

  access_control {
    group_name       = "data-engineers"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "data-scientists"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "analysts"
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = "platform-admins"
    permission_level = "CAN_USE"
  }
}
