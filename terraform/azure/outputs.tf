output "resource_group_name" {
  description = "Resource group containing the demo stack."
  value       = azurerm_resource_group.demo.name
}

output "vault_address" {
  description = "Public Vault HTTP endpoint."
  value       = "http://${azurerm_container_group.vault.fqdn}:8200"
}

output "vault_root_token" {
  description = "Vault root token configured for dev mode."
  value       = var.vault_root_token
  sensitive   = true
}

output "storage_account_name" {
  description = "Storage account provisioned as a sample workload target."
  value       = azurerm_storage_account.demo.name
}

