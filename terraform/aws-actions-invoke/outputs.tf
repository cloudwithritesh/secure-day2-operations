output "action_address" {
  description = "Action address used with terraform -invoke."
  value       = "action.aws_ec2_stop_instance.day2_stop"
}

output "apply_trigger_nonce" {
  description = "Current apply trigger nonce."
  value       = terraform_data.apply_trigger.input
}
