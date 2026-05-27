output "search_matches" {
  description = "Storage accounts discovered by Terraform search."
  value = [
    for r in data.azurerm_resources.storage_accounts.resources : {
      id   = r.id
      name = r.name
      type = r.type
    }
  ]
}

output "selected_storage_account_name" {
  description = "Selected storage account after optional filtering."
  value       = azurerm_storage_account.existing.name
}

output "invoke_action_trigger" {
  description = "Nonce value used to force invoke action."
  value       = var.invoke_action_nonce
}

output "vault_secret_path" {
  description = "Path where rotated storage key details are stored."
  value       = "${var.vault_kv_mount}/data/${var.vault_secret_name}"
}

