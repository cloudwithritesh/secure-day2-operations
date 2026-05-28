# Demo Runbook — Securing Day 2 Operations with Terraform + Vault

> **Session duration:** 30 minutes  
> **Audience:** Platform/DevOps engineers  
> **Scenarios:** 3 — Basics → Search/Import/Invoke → Secure Credential Renewal

---

## Session overview

| # | Scenario | Workspace | Time | Theme |
|---|---|---|---|---|
| 1 | Terraform + Vault Basics | `terraform/vault/` | ~8 min | Secrets as code, auto-rotating secrets |
| 2 | Search + Import + Invoke Action | `terraform/azure-search-actions/` | ~10 min | Bring existing Azure resources under Terraform + rotate their keys into Vault |
| 3 | Secure Credential Renewal | `vault-platform` → `vault-app-readonly` → `vault-rotate-action` | ~10 min | AppRoles, least-privilege, zero manual intervention |

---

## Pre-flight checklist (do this before the session)

```bash
# 1. Start local Vault
docker-compose up -d vault
sleep 3

# 2. Verify Vault is healthy
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"
vault status

# 3. Confirm clean slate
vault secrets list   # should show only built-ins: cubbyhole/, identity/, secret/, sys/
vault auth list      # should show only token/

# 4. Verify Terraform and Vault CLIs
terraform version
vault version
jq --version

# 5. For Scenario 2 — authenticate to Azure
az login
export SUB_ID=$(az account show --query id -o tsv)
```

---

# Scenario 1 — Terraform + Vault Basics (~8 min)

> **Theme:** Secrets as code. Vault is the source of truth. Terraform manages everything.

---

## S1 Step 1 — Open the show (1 min)

**Say:** *"Vault is running locally in dev mode via Docker. In production this would be an ACI container in Azure. The root token is `root` — fine for demo, not production."*

```bash
vault status
vault secrets list
vault auth list
```

**Key message:** Clean slate — no AppRoles, no policies, no app secrets yet.

---

## S1 Step 2 — Apply the vault basics workspace (4 min)

**Say:** *"We're going to let Terraform create everything in Vault — the KV engine, the policies, the AppRole, and a rotating secret. All in code, all version-controlled."*

Show the file first:

```bash
cat terraform/vault/main.tf
```

**Point out:**
- `vault_mount` — KV v2 engine at `app/`
- `vault_policy.ops_admin` / `vault_policy.app_reader` — two policies, different scopes
- `vault_approle_auth_backend_role.demo_app` — AppRole with 1 hr token TTL
- `time_rotating` + `random_password` + `vault_kv_secret_v2` — **auto-rotating secret**: password regenerates every N days automatically
- `vault_approle_auth_backend_role_secret_id` — SecretID also tied to a rotation schedule

**Run it:**

```bash
terraform -chdir=terraform/vault apply -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var="environment=local" \
  -var="rotation_days=7" \
  -var="approle_secret_rotation_hours=24"
```

**Expected output:**

```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:
  kv_mount_path       = "app"
  approle_backend_path = "approle"
  approle_role_name   = "demo-app"
  demo_app_secret_id  = <sensitive>
  runtime_secret_path = "app/data/payments-api/runtime"
```

---

## S1 Step 3 — Inspect what Terraform created in Vault (2 min)

```bash
# Show the KV mount and the rotating secret
vault kv get app/payments-api/runtime

# Show the AppRole
vault read auth/approle/role/demo-app

# Show the policies
vault policy read app-reader
vault policy read ops-admin
```

**Key message for `app-reader` policy:** It can only read `app/data/payments-api/*` — nothing else in Vault.

---

## S1 Step 4 — Show the rotation trigger (1 min)

**Say:** *"If I re-apply with `rotation_days=0` (for demo), `time_rotating` fires, `random_password` gets new `keepers`, regenerates, and Terraform writes the new password to Vault — zero human involvement."*

```bash
# In real demo just show the concept — changing rotation_days forces a new password
terraform -chdir=terraform/vault plan \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var="environment=local" \
  -var="rotation_days=7" \
  -var="approle_secret_rotation_hours=24" 2>&1 | grep -E "No changes|random_password|vault_kv"
```

**Key message:** `time_rotating` is the cron job replacement. CI/CD runs `terraform apply` on schedule — rotation is automatic.

---

# Scenario 2 — Terraform Search + Import + Invoke Action (~10 min)

> **Theme:** Existing Azure resources brought under Terraform control. Keys rotated via API action. Result synced to Vault.

---

## S2 Step 1 — Create a fresh Azure resource to import (2 min)

**Say:** *"We'll create one real Azure storage account with the CLI — representing an existing resource that predates Terraform."*

```bash
SUFFIX=$(date +%m%d%H%M%S)
RG="rg-tfsearch-demo-${SUFFIX}"
SA="tfsearch${SUFFIX}"

az group create --name "$RG" --location southeastasia \
  --tags scenario=tf-search-actions-demo

az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --tags scenario=tf-search-actions-demo

echo "RG=$RG"
echo "SA=$SA"
```

---

## S2 Step 2 — Show the workspace (1 min)

```bash
cat terraform/azure-search-actions/main.tf
```

**Point out these key sections:**

1. **`data "azurerm_resources"`** (line 7) — searches Azure for storage accounts matching the tag filter — no hardcoded IDs
2. **`import { to = ... id = ... }`** (lines 54–62) — declarative import, Terraform 1.6+ syntax. No `terraform import` CLI needed.
3. **`azapi_resource_action.regenerate_storage_key`** (line 68) — calls Azure's `regenerateKey` ARM API directly from Terraform
4. **`replace_triggered_by = [terraform_data.invoke_nonce]`** (line 81) — nonce change forces key regeneration on demand
5. **`vault_kv_secret_v2.storage_account_access`** (line 93) — result (new key + metadata) written to Vault immediately

---

## S2 Step 3 — Apply: search, import, rotate, sync to Vault (5 min)

```bash
# Ensure Vault basics workspace is still applied (scenario 1 must be done first)
# The app KV mount at "app/" is used by this workspace

terraform -chdir=terraform/azure-search-actions init

terraform -chdir=terraform/azure-search-actions apply -auto-approve \
  -var="subscription_id=${SUB_ID}" \
  -var="resource_group_name=${RG}" \
  -var="storage_account_name=${SA}" \
  -var='search_required_tags={"scenario":"tf-search-actions-demo"}' \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var='vault_kv_mount=app' \
  -var='vault_secret_name=platform/azure/search-actions-storage-account' \
  -var='storage_key_to_regenerate=key1' \
  -var='invoke_action_nonce=demo-run-1'
```

**Expected output:**

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:
  search_matches    = ["<storage-account-name>"]
  vault_secret_path = "app/data/platform/azure/search-actions-storage-account"
```

**Verify in Vault:**

```bash
vault kv get app/platform/azure/search-actions-storage-account
```

---

## S2 Step 4 — Day 2: rotate the key again on demand (2 min)

**Say:** *"Key needs rotating again — audit finding, breach, policy deadline. One variable change."*

```bash
terraform -chdir=terraform/azure-search-actions apply -auto-approve \
  -var="subscription_id=${SUB_ID}" \
  -var="resource_group_name=${RG}" \
  -var="storage_account_name=${SA}" \
  -var='search_required_tags={"scenario":"tf-search-actions-demo"}' \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var='vault_kv_mount=app' \
  -var='vault_secret_name=platform/azure/search-actions-storage-account' \
  -var='storage_key_to_regenerate=key1' \
  -var='invoke_action_nonce=demo-run-2'
```

```bash
# Show Vault KV advanced to version 2
vault kv metadata get app/platform/azure/search-actions-storage-account
```

**Key messages:**
1. `invoke_action_nonce=demo-run-2` → `terraform_data` replaces → `azapi_resource_action` fires → new key generated in Azure → written to Vault
2. `current_version = 2` in KV metadata = full audit history of every rotation

---

## S2 Cleanup

```bash
az group delete --name "$RG" --yes --no-wait
terraform -chdir=terraform/azure-search-actions destroy -auto-approve \
  -var="subscription_id=${SUB_ID}" \
  -var="resource_group_name=${RG}" \
  -var="storage_account_name=${SA}" \
  -var='search_required_tags={"scenario":"tf-search-actions-demo"}' \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var='vault_kv_mount=app' \
  -var='vault_secret_name=platform/azure/search-actions-storage-account' \
  -var='storage_key_to_regenerate=key1' \
  -var='invoke_action_nonce=demo-run-2'
```

---

# Scenario 3 — Secure Credential Renewal (~10 min)

> **Theme:** Three workspaces, three trust levels. AppRoles enforce least-privilege. Rotation is fully automated — no human ever touches a SecretID again.

## S3 Step 1 — Show clean Vault (1 min)

**Say:** *"Clean setup — Vault running, no existing policies or AppRoles yet."*

```bash
vault status
vault secrets list
vault auth list
```

**Key message:** Clean slate — no AppRoles, no policies, no app secrets yet.

---

## S3 Step 2 — Platform team deploys policies + AppRoles (5 min)

**Say:** *"The platform team owns this workspace. App teams never touch it. They define the trust boundaries in code."*

Show the policy file:

```bash
cat terraform/vault-platform/main.tf
```

**Point out:**
- 3 policies: `platform-admin`, `payments-app-reader` (read 1 path only), `payments-rotator` (generate SecretIDs + write 1 KV path)
- 2 AppRoles: `payments-app` (1 hr token TTL) + `payments-rotator` (10 min, single-use SecretID)
- Outputs only `role_id` — **never `secret_id`**

**Run it:**

```bash
terraform -chdir=terraform/vault-platform apply -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var="app_name=payments" \
  -var="environment=dev"
```

**Expected output:**

```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
  app_role_id         = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   ← safe to share
  rotator_role_id     = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"   ← safe to share
  kv_mount_path       = "secrets"
  db_credentials_path = "secrets/data/payments-api/db-credentials"
  demo_hint           = "SecretID must be distributed out-of-band..."
```

**Key message:** `secret_id` is nowhere in the output — by design.

---

## S3 Step 3 — Bootstrap: distribute the first SecretID (3 min)

**Say:** *"This is the ONE time a human is involved. After this, everything is automated."*

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

# Get RoleIDs from Terraform outputs (safe to store in CI/CD vars)
APP_ROLE_ID=$(terraform -chdir=terraform/vault-platform output -raw app_role_id)
ROTATOR_ROLE_ID=$(terraform -chdir=terraform/vault-platform output -raw rotator_role_id)

# Platform team generates the first SecretIDs (distributed out-of-band)
APP_SECRET_ID=$(vault write -format=json -f auth/approle/role/payments-app/secret-id \
  | jq -r '.data.secret_id')
ROTATOR_SECRET_ID=$(vault write -format=json -f auth/approle/role/payments-rotator/secret-id \
  | jq -r '.data.secret_id')

# Login with both AppRoles to get scoped tokens
APP_TOKEN=$(vault write -format=json auth/approle/login \
  role_id="$APP_ROLE_ID" secret_id="$APP_SECRET_ID" | jq -r '.auth.client_token')
ROTATOR_TOKEN=$(vault write -format=json auth/approle/login \
  role_id="$ROTATOR_ROLE_ID" secret_id="$ROTATOR_SECRET_ID" | jq -r '.auth.client_token')

# Verify scopes
VAULT_TOKEN="$APP_TOKEN"      vault token lookup -format=json | jq -r '.data.policies'
VAULT_TOKEN="$ROTATOR_TOKEN"  vault token lookup -format=json | jq -r '.data.policies'
```

**Expected:**
```json
["default", "payments-app-reader"]   ← app token
["default", "payments-rotator"]      ← rotator token
```

**Key message:** Each token is scoped at Vault level — not enforced by code, by Vault itself.

---

## S3 Step 4 — App team workspace: least-privilege in action (5 min)

**Say:** *"The app team gets a token. Their Terraform provider uses it. They literally cannot do anything outside their one path."*

**Show the restriction:**

```bash
# What the app CAN do
VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$APP_TOKEN" \
  vault kv get secrets/payments-api/db-credentials

# What the app CANNOT do — 403
VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$APP_TOKEN" \
  vault policy list
```

**Expected:** `403 permission denied` on policy list — pause here for the audience.

**Now run the app Terraform workspace:**

```bash
terraform -chdir=terraform/vault-app-readonly apply -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="approle_token=${APP_TOKEN}" \
  -var="kv_mount=secrets" \
  -var="secret_path=payments-api/db-credentials"
```

**Expected output:**

```
Outputs:
  db_host        = <sensitive>
  db_name        = <sensitive>
  db_password    = <sensitive>   ← never in logs
  db_port        = <sensitive>
  db_user        = <sensitive>
  kv_path_read   = "secrets/data/payments-api/db-credentials"
  secret_version = 1
```

**Key messages:**
1. The `403` — policy enforcement lives in Vault, not in the app's code
2. All outputs are `<sensitive>` — db_password never appears in CI/CD logs

---

## S3 Step 5 — Automated rotation: the Day 2 money shot (7 min)

**Say:** *"This is the core of Day 2 operations. CI/CD runs `terraform apply` on a cron schedule. No human is ever involved again."*

Show the rotation workspace:

```bash
cat terraform/vault-rotate-action/main.tf
```

**Point out:**
- `time_rotating` = the schedule (24 hrs by default)
- `terraform_data` with `replace_triggered_by` = fires the `local-exec` when the timer elapses
- `local-exec` calls `vault write -f auth/approle/role/payments-app/secret-id` with the scoped rotator token
- New SecretID is written to KV — downstream automation reads it from there

**Run it:**

```bash
terraform -chdir=terraform/vault-rotate-action apply -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="rotator_token=${ROTATOR_TOKEN}" \
  -var="app_role_name=payments-app" \
  -var="kv_mount=secrets" \
  -var="rotation_nonce=initial"
```

**Expected output:**

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
  rotation_schedule     = "Every 24 hours (next rotation when time_rotating fires)"
  last_rotation_time    = <sensitive>
  kv_path_for_consumers = "secrets/payments-app/current-secret-id"
  rotation_mode_hint = {
    scheduled = "CI/CD runs 'terraform apply' on a cron schedule..."
    on_demand = "Change var.rotation_nonce and re-apply..."
    emergency = "VAULT_TOKEN=<rotator-token> vault write -f ..."
  }
```

**Key message:** The rotator token can ONLY generate SecretIDs + write to 1 KV path.
Even if this token were compromised, the blast radius is a single AppRole's SecretID.

---

## S3 Step 6 — Emergency rotation: one variable, instant rotation (3 min)

**Say:** *"Breach detected. We need to rotate NOW. No SSH. No Vault admin login. One variable change."*

```bash
terraform -chdir=terraform/vault-rotate-action apply -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="rotator_token=${ROTATOR_TOKEN}" \
  -var="app_role_name=payments-app" \
  -var="kv_mount=secrets" \
  -var="rotation_nonce=emergency-breach-detected"
```

**Then show the audit trail:**

```bash
# KV version history — each version = one rotation event
vault kv metadata get secrets/payments-app/current-secret-id
```

**Expected:**

```
current_version   = 3          ← 3 rotations happened
Version 1  created_time = ...  ← initial
Version 2  created_time = ...  ← scheduled
Version 3  created_time = ...  ← emergency nonce change
```

**Key messages:**
1. `rotation_nonce=emergency-breach-detected` → Terraform detects the change → `terraform_data` replaces → `local-exec` fires → new SecretID in ~3 seconds
2. The KV version history IS the audit log — immutable, timestamped, no extra tooling needed
3. Old SecretID is cryptographically superseded — even if an attacker had it, it's dead

---

## S3 Step 7 — The trust model summary (2 min)

**Say:** *"Three workspaces, three trust levels, zero privilege escalation."*

| Workspace | Runs as | Token scope | Can do |
|---|---|---|---|
| `vault-platform` | Platform team (manual) | Root / admin | Create policies, AppRoles, write secrets |
| `vault-app-readonly` | App CI/CD pipeline | `payments-app-reader` | Read own secret path ONLY |
| `vault-rotate-action` | Rotation CI/CD cron | `payments-rotator` | Generate SecretIDs + write 1 KV path |

**No workspace can escalate beyond its scoped token. Vault enforces this — not code.**

---

## Step 8 — Cleanup

```bash
# Destroy all three workspaces (reverse order)
terraform -chdir=terraform/vault-rotate-action destroy -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="rotator_token=${ROTATOR_TOKEN}"

terraform -chdir=terraform/vault-app-readonly destroy -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="approle_token=${APP_TOKEN}"

terraform -chdir=terraform/vault-platform destroy -auto-approve \
  -var="vault_addr=http://127.0.0.1:8200" \
  -var="vault_token=root" \
  -var="app_name=payments" \
  -var="environment=dev"

# Stop Vault
docker-compose down
```

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `403` on `vault kv put` | Policy path mismatch | Check `payments-rotator` policy — path must match `<kv_mount>/data/<app_role_name>/current-secret-id` |
| `403 failed to create limited child token` | Scoped token lacks `token/create` permission | Add `skip_child_token = true` to Vault provider |
| `Output refers to sensitive values` | `vault_kv_secret_v2` propagates sensitivity | Add `sensitive = true` to all outputs derived from KV data |
| Rotation `local-exec` fails with double `data/` path | `vault kv put` adds `data/` automatically for KV v2 | Use `vault kv put <mount>/<path>` NOT `<mount>/data/<path>` |
| `permission denied` on `vault kv metadata get` | Rotator policy missing `read` capability | Add `"read"` to the `secrets/data/<app_role_name>/current-secret-id` path in platform policy |
| Old rotator token still fails after policy update | Token was issued before policy change | Generate a fresh SecretID and login again to get a new token |
