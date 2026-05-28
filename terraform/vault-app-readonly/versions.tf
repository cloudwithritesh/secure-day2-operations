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
# skip_child_token = true avoids the provider trying to create a child token,
# which the scoped policy intentionally does not allow.
provider "vault" {
  address           = var.vault_addr
  token             = var.approle_token
  skip_child_token  = true
}
