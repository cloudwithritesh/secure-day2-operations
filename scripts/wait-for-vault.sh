#!/usr/bin/env bash
set -euo pipefail

vault_addr="${1:-http://127.0.0.1:8200}"

for _ in $(seq 1 60); do
  if curl -fsS "${vault_addr}/v1/sys/health" >/dev/null 2>&1; then
    echo "Vault is reachable at ${vault_addr}"
    exit 0
  fi
  sleep 2
done

echo "Vault was not reachable at ${vault_addr} after waiting." >&2
exit 1

