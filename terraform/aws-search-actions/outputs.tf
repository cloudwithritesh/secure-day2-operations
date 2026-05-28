output "selected_bucket_name" {
  description = "S3 bucket selected via explicit name or search filters."
  value       = aws_s3_bucket.existing.id
}

output "vault_secret_path" {
  description = "Vault path that stores the day-2 action metadata."
  value       = var.enable_vault_sync ? "${var.vault_kv_mount}/data/${var.vault_secret_name}" : null
}
