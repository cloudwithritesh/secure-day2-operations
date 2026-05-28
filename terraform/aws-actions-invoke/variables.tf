variable "aws_region" {
  description = "AWS region for the target EC2 instance."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "Optional AWS profile name. Leave empty to use default credential chain."
  type        = string
  default     = ""
}

variable "instance_id" {
  description = "Existing EC2 instance ID for day-2 stop action demo."
  type        = string
}

variable "force_stop" {
  description = "Whether to force stop the instance."
  type        = bool
  default     = false
}

variable "stop_timeout_seconds" {
  description = "Timeout in seconds for stop action completion (30-3600)."
  type        = number
  default     = 600
}

variable "invoke_nonce" {
  description = "Change this value to trigger lifecycle-bound action on apply."
  type        = string
  default     = "run-1"
}
