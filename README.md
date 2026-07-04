# Databricks Infrastructure as Code — Energy Platform

Terraform IaC for a multi-team Databricks workspace on **Azure**, covering infrastructure provisioning, Unity Catalog governance, cluster policies, RBAC, and CI/CD via GitHub Actions.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Azure Subscription                                         │
│                                                             │
│  ┌──────────────── Resource Group ──────────────────────┐  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │  VNet (VNet Injection – no public IPs on nodes) │ │  │
│  │  │   ├── Public subnet  (host tier)                │ │  │
│  │  │   └── Private subnet (container tier)           │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  │                          │                            │  │
│  │  ┌───────────────────────▼──────────────────────┐    │  │
│  │  │  Databricks Workspace (Premium SKU)          │    │  │
│  │  │  Unity Catalog enabled                       │    │  │
│  │  │  No public IPs on compute nodes              │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  ADLS Gen2 Storage (HNS enabled)               │  │  │
│  │  │  ├── unity-catalog/  (UC metastore root)       │  │  │
│  │  │  ├── bronze/         (raw ingest)              │  │  │
│  │  │  ├── silver/         (cleaned)                 │  │  │
│  │  │  ├── gold/           (curated)                 │  │  │
│  │  │  ├── models/         (ML artefacts)            │  │  │
│  │  │  └── shared/         (cross-team exchange)     │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

Unity Catalog layer (logical):
  energy_<env>     → raw_*, processed_*, curated schemas
  models_<env>     → experiments, registry, serving schemas
  shared_<env>     → cross_team schema
```

---

## Repository Structure

```
databricks-iac/
├── terraform/
│   ├── main.tf                     # Root module – orchestrates all modules
│   ├── providers.tf                # Provider versions and config
│   ├── variables.tf                # Root variable declarations
│   ├── outputs.tf                  # Root outputs
│   ├── modules/
│   │   ├── workspace/              # Azure VNet + Databricks workspace
│   │   ├── storage/                # ADLS Gen2 + IAM
│   │   ├── unity_catalog/          # Metastore, catalogs, schemas, grants
│   │   ├── cluster_policies/       # Per-team cluster policies
│   │   └── rbac/                   # Groups, folders, SQL warehouse, secret scopes
│   └── environments/
│       ├── dev/                    # Dev tfvars + backend config
│       └── prod/                   # Prod tfvars + backend config
├── .github/
│   └── workflows/
│       ├── terraform-pr.yml        # PR: fmt, validate, tfsec, plan (comment)
│       └── terraform-deploy.yml    # Merge: apply dev → gated apply prod
└── README.md
```

---

## RBAC Design

### User Groups

| Group | Who | Cluster Create | Key Entitlements |
|---|---|---|---|
| **platform-admins** | Platform/SRE engineers | ✅ | Workspace admin, metastore admin, manage all secrets |
| **data-engineers** | Pipeline/ETL developers | ✅ | Write bronze→gold, write models, manage jobs, create clusters via DE policy |
| **data-scientists** | ML / research team | ✅ | Read silver/gold, write models & experiments, interactive clusters via DS policy |
| **analysts** | BI / reporting team | ❌ | Read gold/curated only, SQL warehouse access, read-only notebooks in shared folder |
| **service-principals** | CI/CD, orchestration bots | ✅ | Job execution only, read platform secrets |

### Data Access Matrix

| Zone / Layer | platform-admins | data-engineers | data-scientists | analysts |
|---|---|---|---|---|
| **bronze** (raw) | RW | RW | – | – |
| **silver** (cleaned) | RW | RW | R | – |
| **gold** (curated) | RW | RW | R | R |
| **models** | RW | RW | RW | R |
| **shared** | RW | RW | RW | R |

### Unity Catalog Privileges

Catalogs follow the principle of least privilege. Each team can only `USE_CATALOG` for the catalog tier they need. Within catalogs, schema-level grants narrow access further (e.g., analysts get `SELECT` on the `curated` schema only).

---

## Setup Instructions

### Prerequisites

- Azure subscription with Contributor access
- Databricks account-level admin access (accounts.azuredatabricks.net)
- Terraform ≥ 1.6.0
- Azure CLI (`az`)
- GitHub repository with Actions enabled

### 1. Bootstrap remote state storage

Before the first `terraform init`, create the Terraform state storage account manually (or via a bootstrap script):

```bash
# Create state resource group and storage account (one-time, per environment)
az group create --name energy-tfstate-rg --location eastus2

az storage account create \
  --name energytfstatedev \
  --resource-group energy-tfstate-rg \
  --sku Standard_LRS \
  --kind StorageV2

az storage container create \
  --name tfstate \
  --account-name energytfstatedev
```

### 2. Configure GitHub Secrets

In your GitHub repository → Settings → Secrets and variables → Actions:

| Secret | Description |
|---|---|
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Dev subscription ID |
| `AZURE_CLIENT_ID` | App registration client ID (dev, OIDC federated) |
| `AZURE_SUBSCRIPTION_ID_PROD` | Prod subscription ID |
| `AZURE_CLIENT_ID_PROD` | App registration client ID (prod, OIDC federated) |
| `DATABRICKS_ACCOUNT_ID` | Databricks account ID |

Configure OIDC federation on your Azure App Registration so GitHub Actions can authenticate without storing long-lived secrets:

```bash
az ad app federated-credential create \
  --id <APP_OBJECT_ID> \
  --parameters '{
    "name": "github-actions-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<ORG>/<REPO>:environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 3. Configure GitHub Environments

Create three GitHub Environments (`dev-plan`, `dev`, `prod`) in Settings → Environments.
Add a required-reviewer rule on the `prod` environment to gate production deploys.

### 4. Local Development

```bash
# Authenticate
az login
az account set --subscription <DEV_SUBSCRIPTION_ID>

cd terraform

# Initialise with dev backend
terraform init -backend-config=environments/dev/backend.tf

# Plan
export TF_VAR_databricks_account_id="<your-account-id>"
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply
terraform apply -var-file=environments/dev/terraform.tfvars
```

---

## CI/CD Flow

```
PR opened/updated
       │
       ▼
  terraform fmt -check
  terraform validate
  tfsec (security scan)
       │
       ├──► plan (dev)  ──► comment on PR
       └──► plan (prod) ──► comment on PR
                │
          PR approved + merged to main
                │
                ▼
         apply → dev  (auto, no approval)
                │
         ✅ dev success
                │
                ▼
         apply → prod  (requires manual approval in GitHub Environment)
```

---

## Assumptions

1. **Azure as cloud provider** — Databricks on Azure is the most common enterprise choice and aligns well with energy sector Azure footprints.
2. **Unity Catalog** — assumed the account is Unity Catalog enabled (requires Databricks account-level admin). UC is the recommended governance layer for multi-team environments.
3. **No existing AAD groups** — groups are created and managed in Databricks rather than synced from Entra ID. In practice you would use SCIM provisioning to sync AAD groups.
4. **VNet injection with no public IPs** — secure-by-default networking; all cluster traffic stays within the private VNet.
5. **Single workspace per environment** — a single Premium workspace per env with Unity Catalog handles multi-team isolation at the catalog/schema level. Separate workspaces per team would add operational overhead without significant security benefit given UC isolation.
6. **Four teams** — data engineering, data science, analytics, and platform/SRE. Additional teams (e.g. ML Ops, IoT ingestion) would follow the same pattern.
7. **Storage account name uniqueness** — tfvars contain placeholder names; these must be globally unique and should be updated before first apply.

---

## Challenges

- **Unity Catalog bootstrap order** — the metastore, access connector, storage credential, and workspace assignment must be created in a specific order with explicit `depends_on` to avoid race conditions.
- **OIDC federation vs. service principal secrets** — OIDC is used to avoid long-lived secrets in CI; this requires the GitHub environment subject claim to match exactly.
- **Cluster policy JSON** — Databricks cluster policy definitions are a verbose JSON-in-HCL structure. `jsonencode()` keeps it readable but type errors surface only at apply time.
- **Storage account name constraints** — 24-char limit, globally unique, lowercase alphanumeric. Recommended pattern: `<project><env>lake<suffix>`.

---

## Improvement Ideas

1. **SCIM / Entra ID group sync** — replace manually-managed Databricks groups with automatic sync from Azure AD using the Databricks SCIM connector.
2. **Databricks Terraform testing** — add `terraform test` unit tests (`.tftest.hcl`) for variable validation and module output shapes.
3. **Cost monitoring** — add Azure Cost Management budgets and alerts; integrate Databricks cluster usage reports with a cost dashboard.
4. **Private endpoints** — add Azure Private Endpoints for the storage account to remove all public network exposure (production hardening).
5. **Key Vault integration** — store secrets (Databricks tokens, SP credentials) in Azure Key Vault and reference them via the Databricks secrets API rather than storing in Terraform state.
6. **Drift detection** — schedule a weekly `terraform plan` run in CI and alert on drift via Slack/Teams.
7. **Policy-as-code** — extend tfsec with custom rules for energy-sector compliance (e.g., data residency, encryption key management).
8. **MLflow integration** — provision a dedicated MLflow tracking URI and model registry pointing at the `models` catalog, wired into the data science cluster policy by default.

---

## LLM Disclosure

This solution was developed with assistance from **Claude (Anthropic)** to accelerate writing Terraform HCL boilerplate, structuring the module hierarchy, and drafting documentation. All architectural decisions, security boundaries, RBAC design, and module composition were authored and reviewed by the engineer. The LLM was used as a coding accelerator, not a decision-maker.
