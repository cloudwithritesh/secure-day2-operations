variable "aws_region" {
  description = "AWS region for discovery, import, and action invocation."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI/profile name. Leave empty to use default credentials."
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "Optional S3 bucket name to target directly. If empty, search result is used."
  type        = string
  default     = ""
}

variable "search_tag_key" {
  description = "Tag key used by search filter for unmanaged instances."
  type        = string
  default     = "ManagedBy"
}

variable "search_tag_value" {
  description = "Tag value used by search filter for unmanaged buckets."
  type        = string
  default     = "unmanaged"
}

variable "invoke_action_nonce" {
  description = "Change this value to force the day-2 action (S3 versioning enable) to run again."
  type        = string
  default     = "demo-run-1"
}

variable "enable_vault_sync" {
  description = "When true, write day-2 action metadata to Vault KV."
  type        = bool
  default     = false
}

variable "vault_addr" {
  description = "Vault HTTP address."
  type        = string
  default     = ""
}

variable "vault_token" {
  description = "Vault token with write access to the target KV path."
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_kv_mount" {
  description = "Vault KV v2 mount path used to store operation metadata."
  type        = string
  default     = "app"
}

variable "vault_secret_name" {
  description = "Secret path name under the KV mount."
  type        = string
  default     = "platform/aws/s3-day2-action"
}
