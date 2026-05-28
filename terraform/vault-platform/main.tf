# =============================================================================
# vault-platform / main.tf
# PURPOSE : Platform team workspace — owns all Vault policies and AppRoles.
#           App teams get a scoped token; they NEVER touch this workspace.
# =============================================================================

# ---------------------------------------------------------------------------
# KV v2 mount  (isolated from the existing "app" mount)
# ---------------------------------------------------------------------------
resource "vault_mount" "secrets" {
  path        = "secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "App secrets — managed exclusively by the platform team"
}

# ---------------------------------------------------------------------------
# Policies (least-privilege)
# ---------------------------------------------------------------------------

# Full control of everything under this mount — platform team only
resource "vault_policy" "platform_admin" {
  name = "platform-admin"

  policy = <<-EOT
    # Manage the secrets/ KV mount
    path "secrets/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage AppRoles
    path "auth/approle/role/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage policies
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}

# App service account — read its own secrets, nothing else
resource "vault_policy" "app_reader" {
  name = "${var.app_name}-app-reader"

  policy = <<-EOT
    # Read secrets for this specific application only
    path "secrets/data/${var.app_name}-api/*" {
      capabilities = ["read"]
    }

    # Allow listing to know what secrets exist (not the values)
    path "secrets/metadata/${var.app_name}-api/*" {
      capabilities = ["list"]
    }
  EOT
}

# Rotation service account — can ONLY generate new SecretIDs for its own AppRole
resource "vault_policy" "secret_rotator" {
  name = "${var.app_name}-rotator"

  policy = <<-EOT
    # Generate a new SecretID for the app's AppRole — nothing else
    path "auth/approle/role/${var.app_name}-app/secret-id" {
      capabilities = ["create", "update"]
    }

    # Write AND read the SecretID back (read needed for rotation workspace outputs)
    path "secrets/data/${var.app_name}-app/current-secret-id" {
      capabilities = ["create", "update", "read"]
    }
  EOT
}

# ---------------------------------------------------------------------------
# AppRoles
# ---------------------------------------------------------------------------

# Enable the AppRole auth method (idempotent — skipped if already enabled)
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# AppRole for the application — short-lived tokens, read-only policy
resource "vault_approle_auth_backend_role" "app" {
  backend              = vault_auth_backend.approle.path
  role_name            = "${var.app_name}-app"
  token_policies       = [vault_policy.app_reader.name]
  token_ttl            = 3600  # 1 hour
  token_max_ttl        = 7200  # 2 hours hard cap
  secret_id_ttl        = var.secret_rotation_hours * 3600
  bind_secret_id       = true
}

# AppRole for the rotation service — minimal policy, only rotates SecretIDs
resource "vault_approle_auth_backend_role" "rotator" {
  backend              = vault_auth_backend.approle.path
  role_name            = "${var.app_name}-rotator"
  token_policies       = [vault_policy.secret_rotator.name]
  token_ttl            = 600   # 10 minutes — rotation is a quick operation
  token_max_ttl        = 1200
  secret_id_num_uses   = 1     # Single-use SecretID for the rotator itself
  bind_secret_id       = true
}

# ---------------------------------------------------------------------------
# Initial secrets (simulated DB credentials)
# ---------------------------------------------------------------------------

resource "vault_kv_secret_v2" "db_credentials" {
  mount = vault_mount.secrets.path
  name  = "${var.app_name}-api/db-credentials"

  data_json = jsonencode({
    db_host     = "db.internal.example.com"
    db_port     = 5432
    db_name     = "${var.app_name}_prod"
    db_user     = "${var.app_name}_svc"
    db_password = "REPLACE_ME_WITH_REAL_SECRET"  # In practice, inject via pipeline
    managed_by  = "vault-platform-terraform"
    environment = var.environment
  })

  lifecycle {
    ignore_changes = [data_json]  # Allow app teams to update values without Terraform drift
  }
}

# ---------------------------------------------------------------------------
# RoleIDs — safe to export (they are not secrets)
# ---------------------------------------------------------------------------

data "vault_approle_auth_backend_role_id" "app" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.app.role_name
}

data "vault_approle_auth_backend_role_id" "rotator" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.rotator.role_name
}
