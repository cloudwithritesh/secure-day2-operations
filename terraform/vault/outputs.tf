output "kv_mount_path" {
  description = "KV engine path used for app secrets."
  value       = vault_mount.app_kv.path
}

output "approle_backend_path" {
  description = "AppRole auth backend path."
  value       = vault_auth_backend.approle.path
}

output "approle_role_name" {
  description = "AppRole name for applications."
  value       = vault_approle_auth_backend_role.demo_app.role_name
}

output "demo_app_secret_id" {
  description = "Current SecretID for demo-app AppRole."
  value       = vault_approle_auth_backend_role_secret_id.demo_app.secret_id
  sensitive   = true
}

output "runtime_secret_path" {
  description = "Path of rotated runtime secret."
  value       = "app/data/payments-api/runtime"
}

