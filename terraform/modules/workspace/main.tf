# ============================================================
# Module: workspace
# Provisions: Resource Group, VNet (VNet injection), NSG,
#             Azure Databricks Workspace (Premium SKU)
# ============================================================

# ----- Resource Group -------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ----- Networking -----------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "public" {
  name                 = "${var.prefix}-public-snet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.public_subnet_cidr]

  delegation {
    name = "databricks-del"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private" {
  name                 = "${var.prefix}-private-snet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_cidr]

  delegation {
    name = "databricks-del"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_network_security_group" "databricks" {
  name                = "${var.prefix}-databricks-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

# ----- Databricks Workspace -------------------------------------------------
resource "azurerm_databricks_workspace" "this" {
  name                        = "${var.prefix}-dbw"
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  sku                         = "premium" # Premium required for Unity Catalog & RBAC
  managed_resource_group_name = "${var.prefix}-dbw-managed-rg"
  tags                        = var.tags

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = azurerm_virtual_network.this.id
    public_subnet_name                                   = azurerm_subnet.public.name
    private_subnet_name                                  = azurerm_subnet.private.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.public,
    azurerm_subnet_network_security_group_association.private,
  ]
}

# ----- Workspace-level settings via Databricks provider --------------------
resource "databricks_workspace_conf" "this" {
  custom_config = {
    # Enable IP access lists so databricks_ip_access_list resources take effect
    "enableIpAccessLists" = "true"
    # Disable result downloads to prevent data exfiltration via notebook output
    "enableResultsDownloading" = var.enable_results_downloading
    # Disable clipboard export from notebook table cells
    "enableNotebookTableClipboard" = "false"
    # Enable PAT management; tokens expire after 90 days
    "enableTokensConfig"   = "true"
    "maxTokenLifetimeDays" = "90"
  }
}
