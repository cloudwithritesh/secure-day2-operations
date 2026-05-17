#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

vault_addr="$(terraform -chdir="${repo_root}/terraform/azure" output -raw vault_address)"
vault_token="$(terraform -chdir="${repo_root}/terraform/azure" output -raw vault_root_token)"

terraform -chdir="${repo_root}/terraform/vault" init
terraform -chdir="${repo_root}/terraform/vault" apply \
  -var="vault_addr=${vault_addr}" \
  -var="vault_token=${vault_token}" \
  -var="environment=azure"

