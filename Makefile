TF_AZURE_DIR := terraform/azure
TF_AZURE_EXISTING_DIR := terraform/azure-existing
TF_VAULT_DIR := terraform/vault

.PHONY: local-up local-down local-logs local-bootstrap azure-init azure-apply azure-destroy azure-existing-init azure-existing-apply vault-init vault-fmt

local-up:
	docker compose up -d vault

local-down:
	docker compose down

local-logs:
	docker compose logs -f vault

local-bootstrap:
	./scripts/wait-for-vault.sh http://127.0.0.1:8200
	terraform -chdir=$(TF_VAULT_DIR) init
	terraform -chdir=$(TF_VAULT_DIR) apply -auto-approve \
		-var='vault_addr=http://127.0.0.1:8200' \
		-var='vault_token=root' \
		-var='environment=local'

azure-init:
	terraform -chdir=$(TF_AZURE_DIR) init

azure-apply:
	terraform -chdir=$(TF_AZURE_DIR) apply

azure-destroy:
	terraform -chdir=$(TF_AZURE_DIR) destroy

azure-existing-init:
	terraform -chdir=$(TF_AZURE_EXISTING_DIR) init

azure-existing-apply:
	terraform -chdir=$(TF_AZURE_EXISTING_DIR) apply

vault-init:
	terraform -chdir=$(TF_VAULT_DIR) init

vault-fmt:
	terraform fmt -recursive
