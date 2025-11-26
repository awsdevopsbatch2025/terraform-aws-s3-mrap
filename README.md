Module call :

module "s3_mrap" {
  source = "../terraform-aws-s3-mrap"  # path to your module's folder -- adjust as needed

  name                     = "my-bucket"
  name_prefix              = "env-"
  lifecycle_rules          = var.lifecycle_rules   # define in root or use default
  kms_master_key_id        = var.kms_key_id        # define in root or use default
  object_versioning_status = "Enabled"
  private                  = true
  tags                     = var.global_tags

  # Replication configuration input example
  replication_configuration = {
    rules = [
      {
        id       = "dr-replication"
        status   = "Enabled"
        priority = 1
        destinations = [
          {
            bucket_arn    = "arn:aws:s3:::env-my-bucket-us-east-2"  # This must exist!
            storage_class = "STANDARD"
            account_id    = "YOUR_TARGET_AWS_ACCOUNT_ID"
          }
        ]
      }
    ]
  }

  # MRAP inputs (use existing bucket ARNs created separately)
  mrap_name = "my-mrap"
  mrap_regions = [
    {
      region     = "us-east-1"
      bucket_arn = "arn:aws:s3:::env-my-bucket-us-east-1"
    },
    {
      region     = "us-east-2"
      bucket_arn = "arn:aws:s3:::env-my-bucket-us-east-2"
    }
  ]
}
