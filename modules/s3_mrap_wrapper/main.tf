locals {
primary_name = var.base_name
dr_name = "${var.base_name}-dr"
mrap_name = "${var.base_name}-mrap"
}

# Expect providers to be passed from root:
# aws.primary = primary region provider
# aws.dr = DR region provider

module "primary_bucket" {
source = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

providers = {
aws = aws.primary
}

context = var.context
name = local.primary_name
object_versioning_status = "Enabled"

replication_configuration = var.enable_bi_directional_crr ? {
iam_role_arn = module.dr_bucket.replication_iam_role_arn
rules = [
{
id = "ReplicateToDRBucket"
status = "Enabled"
priority = 1
delete_marker_replication_status = "Enabled"
destinations = [
{
bucket_arn = module.dr_bucket.bucket_arn
storage_class = "STANDARD"
}
]
filter = {
prefix = ""
}
}
]
} : null
}

module "dr_bucket" {
source = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

providers = {
aws = aws.dr
}

context = var.context
name = local.dr_name
object_versioning_status = "Enabled"

replication_configuration = var.enable_bi_directional_crr ? {
rules = [
{
id = "ReplicateToSourceBucket"
status = "Enabled"
priority = 1
delete_marker_replication_status = "Enabled"
destinations = [
{
bucket_arn = module.primary_bucket.bucket_arn
storage_class = "STANDARD"
}
]
filter = {
prefix = ""
}
}
]
} : null

replication_iam = {
role_name = "${local.dr_name}-s3-replication-role"
policy_name = "${local.dr_name}-s3-replication-policy"
destination_bucket_arns = [
module.primary_bucket.bucket_arn,
module.dr_bucket.bucket_arn
]
}

mrap_name = var.enable_mrap ? local.mrap_name : null

mrap_regions = var.enable_mrap ? [
{
region = var.primary_region
bucket_arn = module.primary_bucket.bucket_name # using bucket NAME
},
{
region = var.dr_region
bucket_arn = module.dr_bucket.bucket_name # using bucket NAME
}
] : []

mrap_iam = var.enable_mrap ? {
role_name = "${local.mrap_name}-role"
policy_name = "${local.mrap_name}-policy"
bucket_arns = [
module.primary_bucket.bucket_arn,
"arn:aws:s3:::${module.dr_bucket.bucket_name}"
]
policy_path = "/"
policy_description = "IAM policy for Multi-Region Access Point to access ${local.primary_name} and ${local.dr_name}"
} : null
}
