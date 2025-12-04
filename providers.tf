provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}



module "v3_bucket_pair" {
  source = "./modules/s3_mrap_wrapper"

  providers = {
    aws.primary = aws           # us-east-1
    aws.dr      = aws.us-east-2 # us-east-2
  }


  base_name      = "v3-bucket"   # primary = v3-bucket, DR = v3-bucket-dr, MRAP = v3-bucket-mrap
  primary_region = "us-east-1"
  dr_region      = "us-east-2"

  enable_mrap               = true
  enable_bi_directional_crr = true

  # NEW: permissions, applied to BOTH primary and DR
  # Adjust these to match how your existing primary is supposed to be configured.

  # Example 1: both buckets fully private, block public access:
  acl     = "private"
  private = true
  policy  = ""          # or file("bucket-policy.json") if you want a policy

  # Example 2 (if you ever want public buckets):
  # acl     = "public-read"
  # private = false
  # policy  = file("bucket-policy.json")
}
