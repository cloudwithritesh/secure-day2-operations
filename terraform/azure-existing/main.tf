data "azurerm_client_config" "current" {}

locals {
  effective_subscription_id = var.subscription_id != "" ? var.subscription_id : data.azurerm_client_config.current.subscription_id
  kv_mount_path             = var.create_kv_mount ? vault_mount.app_kv[0].path : var.vault_kv_mount
}

# Import target: existing resource group (adoption mode: no mutations).
resource "azurerm_resource_group" "existing" {
  name     = var.resource_group_name
  location = var.resource_group_location
  tags     = var.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Import target: existing storage account (adoption mode: no mutations).
resource "azurerm_storage_account" "existing" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.existing.name
  location                 = var.resource_group_location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind             = var.storage_account_kind
  access_tier              = var.storage_account_access_tier
  tags                     = var.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "vault_mount" "app_kv" {
  count       = var.create_kv_mount ? 1 : 0
  path        = var.vault_kv_mount
  type        = "kv-v2"
  description = "KV mount for storing imported Azure resource secrets."
}

resource "vault_kv_secret_v2" "imported_storage_account" {
  mount = local.kv_mount_path
  name  = var.vault_secret_name

  data_json = jsonencode({
    subscription_id           = local.effective_subscription_id
    resource_group_name       = azurerm_resource_group.existing.name
    storage_account_name      = azurerm_storage_account.existing.name
    primary_access_key        = azurerm_storage_account.existing.primary_access_key
    primary_connection_string = azurerm_storage_account.existing.primary_connection_string
    primary_blob_endpoint     = azurerm_storage_account.existing.primary_blob_endpoint
    managed_by                = "terraform"
    source                    = "imported-existing-resource"
  })
}

import {
  to = azurerm_resource_group.existing
  id = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}"
}

import {
  to = azurerm_storage_account.existing
  id = "/subscriptions/${local.effective_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
}

