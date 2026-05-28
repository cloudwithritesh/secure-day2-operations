action "aws_ec2_stop_instance" "day2_stop" {
  config {
    instance_id = var.instance_id
    force       = var.force_stop
    timeout     = var.stop_timeout_seconds
    region      = var.aws_region
  }
}

resource "terraform_data" "apply_trigger" {
  input = var.invoke_nonce

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_ec2_stop_instance.day2_stop]
    }
  }
}
