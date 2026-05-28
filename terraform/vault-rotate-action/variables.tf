variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "rotator_token" {
  description = "AppRole token for the rotator role (only allowed to generate new SecretIDs)"
  type        = string
  sensitive   = true
}

variable "app_role_name" {
  description = "Name of the AppRole whose SecretID will be rotated"
  type        = string
  default     = "payments-app"
}

variable "kv_mount" {
  description = "KV v2 mount used to store the freshly generated SecretID"
  type        = string
  default     = "secrets"
}

variable "rotation_hours" {
  description = "How many hours between automatic SecretID rotations"
  type        = number
  default     = 24
}

variable "rotation_nonce" {
  description = "Change this value to trigger an on-demand SecretID rotation for demo purposes"
  type        = string
  default     = "initial"
}
