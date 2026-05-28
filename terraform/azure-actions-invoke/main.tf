action "azurerm_virtual_machine_power" "day2_power" {
  config {
    virtual_machine_id = var.virtual_machine_id
    power_action       = var.power_action
    timeout            = var.action_timeout
  }
}

resource "terraform_data" "apply_trigger" {
  input = var.invoke_nonce

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.azurerm_virtual_machine_power.day2_power]
    }
  }
}
