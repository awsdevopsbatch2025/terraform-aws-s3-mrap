**root main.tf**

module "v3_bucket_pair" {
  source = "./modules/s3_mrap_wrapper"

  providers = {
    aws.primary = aws
    aws.dr      = aws.us-east-2
  }

  # Minimal context; adjust fields to what your aws_s3_bucket var.context expects
  context = {
    environment = "dev"
    service     = "example-service"
  }

  base_name      = "v3-bucket"
  primary_region = "us-east-1"
  dr_region      = "us-east-2"

  enable_mrap               = true
  enable_bi_directional_crr = true
}
