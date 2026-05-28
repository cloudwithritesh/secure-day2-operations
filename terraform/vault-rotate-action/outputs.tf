output "rotation_schedule" {
  description = "Time window that governs automatic rotation"
  value       = "Every ${var.rotation_hours} hours (next rotation when time_rotating fires)"
}

output "last_rotation_time" {
  description = "Timestamp of the last successful rotation (from KV metadata)"
  value       = try(data.vault_kv_secret_v2.current_secret_id_meta.data["rotated_at"], "not yet rotated")
  sensitive   = true
}

output "secret_id_accessor" {
  description = "Accessor of the current SecretID — use to revoke if needed"
  value       = try(data.vault_kv_secret_v2.current_secret_id_meta.data["accessor"], "not yet rotated")
  sensitive   = true
}

output "kv_path_for_consumers" {
  description = "Where downstream automation should read the fresh SecretID from"
  value       = "${var.kv_mount}/${var.app_role_name}/current-secret-id"
}

output "rotation_mode_hint" {
  description = "How to trigger rotation modes"
  value = {
    scheduled  = "CI/CD runs 'terraform apply' on a cron schedule — rotation fires automatically when time window elapses"
    on_demand  = "Change var.rotation_nonce and re-apply — e.g., TF_VAR_rotation_nonce=emergency-$(date +%s)"
    emergency  = "VAULT_TOKEN=<rotator-token> vault write -f auth/approle/role/${var.app_role_name}/secret-id"
  }
}
