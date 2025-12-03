provider "aws" {
region = "us-east-1"
}

provider "aws" {
alias = "us-east-2"
region = "us-east-2"
}

module "bucket_label" {
source = "github.com/hinge-health-terraform/hh_label?ref=v1"

namespace = "hh"
component = "s3_bucket_pair"

context = {
environment = "dev"
service = "example-service"
}
}

module "v3_bucket_pair" {
source = "./modules/s3_mrap_wrapper"

providers = {
aws.primary = aws
aws.dr = aws.us-east-2
}

context = module.bucket_label.context
base_name = "v3-bucket"
primary_region = "us-east-1"
dr_region = "us-east-2"

enable_mrap = true
enable_bi_directional_crr = true
}
