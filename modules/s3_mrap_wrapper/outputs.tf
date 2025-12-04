output "primary_bucket_name" {
description = "Name of the primary S3 bucket."
value = module.primary_bucket.bucket_name
}

output "primary_bucket_arn" {
description = "ARN of the primary S3 bucket."
value = module.primary_bucket.bucket_arn
}

output "dr_bucket_name" {
description = "Name of the DR S3 bucket."
value = module.dr_bucket.bucket_name
}

output "dr_bucket_arn" {
description = "ARN of the DR S3 bucket."
value = module.dr_bucket.bucket_arn
}

output "replication_iam_role_arn" {
description = "ARN of the IAM role for DR bucket replication."
value = module.dr_bucket.replication_iam_role_arn
}

output "mrap_alias" {
description = "MRAP alias/URL (hostname) if MRAP is enabled."
value = var.enable_mrap ? module.dr_bucket.mrap_alias : null
}

output "mrap_arn" {
  description = "ARN of the Multi-Region Access Point."
  value       = var.enable_mrap ? module.dr_bucket.mrap_arn : null
}

output "mrap_name" {
  description = "Name of the Multi-Region Access Point."
  value       = var.enable_mrap ? module.dr_bucket.mrap_name : null
}

