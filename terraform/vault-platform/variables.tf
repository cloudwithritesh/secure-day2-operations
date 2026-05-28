variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault root/admin token (platform team only)"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment label (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application identifier used in policy and AppRole names"
  type        = string
  default     = "payments"
}

variable "secret_rotation_hours" {
  description = "How many hours between automatic SecretID rotations"
  type        = number
  default     = 24
}
