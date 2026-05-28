data "aws_caller_identity" "current" {}

data "aws_resourcegroupstaggingapi_resources" "unmanaged_buckets" {
  resource_type_filters = ["s3:bucket"]

  tag_filter {
    key    = var.search_tag_key
    values = [var.search_tag_value]
  }
}

locals {
  discovered_bucket_names = [
    for r in data.aws_resourcegroupstaggingapi_resources.unmanaged_buckets.resource_tag_mapping_list :
    replace(r.resource_arn, "arn:aws:s3:::", "")
  ]
  selected_bucket_name = var.bucket_name != "" ? var.bucket_name : one(local.discovered_bucket_names)
  profile_arg          = var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""
}

data "aws_s3_bucket" "target" {
  bucket = local.selected_bucket_name
}

# Adoption mode: imported existing S3 bucket (no destructive mutations).
resource "aws_s3_bucket" "existing" {
  bucket = data.aws_s3_bucket.target.bucket

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

import {
  to = aws_s3_bucket.existing
  id = local.selected_bucket_name
}

resource "terraform_data" "invoke_nonce" {
  input = var.invoke_action_nonce
}

# Day-2 operation sample: invoke an action on existing infrastructure.
resource "null_resource" "enable_bucket_versioning" {
  triggers = {
    bucket_name = aws_s3_bucket.existing.id
    nonce       = terraform_data.invoke_nonce.output
  }

  provisioner "local-exec" {
    command = "aws s3api put-bucket-versioning --bucket ${aws_s3_bucket.existing.id} --versioning-configuration Status=Enabled --region ${var.aws_region} ${local.profile_arg}"
  }
}

resource "vault_kv_secret_v2" "s3_action_record" {
  count = var.enable_vault_sync ? 1 : 0

  mount = var.vault_kv_mount
  name  = var.vault_secret_name

  data_json = jsonencode({
    cloud_provider   = "aws"
    account_id       = data.aws_caller_identity.current.account_id
    region           = var.aws_region
    bucket_name      = aws_s3_bucket.existing.id
    bucket_arn       = data.aws_s3_bucket.target.arn
    action           = "s3:PutBucketVersioning"
    versioning_state = "Enabled"
    action_nonce     = var.invoke_action_nonce
    search_tag_key   = var.search_tag_key
    search_tag_value = var.search_tag_value
    managed_by       = "terraform-aws-search-actions"
  })

  depends_on = [null_resource.enable_bucket_versioning]
}
