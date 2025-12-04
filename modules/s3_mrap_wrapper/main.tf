locals {
  primary_name = var.base_name
  dr_name      = "${var.base_name}-dr"
  mrap_name    = "${var.base_name}-mrap"
}

# Get current account ID for MRAP operations
data "aws_caller_identity" "current" {}

# Primary bucket module
module "primary_bucket" {
  source = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

  providers = {
    aws = aws.primary
  }

  context                    = var.context
  name                       = local.primary_name
  object_versioning_status   = "Enabled"
  acl                        = var.acl
  private                    = var.private
  policy                     = var.policy
  kms_master_key_id          = var.kms_master_key_id

  replication_configuration = var.enable_bi_directional_crr ? {
    iam_role_arn = module.dr_bucket.replication_iam_role_arn
    rules = [{
      id                            = "ReplicateToDRBucket"
      status                        = "Enabled"
      priority                      = 1
      delete_marker_replication_status = "Enabled"
      destinations = [{
        bucket_arn = module.dr_bucket.bucket_arn
        storage_class = "STANDARD"
      }]
      filter = {
        prefix = ""
      }
    }]
  } : null
}

# DR bucket module (with MRAP)
module "dr_bucket" {
  source = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

  providers = {
    aws = aws.dr
  }

  context                    = var.context
  name                       = local.dr_name
  object_versioning_status   = "Enabled"
  acl                        = var.acl
  private                    = var.private
  policy                     = var.policy
  kms_master_key_id          = var.kms_master_key_id

  replication_configuration = var.enable_bi_directional_crr ? {
    rules = [{
      id                            = "ReplicateToSourceBucket"
      status                        = "Enabled"
      priority                      = 1
      delete_marker_replication_status = "Enabled"
      destinations = [{
        bucket_arn = module.primary_bucket.bucket_arn
        storage_class = "STANDARD"
      }]
      filter = {
        prefix = ""
      }
    }]
    replication_iam = {
      role_name              = "${local.dr_name}-s3-replication-role"
      policy_name            = "${local.dr_name}-s3-replication-policy"
      destination_bucket_arns = [
        module.primary_bucket.bucket_arn
      ]
    }
  } : null

  mrap_name = var.enable_mrap ? local.mrap_name : null

  mrap_regions = var.enable_mrap ? [
    {
      region     = var.primary_region
      bucket_arn = module.primary_bucket.bucket_arn  # Fixed: Use ARN, not name
    },
    {
      region     = var.dr_region
      bucket_arn = module.dr_bucket.bucket_arn      # Fixed: Use ARN, not name
    }
  ] : []

  mrap_iam = var.enable_mrap ? {
    role_name         = "${local.mrap_name}-role"
    policy_name       = "${local.mrap_name}-policy"
    policy_path       = "/"
    policy_description = "IAM policy for Multi-Region Access Point to access ${local.primary_name} and ${local.dr_name}"
    bucket_arns = [
      module.primary_bucket.bucket_arn,
      module.dr_bucket.bucket_arn
    ]
  } : null
}

# MRAP Traffic Dial - Primary ACTIVE (100%), DR PASSIVE (0%)
resource "null_resource" "mrap_traffic_dial" {
  count = var.enable_mrap ? 1 : 0

  triggers = {
    mrap_arn        = module.dr_bucket.mrap_arn
    primary_bucket  = module.primary_bucket.bucket_name
    primary_dial    = 100  # Primary ACTIVE
    dr_bucket       = module.dr_bucket.bucket_name
    dr_dial         = 0    # DR PASSIVE
    account_id      = data.aws_caller_identity.current.account_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      ACCOUNT_ID="${self.triggers.account_id}"
      MRAP_ARN="${self.triggers.mrap_arn}"
      
      echo "Setting MRAP traffic dial: Primary=${self.triggers.primary_dial}%, DR=${self.triggers.dr_dial}%"
      
      aws s3control submit-multi-region-access-point-routes \
        --account-id "$ACCOUNT_ID" \
        --mrap "$MRAP_ARN" \
        --route-updates "Bucket=${self.triggers.primary_bucket},TrafficDialPercentage=${self.triggers.primary_dial}" \
                         "Bucket=${self.triggers.dr_bucket},TrafficDialPercentage=${self.triggers.dr_dial}" \
        --region us-east-1
      
      echo "Traffic dial update submitted successfully"
    EOT
    
    interpreter = ["bash", "-c"]
  }

  depends_on = [module.dr_bucket]
}

# MRAP Policy for access control
resource "aws_s3control_multi_region_access_point_policy" "this" {
  count  = var.enable_mrap ? 1 : 0
  provider = aws.primary  # MRAP policy must be in control plane region (primary)

  depends_on = [null_resource.mrap_traffic_dial]

  details {
    name = module.dr_bucket.mrap_name

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AllowObjectOperations"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:GetObjectVersion",
            "s3:AbortMultipartUpload",
            "s3:ListMultipartUploadParts"
          ]
          Resource = "${module.dr_bucket.mrap_arn}/object/*"
        },
        {
          Sid    = "AllowBucketOperations"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action = [
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads"
          ]
          Resource = module.dr_bucket.mrap_arn
        }
      ]
    })
  }
}
