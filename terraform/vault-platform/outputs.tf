output "kv_mount_path" {
  description = "KV v2 mount path for all app secrets"
  value       = vault_mount.secrets.path
}

output "app_role_name" {
  description = "AppRole name for the application"
  value       = vault_approle_auth_backend_role.app.role_name
}

output "rotator_role_name" {
  description = "AppRole name for the rotation service"
  value       = vault_approle_auth_backend_role.rotator.role_name
}

output "app_role_id" {
  description = "RoleID for the application AppRole — safe to store in CI/CD vars"
  value       = data.vault_approle_auth_backend_role_id.app.role_id
}

output "rotator_role_id" {
  description = "RoleID for the rotator AppRole — safe to store in CI/CD vars"
  value       = data.vault_approle_auth_backend_role_id.rotator.role_id
}

output "db_credentials_path" {
  description = "Full KV path the app reads for its DB credentials"
  value       = "${vault_mount.secrets.path}/data/${vault_kv_secret_v2.db_credentials.name}"
}

output "app_reader_policy" {
  description = "Policy assigned to the app AppRole — read-only to its own path"
  value       = vault_policy.app_reader.name
}

output "rotator_policy" {
  description = "Policy assigned to the rotator — only creates new SecretIDs"
  value       = vault_policy.secret_rotator.name
}

output "demo_hint" {
  description = "Reminder: never output secret_id from this workspace"
  value       = "SecretID must be distributed out-of-band (CI/CD var, manual inject, or rotation workspace)"
}
