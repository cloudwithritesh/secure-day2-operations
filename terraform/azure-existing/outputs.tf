output "imported_resource_group_id" {
  description = "Imported Azure resource group ID."
  value       = azurerm_resource_group.existing.id
}

output "imported_storage_account_id" {
  description = "Imported Azure storage account ID."
  value       = azurerm_storage_account.existing.id
}

output "vault_secret_path" {
  description = "Path to imported storage account secret in Vault KV v2."
  value       = "${local.kv_mount_path}/data/${var.vault_secret_name}"
}

