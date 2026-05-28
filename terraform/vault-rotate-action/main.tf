# =============================================================================
# vault-rotate-action / main.tf
# PURPOSE : Demonstrate automated SecretID rotation without manual intervention.
#
# KEY INSIGHT: The rotator provider token is scoped ONLY to:
#   1) Generate a new SecretID for payments-app AppRole
#   2) Write that SecretID into the secrets/payments-api/current-secret-id path
#
# HOW ROTATION IS TRIGGERED (two modes):
#   MODE A — Scheduled: time_rotating fires when rotation_hours window elapses.
#             CI/CD runs "terraform apply" on a cron schedule.
#   MODE B — On-demand: change var.rotation_nonce and re-apply.
#             Useful for emergency rotation without waiting for the timer.
# =============================================================================

# ---------------------------------------------------------------------------
# Rotation schedule — the core "no manual intervention" mechanism
# ---------------------------------------------------------------------------

resource "time_rotating" "secret_id" {
  rotation_hours = var.rotation_hours
}

# ---------------------------------------------------------------------------
# Nonce tracker — allows on-demand rotation during demo (or emergency)
# ---------------------------------------------------------------------------

resource "terraform_data" "rotation_trigger" {
  input = {
    nonce    = var.rotation_nonce
    schedule = time_rotating.secret_id.id
  }

  # Any change to the combined trigger value replaces this resource,
  # which in turn triggers the rotation provisioner below.
  lifecycle {
    replace_triggered_by = [time_rotating.secret_id]
  }
}

# ---------------------------------------------------------------------------
# Automated SecretID rotation  (Day 2 operation — no human required)
# ---------------------------------------------------------------------------

resource "terraform_data" "rotate_secret_id" {
  # This resource re-runs its provisioner whenever the trigger changes —
  # either because the time window elapsed OR the nonce was bumped.
  triggers_replace = {
    schedule = terraform_data.rotation_trigger.output.schedule
    nonce    = terraform_data.rotation_trigger.output.nonce
  }

  # Step 1: generate a fresh SecretID via the Vault API
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      echo "⏰  Rotating SecretID for AppRole: ${var.app_role_name}"
      echo "    Vault address : ${var.vault_addr}"
      echo "    Triggered at  : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo ""

      # Generate a new SecretID using the rotator-scoped token
      RESPONSE=$(vault write -format=json -f \
        auth/approle/role/${var.app_role_name}/secret-id)

      NEW_SECRET_ID=$(echo "$RESPONSE" | jq -r '.data.secret_id')
      ACCESSOR=$(echo "$RESPONSE"      | jq -r '.data.secret_id_accessor')

      echo "✅  New SecretID generated  (accessor: $ACCESSOR)"

      # Step 2: store the new SecretID in Vault KV for downstream consumption
      # (e.g., another Terraform workspace or a CI/CD pipeline reads it from here)
      vault kv put ${var.kv_mount}/${var.app_role_name}/current-secret-id \
        secret_id="$NEW_SECRET_ID" \
        rotated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        accessor="$ACCESSOR"

      echo "✅  SecretID written to Vault KV: ${var.kv_mount}/${var.app_role_name}/current-secret-id"
      echo ""
      echo "🔑  Downstream apps must re-login with the new SecretID."
    EOT

    environment = {
      VAULT_ADDR  = var.vault_addr
      VAULT_TOKEN = var.rotator_token
    }
  }
}

# ---------------------------------------------------------------------------
# Read back the newly stored SecretID metadata (accessor only — never the value)
# ---------------------------------------------------------------------------

data "vault_kv_secret_v2" "current_secret_id_meta" {
  mount = var.kv_mount
  name  = "${var.app_role_name}/current-secret-id"

  depends_on = [terraform_data.rotate_secret_id]
}
