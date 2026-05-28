variable "subscription_id" {
  description = "Azure subscription ID. Leave empty to use Azure CLI default subscription."
  type        = string
  default     = ""
}

variable "virtual_machine_id" {
  description = "Existing Azure VM resource ID for day-2 power action demo."
  type        = string
}

variable "power_action" {
  description = "Power action to perform. Valid values: restart, power_on, power_off."
  type        = string
  default     = "restart"
}

variable "action_timeout" {
  description = "Timeout duration for action completion, e.g. 30m."
  type        = string
  default     = "30m"
}

variable "invoke_nonce" {
  description = "Change this value to trigger lifecycle-bound action on apply."
  type        = string
  default     = "run-1"
}
