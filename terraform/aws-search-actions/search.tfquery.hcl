# Terraform Search query config for HCP Terraform / Terraform 1.14+.
# This searches for S3 buckets tagged as unmanaged.
# Use: terraform query

list "aws_s3_bucket" "unmanaged" {
  provider = aws

  config {
    region = "us-east-1"

    filter {
      name   = "tag:ManagedBy"
      values = ["unmanaged"]
    }
  }
}
