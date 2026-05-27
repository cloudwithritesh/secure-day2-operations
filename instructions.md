# Deployment Runbook (Executed Steps)

This file captures the exact steps executed to deploy the demo in a real Azure subscription.

## 1) Verified Azure authentication context

Command:

```bash
az account show --query "{name:name,id:id,tenant:tenantId,user:user.name,state:state}" -o json
```

Result:

- Subscription name: `your-subscription-name`
- Subscription ID: `151761fe-90ef-4c1c-9241-3frr418bd68`
- Tenant ID: `fa8daedc-b6e5-4da1-bded-f0a9532b687d`
- State: `Enabled`

## 2) Installed required CLIs in runtime

### 2.1 GitHub CLI

- Already present: `gh version 2.92.0`

### 2.2 Azure CLI

Installed via Python user packages and linked into runtime PATH:

```bash
python3 -m pip install --user --upgrade azure-cli
ln -sf "$HOME/Library/Python/3.9/bin/az" "/Users/rhegde/Library/Caches/copilot-desktop-gh-2.92.0/az"
```

Version verified:

- `az` version `2.79.0`

### 2.3 Terraform + Vault CLI

Installed binaries into runtime PATH:

```bash
curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_darwin_arm64.zip -o terraform.zip
curl -fsSL https://releases.hashicorp.com/vault/1.16.3/vault_1.16.3_darwin_arm64.zip -o vault.zip
```

Versions verified:

- `Terraform v1.9.8`
- `Vault v1.16.3`

## 3) Deployed Azure infrastructure (`terraform/azure`)

Working directory:

```bash
cd /Users/rhegde/my_work/GitHub_Repo/cloudwithritesh/secure-day2-operations
```

Commands executed:

```bash
SUB_ID="$(az account show --query id -o tsv)"
ROOT_TOKEN="day2-<generated-random-token>"

terraform -chdir=terraform/azure init -input=false
terraform -chdir=terraform/azure apply -auto-approve -input=false \
  -var="subscription_id=${SUB_ID}" \
  -var="vault_root_token=${ROOT_TOKEN}"
terraform -chdir=terraform/azure output -json
```

Resources created:

- Resource group: `rg-day2vaultdemo7959`
- Storage account: `day2vaultdemo7959`
- Azure Container Instance running Vault CE (dev mode)

Key output:

- Vault address: `http://day2vaultdemo-7959.southeastasia.azurecontainer.io:8200`

## 4) Bootstrapped Vault configuration (`terraform/vault`)

Commands executed:

```bash
VAULT_ADDR="$(terraform -chdir=terraform/azure output -raw vault_address)"
VAULT_TOKEN="$(terraform -chdir=terraform/azure output -raw vault_root_token)"

./scripts/wait-for-vault.sh "$VAULT_ADDR"

terraform -chdir=terraform/vault init -input=false
terraform -chdir=terraform/vault apply -auto-approve -input=false \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_token=${VAULT_TOKEN}" \
  -var='environment=azure'
terraform -chdir=terraform/vault output -json
```

Vault resources created:

- KV v2 mount: `app`
- Policies: `ops-admin`, `app-reader`
- Auth backend: `approle`
- AppRole: `demo-app`
- Rotating runtime secret at: `app/data/payments-api/runtime`
- Rotating SecretID for AppRole

## 5) Post-deployment validation

Commands executed:

```bash
export VAULT_ADDR="$(terraform -chdir=terraform/azure output -raw vault_address)"
export VAULT_TOKEN="$(terraform -chdir=terraform/azure output -raw vault_root_token)"

vault status
vault kv get app/payments-api/runtime
vault read auth/approle/role/demo-app/role-id
```

Validation observed:

- Vault initialized and unsealed
- Runtime secret exists under KV v2 path
- AppRole role ID is retrievable

## 6) Notes

- Sensitive values (Vault root token, runtime secret password, AppRole SecretID) were generated and applied successfully but are intentionally not duplicated here.
- This deployment is in Vault **dev mode** for demo use.

## 7) Terraform Search + Import + Invoke Action demo (isolated resource)

Per request, this demo was executed on a **new isolated Azure resource** and not on live existing infrastructure.

### 7.1 Created fresh Azure resources with Azure CLI

Commands executed:

```bash
az group create --name rg-tfsearch-demo-05262326903 --location southeastasia \
  --tags scenario=tf-search-actions-demo created-by=copilot-cli

az storage account create \
  --name tfsearch05262326903 \
  --resource-group rg-tfsearch-demo-05262326903 \
  --location southeastasia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --tags scenario=tf-search-actions-demo environment=demo created-by=copilot-cli
```

### 7.2 Added new Terraform stack

New folder:

- `terraform/azure-search-actions`

Purpose:

1. Search existing resources using `data.azurerm_resources`.
2. Import selected resource group and storage account with declarative `import` blocks.
3. Invoke Azure day-2 operation (`regenerateKey`) through `azapi_resource_action`.
4. Sync updated credentials to Vault KV v2.

### 7.3 Applied Terraform Search + Import + Action stack

Commands executed:

```bash
terraform -chdir=terraform/azure-search-actions init
terraform -chdir=terraform/azure-search-actions validate
terraform -chdir=terraform/azure-search-actions apply -auto-approve \
  -var="subscription_id=151761fe-10ae-4c1c-9241-2e45cc18bd68" \
  -var="resource_group_name=rg-tfsearch-demo-05262326903" \
  -var="storage_account_name=tfsearch05262326903" \
  -var='search_required_tags={scenario="tf-search-actions-demo"}' \
  -var="vault_addr=$(terraform -chdir=terraform/azure output -raw vault_address)" \
  -var="vault_token=$(terraform -chdir=terraform/azure output -raw vault_root_token)" \
  -var='vault_kv_mount=app' \
  -var='vault_secret_name=platform/azure/search-actions-storage-account' \
  -var='storage_key_to_regenerate=key1' \
  -var='invoke_action_nonce=demo-run-1'
```

Result:

- Imported:
  - `azurerm_resource_group.existing`
  - `azurerm_storage_account.existing`
- Created:
  - `terraform_data.invoke_nonce`
  - `azapi_resource_action.regenerate_storage_key`
  - `vault_kv_secret_v2.storage_account_access`

Key outputs:

- `selected_storage_account_name = tfsearch05262326903`
- `vault_secret_path = app/data/platform/azure/search-actions-storage-account`

### 7.4 Demonstrated day-2 invoke action re-run

Command executed:

```bash
terraform -chdir=terraform/azure-search-actions apply -auto-approve \
  -var="subscription_id=151761fe-10ae-4c1c-9241-2e45cc18bd68" \
  -var="resource_group_name=rg-tfsearch-demo-05262326903" \
  -var="storage_account_name=tfsearch05262326903" \
  -var='search_required_tags={scenario="tf-search-actions-demo"}' \
  -var="vault_addr=$(terraform -chdir=terraform/azure output -raw vault_address)" \
  -var="vault_token=$(terraform -chdir=terraform/azure output -raw vault_root_token)" \
  -var='vault_kv_mount=app' \
  -var='vault_secret_name=platform/azure/search-actions-storage-account' \
  -var='storage_key_to_regenerate=key1' \
  -var='invoke_action_nonce=demo-run-2'
```

Observed behavior:

- Terraform replaced and re-created `azapi_resource_action.regenerate_storage_key`.
- Vault secret at `app/platform/azure/search-actions-storage-account` updated to **version 2** with `action_nonce=demo-run-2`.

## 8) Commented command blocks (run one-by-one)

Use these as copy-ready snippets. Remove `#` from one line at a time when you execute.

### 8.1 Verify login and subscription

```bash
# az login
# az account show
# az account show --query "{name:name,id:id,tenant:tenantId,user:user.name,state:state}" -o json
```

### 8.2 Deploy base Azure + Vault demo

```bash
# cd /Users/rhegde/my_work/GitHub_Repo/cloudwithritesh/secure-day2-operations
# SUB_ID="$(az account show --query id -o tsv)"
# ROOT_TOKEN="day2-<your-random-token>"
# terraform -chdir=terraform/azure init -input=false
# terraform -chdir=terraform/azure apply -auto-approve -input=false \
#   -var="subscription_id=${SUB_ID}" \
#   -var="vault_root_token=${ROOT_TOKEN}"
# export VAULT_ADDR="$(terraform -chdir=terraform/azure output -raw vault_address)"
# export VAULT_TOKEN="$(terraform -chdir=terraform/azure output -raw vault_root_token)"
# ./scripts/wait-for-vault.sh "$VAULT_ADDR"
# terraform -chdir=terraform/vault init -input=false
# terraform -chdir=terraform/vault apply -auto-approve -input=false \
#   -var="vault_addr=${VAULT_ADDR}" \
#   -var="vault_token=${VAULT_TOKEN}" \
#   -var='environment=azure'
```

### 8.3 Create isolated search/action demo resource with Azure CLI

```bash
# SUFFIX="$(date +%m%d%H%M)$((RANDOM%900+100))"
# RG="rg-tfsearch-demo-${SUFFIX}"
# SA="tfsearch${SUFFIX}"
# az group create --name "$RG" --location southeastasia --tags scenario=tf-search-actions-demo created-by=lab
# az storage account create \
#   --name "$SA" \
#   --resource-group "$RG" \
#   --location southeastasia \
#   --sku Standard_LRS \
#   --kind StorageV2 \
#   --min-tls-version TLS1_2 \
#   --tags scenario=tf-search-actions-demo environment=demo created-by=lab
```

### 8.4 Run Terraform Search + Import + Invoke Action

```bash
# SUB_ID="$(az account show --query id -o tsv)"
# VAULT_ADDR="$(terraform -chdir=terraform/azure output -raw vault_address)"
# VAULT_TOKEN="$(terraform -chdir=terraform/azure output -raw vault_root_token)"
# terraform -chdir=terraform/azure-search-actions init
# terraform -chdir=terraform/azure-search-actions apply -auto-approve \
#   -var="subscription_id=${SUB_ID}" \
#   -var="resource_group_name=${RG}" \
#   -var="storage_account_name=${SA}" \
#   -var='search_required_tags={scenario="tf-search-actions-demo"}' \
#   -var="vault_addr=${VAULT_ADDR}" \
#   -var="vault_token=${VAULT_TOKEN}" \
#   -var='vault_kv_mount=app' \
#   -var='vault_secret_name=platform/azure/search-actions-storage-account' \
#   -var='storage_key_to_regenerate=key1' \
#   -var='invoke_action_nonce=demo-run-1'
```

### 8.5 Re-run action for day-2 operation

```bash
# terraform -chdir=terraform/azure-search-actions apply -auto-approve \
#   -var="subscription_id=${SUB_ID}" \
#   -var="resource_group_name=${RG}" \
#   -var="storage_account_name=${SA}" \
#   -var='search_required_tags={scenario="tf-search-actions-demo"}' \
#   -var="vault_addr=${VAULT_ADDR}" \
#   -var="vault_token=${VAULT_TOKEN}" \
#   -var='vault_kv_mount=app' \
#   -var='vault_secret_name=platform/azure/search-actions-storage-account' \
#   -var='storage_key_to_regenerate=key1' \
#   -var='invoke_action_nonce=demo-run-2'
```

### 8.6 Cleanup

```bash
# terraform -chdir=terraform/azure-search-actions destroy -auto-approve \
#   -var="subscription_id=${SUB_ID}" \
#   -var="resource_group_name=${RG}" \
#   -var="storage_account_name=${SA}" \
#   -var='search_required_tags={scenario="tf-search-actions-demo"}' \
#   -var="vault_addr=${VAULT_ADDR}" \
#   -var="vault_token=${VAULT_TOKEN}" \
#   -var='vault_kv_mount=app' \
#   -var='vault_secret_name=platform/azure/search-actions-storage-account' \
#   -var='storage_key_to_regenerate=key1' \
#   -var='invoke_action_nonce=demo-run-2'
# az group delete --name "$RG" --yes
# terraform -chdir=terraform/vault destroy -auto-approve \
#   -var="vault_addr=${VAULT_ADDR}" \
#   -var="vault_token=${VAULT_TOKEN}" \
#   -var='environment=azure'
# terraform -chdir=terraform/azure destroy -auto-approve \
#   -var="subscription_id=${SUB_ID}" \
#   -var="vault_root_token=${VAULT_TOKEN}"
```
