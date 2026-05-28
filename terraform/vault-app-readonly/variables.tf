variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "approle_token" {
  description = "Scoped AppRole token obtained via vault write auth/approle/login (payments-app-reader policy)"
  type        = string
  sensitive   = true
}

variable "kv_mount" {
  description = "KV v2 mount path where the app secrets live"
  type        = string
  default     = "secrets"
}

variable "secret_path" {
  description = "Path inside the KV mount the app is allowed to read"
  type        = string
  default     = "payments-api/db-credentials"
}
