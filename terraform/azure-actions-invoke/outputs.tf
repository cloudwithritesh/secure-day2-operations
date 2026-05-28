output "action_address" {
  description = "Action address used with terraform -invoke."
  value       = "action.azurerm_virtual_machine_power.day2_power"
}

output "apply_trigger_nonce" {
  description = "Current apply trigger nonce."
  value       = terraform_data.apply_trigger.input
}
