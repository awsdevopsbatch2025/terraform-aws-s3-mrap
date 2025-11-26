# terraform-aws-s3-mrap

Variables you need to add for MRAP

variable "mrap_name" {
  type        = string
  description = "Name of the S3 Multi-Region Access Point"
  default     = null
}

variable "mrap_regions" {
  type = list(object({
    region     = string
    bucket_arn = string
  }))
  description = "List of regions and bucket ARNs to include as endpoints for MRAP"
  default     = []
}



Example External Module Call
Call this module for bucket creation, CRR, and MRAP creation in one go:

module "s3_with_mrap" {
  source = "path_to_your_module"

  name                     = "my-bucket"
  name_prefix              = "env-"
  lifecycle_rules          = var.lifecycle_rules
  replication_configuration = var.replication_config
  kms_master_key_id        = var.kms_key_id
  object_versioning_status = "Enabled"
  private                  = true
  tags                     = var.global_tags

  # MRAP inputs: pass bucket ARNs for all regions participating in MRAP
  mrap_name = "my-mrap"
  mrap_regions = [
    { region = "us-east-1", bucket_arn = "arn:aws:s3:::env-my-bucket-us-east-1" },
    { region = "us-east-2", bucket_arn = "arn:aws:s3:::env-my-bucket-us-east-2" }
  ]
}

