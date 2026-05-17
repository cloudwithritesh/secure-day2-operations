variable "subscription_id" {
  description = "Azure subscription ID. Leave empty to use az CLI default context."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for demo resources."
  type        = string
  default     = "southeastasia"
}

variable "name_prefix" {
  description = "Prefix for all Azure resources."
  type        = string
  default     = "day2vaultdemo"
}

variable "vault_version" {
  description = "Vault CE image tag."
  type        = string
  default     = "1.16"
}

variable "vault_root_token" {
  description = "Vault root token for dev mode."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply on Azure resources."
  type        = map(string)
  default = {
    environment = "demo"
    workload    = "secure-day2-operations"
  }
}

