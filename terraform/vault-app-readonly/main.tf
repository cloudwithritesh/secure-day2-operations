# =============================================================================
# vault-app-readonly / main.tf
# PURPOSE : App team workspace — demonstrates least-privilege Vault access.
#           The provider token is scoped to payments-app-reader only.
#           This workspace CANNOT: create policies, manage AppRoles, or
#           read any path outside secrets/data/payments-api/*.
# =============================================================================

# Read the application's DB credentials — this is the ONLY thing allowed
data "vault_kv_secret_v2" "db_credentials" {
  mount = var.kv_mount
  name  = var.secret_path
}

# ---------------------------------------------------------------------------
# Demonstrate policy enforcement — what the app CAN see
# ---------------------------------------------------------------------------

locals {
  # Safe fields to log/expose in app config
  db_config = {
    host = data.vault_kv_secret_v2.db_credentials.data["db_host"]
    port = data.vault_kv_secret_v2.db_credentials.data["db_port"]
    name = data.vault_kv_secret_v2.db_credentials.data["db_name"]
    user = data.vault_kv_secret_v2.db_credentials.data["db_user"]
  }
}
