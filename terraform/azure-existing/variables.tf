variable "subscription_id" {
  description = "Azure subscription ID. Leave empty to use az CLI default context."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Existing Azure resource group name."
  type        = string
}

variable "resource_group_location" {
  description = "Azure location of the existing resource group."
  type        = string
}

variable "storage_account_name" {
  description = "Existing Azure Storage Account name to import."
  type        = string
}

variable "storage_account_tier" {
  description = "Performance tier of the existing storage account."
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Replication type of the existing storage account."
  type        = string
  default     = "LRS"
}

variable "storage_account_kind" {
  description = "Kind of the existing storage account."
  type        = string
  default     = "StorageV2"
}

variable "storage_account_access_tier" {
  description = "Access tier of the existing storage account."
  type        = string
  default     = "Hot"
}

variable "tags" {
  description = "Optional tags to keep in configuration."
  type        = map(string)
  default     = {}
}

variable "vault_addr" {
  description = "Vault API endpoint used to secure imported resource secrets."
  type        = string
}

variable "vault_token" {
  description = "Vault admin token for bootstrap operations."
  type        = string
  sensitive   = true
}

variable "vault_kv_mount" {
  description = "KV v2 mount where Azure secrets are written."
  type        = string
  default     = "app"
}

variable "vault_secret_name" {
  description = "Secret path (inside mount) for imported Azure resource credentials."
  type        = string
  default     = "platform/azure/storage-account"
}

variable "create_kv_mount" {
  description = "Create the KV mount if it does not already exist."
  type        = bool
  default     = false
}

