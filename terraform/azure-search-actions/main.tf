data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "target" {
  name = var.resource_group_name
}

data "azurerm_resources" "storage_accounts" {
  resource_group_name = var.resource_group_name
  type                = "Microsoft.Storage/storageAccounts"
  required_tags       = var.search_required_tags
}

locals {
  effective_subscription_id = var.subscription_id != "" ? var.subscription_id : data.azurerm_client_config.current.subscription_id
  filtered_storage_accounts = var.storage_account_name != "" ? [
    for r in data.azurerm_resources.storage_accounts.resources : r if lower(r.name) == lower(var.storage_account_name)
  ] : data.azurerm_resources.storage_accounts.resources
  selected_storage_account = one(local.filtered_storage_accounts)
}

data "azurerm_storage_account" "target" {
  name                = local.selected_storage_account.name
  resource_group_name = var.resource_group_name
}

# Adoption mode: imported existing resource group.
resource "azurerm_resource_group" "existing" {
  name     = data.azurerm_resource_group.target.name
  location = data.azurerm_resource_group.target.location
  tags     = data.azurerm_resource_group.target.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Adoption mode: imported existing storage account.
resource "azurerm_storage_account" "existing" {
  name                     = data.azurerm_storage_account.target.name
  resource_group_name      = data.azurerm_storage_account.target.resource_group_name
  location                 = data.azurerm_storage_account.target.location
  account_tier             = data.azurerm_storage_account.target.account_tier
  account_replication_type = data.azurerm_storage_account.target.account_replication_type
  account_kind             = data.azurerm_storage_account.target.account_kind
  tags                     = data.azurerm_storage_account.target.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

import {
  to = azurerm_resource_group.existing
  id = data.azurerm_resource_group.target.id
}

import {
  to = azurerm_storage_account.existing
  id = data.azurerm_storage_account.target.id
}

resource "terraform_data" "invoke_nonce" {
  input = var.invoke_action_nonce
}

resource "azapi_resource_action" "regenerate_storage_key" {
  type        = "Microsoft.Storage/storageAccounts@2023-01-01"
  resource_id = azurerm_storage_account.existing.id
  action      = "regenerateKey"
  method      = "POST"

  body = {
    keyName = var.storage_key_to_regenerate
  }

  response_export_values = ["keys"]

  lifecycle {
    replace_triggered_by = [terraform_data.invoke_nonce]
  }
}

locals {
  action_output     = try(jsondecode(azapi_resource_action.regenerate_storage_key.output), {})
  action_keys       = try(local.action_output.keys, [])
  regenerated_keys  = [for k in local.action_keys : k if lower(try(k.keyName, "")) == lower(var.storage_key_to_regenerate)]
  regenerated_key   = try(one(local.regenerated_keys), null)
  regenerated_value = try(local.regenerated_key.value, azurerm_storage_account.existing.primary_access_key)
}

resource "vault_kv_secret_v2" "storage_account_access" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_name

  data_json = jsonencode({
    subscription_id           = local.effective_subscription_id
    resource_group_name       = azurerm_resource_group.existing.name
    storage_account_name      = azurerm_storage_account.existing.name
    storage_key_name          = var.storage_key_to_regenerate
    primary_access_key        = local.regenerated_value
    primary_connection_string = azurerm_storage_account.existing.primary_connection_string
    primary_blob_endpoint     = azurerm_storage_account.existing.primary_blob_endpoint
    action_nonce              = var.invoke_action_nonce
    managed_by                = "terraform-search-actions-demo"
  })
}
