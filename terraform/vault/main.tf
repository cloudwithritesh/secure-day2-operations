locals {
  app_name = "payments-api"
}

resource "vault_mount" "app_kv" {
  path        = "app"
  type        = "kv-v2"
  description = "Application secrets for Day 2 demo."
}

resource "vault_policy" "ops_admin" {
  name = "ops-admin"

  policy = <<EOT
path "app/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}

resource "vault_policy" "app_reader" {
  name = "app-reader"

  policy = <<EOT
path "app/data/${local.app_name}/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_approle_auth_backend_role" "demo_app" {
  backend        = vault_auth_backend.approle.path
  role_name      = "demo-app"
  token_policies = [vault_policy.app_reader.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

resource "time_rotating" "runtime_secret" {
  rotation_days = var.rotation_days
}

resource "random_password" "runtime_secret" {
  length           = 24
  special          = true
  override_special = "!@#%^*-_=+"
  keepers = {
    rotation = time_rotating.runtime_secret.id
  }
}

resource "vault_kv_secret_v2" "runtime_secret" {
  mount = vault_mount.app_kv.path
  name  = "${local.app_name}/runtime"

  data_json = jsonencode({
    username   = "app-user"
    password   = random_password.runtime_secret.result
    rotated_at = time_rotating.runtime_secret.rotation_rfc3339
    managed_by = "terraform"
    env        = var.environment
  })
}

resource "time_rotating" "approle_secret_id" {
  rotation_hours = var.approle_secret_rotation_hours
}

resource "vault_approle_auth_backend_role_secret_id" "demo_app" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.demo_app.role_name
  metadata = jsonencode({
    rotation_trigger = time_rotating.approle_secret_id.id
    environment      = var.environment
  })
}

