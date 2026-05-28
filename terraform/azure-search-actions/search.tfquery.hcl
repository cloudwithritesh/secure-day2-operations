# Terraform Search query config for Azure.
# Requires Terraform 1.14+ and provider/resource support in your runtime.
# Use from this folder: terraform query

list "azurerm_storage_account" "unmanaged" {
  provider = azurerm

  config {
    # Set this to the target subscription where resources exist.
    subscription_id = "00000000-0000-0000-0000-000000000000"

    # Narrow the result set for demo safety.
    resource_group_name = "rg-tfsearch-demo"

    tag {
      name   = "scenario"
      values = ["tf-search-actions-demo"]
    }
  }
}
