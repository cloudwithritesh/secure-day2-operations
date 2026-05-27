variable "subscription_id" {
  description = "Azure subscription ID. Leave empty to use az CLI default."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Target resource group where existing resources are discovered."
  type        = string
}

variable "storage_account_name" {
  description = "Optional exact storage account name. Leave empty to auto-select from search results."
  type        = string
  default     = ""
}

variable "search_required_tags" {
  description = "Optional tag filters used by Terraform search (azurerm_resources)."
  type        = map(string)
  default     = {}
}

variable "vault_addr" {
  description = "Vault API endpoint."
  type        = string
}

variable "vault_token" {
  description = "Vault token with write access."
  type        = string
  sensitive   = true
}

variable "vault_kv_mount" {
  description = "KV v2 mount where searched/imported resource secrets are written."
  type        = string
  default     = "app"
}

variable "vault_secret_name" {
  description = "Secret name under KV mount."
  type        = string
  default     = "platform/azure/search-actions-storage-account"
}

variable "storage_key_to_regenerate" {
  description = "Storage key name to rotate via invoke action (key1 or key2)."
  type        = string
  default     = "key1"
}

variable "invoke_action_nonce" {
  description = "Change this value to force re-invocation of key rotation action."
  type        = string
  default     = "initial-run"
}

