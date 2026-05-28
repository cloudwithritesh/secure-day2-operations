output "db_host" {
  description = "Database host (non-sensitive)"
  value       = local.db_config.host
}

output "db_port" {
  description = "Database port (non-sensitive)"
  value       = local.db_config.port
}

output "db_name" {
  description = "Database name (non-sensitive)"
  value       = local.db_config.name
}

output "db_user" {
  description = "Database service account username (non-sensitive)"
  value       = local.db_config.user
}

# Password is sensitive — only available to the process, not logged
output "db_password" {
  description = "Database password — marked sensitive, will not appear in logs"
  value       = data.vault_kv_secret_v2.db_credentials.data["db_password"]
  sensitive   = true
}

output "secret_version" {
  description = "KV secret version — can be used to detect stale cached creds"
  value       = data.vault_kv_secret_v2.db_credentials.version
}

output "kv_path_read" {
  description = "Full path that was read — confirms least-privilege scope"
  value       = "${var.kv_mount}/data/${var.secret_path}"
}
