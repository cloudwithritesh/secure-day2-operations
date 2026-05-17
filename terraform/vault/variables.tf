variable "vault_addr" {
  description = "Vault API endpoint."
  type        = string
}

variable "vault_token" {
  description = "Vault token with admin rights for bootstrap."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Target environment label (local or azure)."
  type        = string
  default     = "local"
}

variable "rotation_days" {
  description = "Rotation interval for runtime secrets."
  type        = number
  default     = 7
}

variable "approle_secret_rotation_hours" {
  description = "Rotation interval for AppRole SecretID."
  type        = number
  default     = 24
}

