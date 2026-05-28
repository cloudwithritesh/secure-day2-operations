terraform {
  required_version = ">= 1.6"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.5"
    }
  }
}

# Provider is scoped to the AppRole token — least-privilege by design.
# It cannot create policies, AppRoles, or access other KV paths.
provider "vault" {
  address = var.vault_addr
  token   = var.approle_token
}
