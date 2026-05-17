# Secure Day 2 Operations Demo (Terraform + Vault CE on Azure)

This repo is a **30-minute demo kit** for securing Day 2 operations with:
- **Terraform** for repeatable infrastructure and Vault configuration
- **Vault Community Edition** for policy-based secret management and rotation
- **Azure** as the cloud target

It supports both:
- **Local mode** (Vault CE via Docker)
- **Cloud mode** (Vault CE on Azure Container Instances)

## Demo flow

1. Deploy Vault CE (local Docker or Azure ACI)
2. Bootstrap Vault with Terraform:
   - KV v2 secrets engine
   - least-privilege policies
   - AppRole auth for machine-to-machine access
   - time-based secret rotation
3. Show Day 2 operations:
   - rotate runtime secrets
   - rotate AppRole SecretID
   - update policy as code

## Repository layout

```text
.
├── docker-compose.yml
├── Makefile
├── scripts
│   ├── azure-bootstrap-vault.sh
│   └── wait-for-vault.sh
└── terraform
    ├── azure
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   ├── variables.tf
    │   └── versions.tf
    └── vault
        ├── main.tf
        ├── outputs.tf
        ├── terraform.tfvars.example
        ├── variables.tf
        └── versions.tf
```

## Prerequisites

- Terraform >= 1.6
- Docker Desktop (for local mode)
- Azure CLI (`az`) and an Azure subscription
- `curl`

## Local mode (run from your laptop)

```bash
docker compose up -d vault
./scripts/wait-for-vault.sh http://127.0.0.1:8200

cd terraform/vault
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Cloud mode (Azure)

```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Get Vault endpoint and token from Terraform outputs:

```bash
VAULT_ADDR="$(terraform -chdir=terraform/azure output -raw vault_address)"
VAULT_TOKEN="$(terraform -chdir=terraform/azure output -raw vault_root_token)"
```

Bootstrap Vault on Azure:

```bash
terraform -chdir=terraform/vault init
terraform -chdir=terraform/vault apply \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_token=${VAULT_TOKEN}" \
  -var="environment=azure"
```

Or run:

```bash
./scripts/azure-bootstrap-vault.sh
```

## Day 2 operations demo commands

Rotate runtime secret immediately:

```bash
terraform -chdir=terraform/vault apply -replace=time_rotating.runtime_secret
```

Rotate AppRole SecretID immediately:

```bash
terraform -chdir=terraform/vault apply -replace=time_rotating.approle_secret_id
```

Read role ID and login with AppRole:

```bash
vault read auth/approle/role/demo-app/role-id
vault write auth/approle/login role_id="<ROLE_ID>" secret_id="<SECRET_ID>"
```

## Demo safety notes

- Azure Vault deployment in this demo uses **dev mode** for speed.
- Do not use this configuration as-is for production.
- For production: TLS, Raft storage, auto-unseal, private networking, and hardened root token handling are required.

