# Secure Day 2 Operations Lab (Terraform + Vault CE + Azure)

This repository is a **30-minute, hands-on lab** to demonstrate how to secure Day 2 operations using:

- **Terraform** as infrastructure and security automation code
- **Vault Community Edition** for secret lifecycle and controlled access
- **Azure** as the cloud environment

The lab supports:

- **Local mode** (Vault in Docker)
- **Cloud mode** (Vault CE on Azure Container Instances)

---

## 1. What you will demonstrate

1. Deploy Vault consistently (local or Azure) with code.
2. Bootstrap security controls via Terraform:
   - KV v2 secrets engine
   - least-privilege policies
   - AppRole for machine identity
   - scheduled rotation resources
3. Perform Day 2 operations:
   - rotate runtime secret
   - rotate AppRole SecretID
   - update policy safely as code

---

## 2. Repository structure

```text
.
├── docker-compose.yml               # Local Vault CE (dev mode)
├── Makefile                         # Common shortcut commands
├── scripts/
│   ├── wait-for-vault.sh            # Wait until Vault API is reachable
│   └── azure-bootstrap-vault.sh     # Bootstrap vault module from Azure outputs
└── terraform/
    ├── azure/                       # Azure infrastructure + Vault container
    ├── azure-existing/              # Import existing Azure resources + secure in Vault
    └── vault/                       # Vault configuration (auth, policy, secrets)
```

---

## 3. Prerequisites

- Terraform `>= 1.6`
- Docker Desktop (for local mode)
- Azure CLI (`az`) logged in to your subscription
- `curl`
- (Optional) Vault CLI (`vault`) for interactive verification

Azure login:

```bash
az login
az account show
```

---

## 4. Step-by-step lab guide

### Step 0: Clone and enter the repo

```bash
git clone https://github.com/cloudwithritesh/secure-day2-operations.git
cd secure-day2-operations
```

### Step 1: Choose your path

- **Path A (Local first)**: fastest for live demo and troubleshooting
- **Path B (Azure cloud)**: same concepts, cloud deployment
- **Path C (Existing Azure resources)**: import existing resources into Terraform state and secure them in Vault

You can do both in one session.

---

## 5. Path A - Run locally

### Step A1: Start Vault locally

```bash
make local-up
./scripts/wait-for-vault.sh http://127.0.0.1:8200
```

### Step A2: Bootstrap Vault with Terraform

```bash
cp terraform/vault/terraform.tfvars.example terraform/vault/terraform.tfvars
terraform -chdir=terraform/vault init
terraform -chdir=terraform/vault apply \
  -var='vault_addr=http://127.0.0.1:8200' \
  -var='vault_token=root' \
  -var='environment=local'
```

### Step A3: Verify resources created

```bash
terraform -chdir=terraform/vault output
```

Optional Vault CLI checks:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
vault secrets list
vault policy list
vault auth list
```

---

## 6. Path B - Run on Azure

### Step B1: Prepare Azure variables

```bash
cp terraform/azure/terraform.tfvars.example terraform/azure/terraform.tfvars
```

Edit `terraform/azure/terraform.tfvars` and set at least:

- `vault_root_token` (change from default value)
- `location` / `name_prefix` if needed
- `subscription_id` (optional if your `az` default is correct)

### Step B2: Deploy Azure resources

```bash
terraform -chdir=terraform/azure init
terraform -chdir=terraform/azure apply
```

### Step B3: Capture Vault connection details

```bash
export VAULT_ADDR="$(terraform -chdir=terraform/azure output -raw vault_address)"
export VAULT_TOKEN="$(terraform -chdir=terraform/azure output -raw vault_root_token)"
echo "$VAULT_ADDR"
```

### Step B4: Bootstrap Vault configuration

Option 1 (single script):

```bash
./scripts/azure-bootstrap-vault.sh
```

Option 2 (manual Terraform apply):

```bash
terraform -chdir=terraform/vault init
terraform -chdir=terraform/vault apply \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_token=${VAULT_TOKEN}" \
  -var='environment=azure'
```

---

## 7. Path C - Adopt existing Azure resources and secure them with Vault

This path is for brownfield environments where resources already exist.

What this stack does (`terraform/azure-existing`):

1. Imports an existing resource group and storage account into Terraform state.
2. Keeps them in **adoption mode** (`prevent_destroy`, `ignore_changes = all`) to avoid accidental changes.
3. Writes sensitive storage account access details to Vault KV v2.

### Step C1: Ensure Vault is ready

Use either local Vault (Path A) or Azure Vault (Path B), then export:

```bash
export VAULT_ADDR="<your-vault-address>"
export VAULT_TOKEN="<your-vault-admin-token>"
```

### Step C2: Prepare import variables

```bash
cp terraform/azure-existing/terraform.tfvars.example terraform/azure-existing/terraform.tfvars
```

Edit `terraform/azure-existing/terraform.tfvars`:

- `resource_group_name`
- `resource_group_location`
- `storage_account_name`
- storage account SKU/kind values (must match existing resource)
- `vault_addr`, `vault_token`

If your KV mount already exists at `app`, keep `create_kv_mount = false`.
Set it to `true` only when you need Terraform to create the mount.

### Step C3: Import + apply in one run (declarative import blocks)

```bash
terraform -chdir=terraform/azure-existing init
terraform -chdir=terraform/azure-existing apply
```

### Step C4: Verify imported state and Vault secret

```bash
terraform -chdir=terraform/azure-existing state list
terraform -chdir=terraform/azure-existing output
vault kv get app/platform/azure/storage-account
```

The secret contains:

- storage account name
- primary access key
- primary connection string
- blob endpoint

### Step C5: Day 2 use case with imported resources

Use Vault as the operational source of truth for access credentials instead of sharing keys directly in scripts/pipelines.

---

## 8. Day 2 operations (live demo script)

### Operation 1: Rotate runtime secret now

```bash
terraform -chdir=terraform/vault apply -replace=time_rotating.runtime_secret
```

### Operation 2: Rotate AppRole SecretID now

```bash
terraform -chdir=terraform/vault apply -replace=time_rotating.approle_secret_id
```

### Operation 3: Show machine authentication flow

```bash
vault read auth/approle/role/demo-app/role-id
vault write auth/approle/login role_id="<ROLE_ID>" secret_id="<SECRET_ID>"
```

### Operation 4: Update policy as code

Edit policy blocks in `terraform/vault/main.tf` and re-apply:

```bash
terraform -chdir=terraform/vault apply
```

---

## 9. Teardown / cleanup

Local:

```bash
make local-down
```

Azure:

```bash
terraform -chdir=terraform/azure destroy
```

If you adopted existing resources and want to stop managing them in Terraform state (without deleting Azure resources):

```bash
terraform -chdir=terraform/azure-existing state rm azurerm_storage_account.existing
terraform -chdir=terraform/azure-existing state rm azurerm_resource_group.existing
```

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `terraform: command not found` | Terraform not installed or not in `PATH` | Install Terraform >= 1.6 and reopen terminal. |
| `Error: failed to query available provider packages` | Network/proxy restrictions to registry | Configure corporate proxy, then retry `terraform init`. |
| `Vault was not reachable` in local mode | Container still starting or port conflict on 8200 | Run `docker compose logs -f vault`; stop conflicting process and re-run `make local-up`. |
| `permission denied` running script | Script lost executable bit | Run `chmod +x scripts/*.sh`. |
| `Error building AzureRM Client` | `az login` missing or wrong subscription context | Run `az login` and `az account set --subscription <SUBSCRIPTION_ID>`. |
| `dns_name_label` / naming error on Azure | Name collision or invalid naming | Change `name_prefix` and re-apply. |
| `connect: connection refused` when bootstrapping Azure Vault | ACI not ready yet | Wait 30-60s, check ACI status, then retry vault bootstrap. |
| Vault commands return `permission denied` | Wrong token in shell | `export VAULT_TOKEN=<root token from terraform output>` and retry. |
| AppRole login fails with invalid secret id | SecretID rotated or stale value | Fetch latest output and retry login after rotation apply. |
| `Error: Cannot import non-existent remote object` | Wrong resource names/subscription in `azure-existing` vars | Confirm resource IDs in Azure and update `resource_group_name`, `storage_account_name`, `subscription_id`. |
| Import succeeds but plan wants to update existing resource | SKU/location/kind vars do not match current Azure resource | Set variables to exact live values or keep adoption mode as-is and avoid mutation. |
| `Error writing secret` in `azure-existing` apply | KV mount path does not exist | Set `create_kv_mount=true` once, or use existing mount path in `vault_kv_mount`. |

---

## 11. Important safety notes

- This lab deploys Vault in **dev mode** for speed and simplicity.
- It is intentionally not production-hardened.
- For production, use TLS, persistent Raft storage, auto-unseal, private networking, least-privilege identity, secure token handling, and audit logging.
