resource "random_integer" "suffix" {
  min = 1000
  max = 9999
}

locals {
  unique_name = "${var.name_prefix}${random_integer.suffix.result}"
  dns_label   = "${var.name_prefix}-${random_integer.suffix.result}"
}

resource "azurerm_resource_group" "demo" {
  name     = "rg-${local.unique_name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "demo" {
  name                     = substr(replace(local.unique_name, "-", ""), 0, 24)
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_container_group" "vault" {
  name                = "cg-${local.unique_name}-vault"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  ip_address_type     = "Public"
  dns_name_label      = local.dns_label
  os_type             = "Linux"
  restart_policy      = "Always"
  tags                = var.tags

  container {
    name   = "vault"
    image  = "hashicorp/vault:${var.vault_version}"
    cpu    = 1
    memory = 1.5

    ports {
      port     = 8200
      protocol = "TCP"
    }

    environment_variables = {
      VAULT_ADDR = "http://127.0.0.1:8200"
    }

    commands = [
      "/bin/sh",
      "-c",
      "vault server -dev -dev-root-token-id=${var.vault_root_token} -dev-listen-address=0.0.0.0:8200"
    ]
  }
}
