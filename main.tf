locals {
  # existing lifecycle rules concatenation as before ...
  effective_lifecycle_rules = concat(
    var.lifecycle_rules,
    # ... same as your existing local block for lifecycle_rules ...
  )

  name_suffix  = var.name_uniqueness == true ? "-${random_id.name_suffix[0].hex}" : ""
  applied_name = "${var.name_prefix}${var.name}${local.name_suffix}"
  backup_status = var.object_versioning_status == "Suspended" ? { "hh:backup" = "exclude" } : null
  phi_status = module.label.phi == "false" ? { "hh:phi" = "false" } : { "hh:phi" = "true" }
  applied_tags = merge(module.label.tags, local.backup_status, local.phi_status, var.tags)

  replication_configuration_rules = var.replication_configuration != null ? [for rule in var.replication_configuration.rules : {
    id                             = rule.id
    status                         = rule.status
    priority                       = rule.priority
    delete_marker_replication_status = rule.delete_marker_replication_status
    destinations = [for dest in rule.destinations : {
      bucket        = dest.bucket_arn
      storage_class = dest.storage_class
      account       = dest.account_id
      access_control_translation = dest.access_control_translation != null ? {
        owner = dest.access_control_translation.owner
      } : null
      encryption_configuration = dest.encryption_configuration != null ? {
        replica_kms_key_id = dest.encryption_configuration.replica_kms_key_id
      } : null
      metrics = dest.metrics != null ? {
        status = dest.metrics.status
        event_threshold = {
          minutes = dest.metrics.event_threshold_minutes
        }
      } : null
      replication_time = dest.replication_time != null ? {
        status = dest.replication_time.status
        time = {
          minutes = dest.replication_time.time_minutes
        }
      } : null
    }]
    filter = rule.filter != null ? {
      prefix = rule.filter.prefix
      tag = rule.filter.tag != null ? {
        key   = rule.filter.tag.key
        value = rule.filter.tag.value
      } : null
      and = rule.filter.and != null ? {
        prefix = rule.filter.and.prefix
        tags   = rule.filter.and.tags
      } : null
    } : null
    source_selection_criteria = rule.source_selection_criteria != null ? {
      sse_kms_encrypted_objects = rule.source_selection_criteria.sse_kms_encrypted_objects != null ? {
        status = rule.source_selection_criteria.sse_kms_encrypted_objects.status
      } : null
      replica_modifications = rule.source_selection_criteria.replica_modifications != null ? {
        status = rule.source_selection_criteria.replica_modifications.status
      } : null
    } : null
    existing_object_replication = rule.existing_object_replication != null ? {
      status = rule.existing_object_replication.status
    } : null
  }] : []
}

resource "random_id" "name_suffix" {
  count       = var.name_uniqueness == true ? 1 : 0
  byte_length = 4
}

module "label" {
  source = "github.com/hinge-health-terraform/hh_label?ref=v1"

  namespace = "hh"
  component = "s3_bucket"

  context = var.context
}

module "this" {
  source = "github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=v3.15.0"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = var.kms_master_key_id
        sse_algorithm     = var.kms_master_key_id == null ? "AES256" : "aws:kms"
      }
      bucket_key_enabled = var.kms_master_key_id == null ? false : true
    }
  }
  object_lock_enabled = var.object_lock_enabled
  object_lock_configuration = var.object_lock_enabled == true ? {
    default_retention_period = var.object_lock_default_retention_period
    default_retention_units  = var.object_lock_default_retention_units
  } : null
  versioning = {
    enabled = var.object_versioning_status == "Enabled"
  }
  logging = var.access_log_bucket != null ? {
    target_bucket = var.access_log_bucket
    target_prefix = "${var.name}/"
  } : {}
  control_object_ownership = true
  object_ownership         = var.object_ownership
  block_public_acls        = var.private
  block_public_policy      = var.private
  ignore_public_acls       = var.private
  restrict_public_buckets  = var.private
  bucket                   = local.applied_name
  tags                     = local.applied_tags
  force_destroy            = var.force_destroy
  attach_policy            = length(var.policy) > 0 ? true : false
  policy                   = length(var.policy) > 0 ? var.policy : null
  acl                      = var.object_ownership == "BucketOwnerEnforced" ? null : (var.acl == "null" ? null : var.acl)
  lifecycle_rule           = local.effective_lifecycle_rules
  metric_configuration     = length(var.bucket_metrics_filters) > 0 ? [for k, v in var.bucket_metrics_filters : { name = k, prefix = v.prefix }] : []
}

resource "aws_s3_bucket_replication_configuration" "this" {
  count = var.replication_configuration != null ? 1 : 0

  role   = var.replication_configuration.iam_role_arn != null ? var.replication_configuration.iam_role_arn : (var.replication_iam != null ? aws_iam_role.replication[0].arn : null)
  bucket = module.this.s3_bucket_id

  dynamic "rule" {
    for_each = var.replication_configuration.rules
    content {
      id       = rule.value.id
      status   = rule.value.status
      priority = rule.value.priority

      delete_marker_replication {
        status = rule.value.delete_marker_replication_status
      }

      dynamic "destination" {
        for_each = rule.value.destinations
        content {
          bucket        = destination.value.bucket_arn
          storage_class = destination.value.storage_class
          account       = destination.value.account_id

          dynamic "access_control_translation" {
            for_each = destination.value.access_control_translation != null ? [destination.value.access_control_translation] : []
            content {
              owner = access_control_translation.value.owner
            }
          }

          dynamic "encryption_configuration" {
            for_each = destination.value.encryption_configuration != null ? [destination.value.encryption_configuration] : []
            content {
              replica_kms_key_id = encryption_configuration.value.replica_kms_key_id
            }
          }

          dynamic "metrics" {
            for_each = destination.value.metrics != null ? [destination.value.metrics] : []
            content {
              status = metrics.value.status
              event_threshold {
                minutes = metrics.value.event_threshold_minutes
              }
            }
          }

          dynamic "replication_time" {
            for_each = destination.value.replication_time != null ? [destination.value.replication_time] : []
            content {
              status = replication_time.value.status
              time {
                minutes = replication_time.value.time_minutes
              }
            }
          }
        }
      }

      dynamic "filter" {
        for_each = rule.value.filter != null ? [rule.value.filter] : []
        content {
          prefix = filter.value.prefix

          dynamic "tag" {
            for_each = filter.value.tag != null ? [filter.value.tag] : []
            content {
              key   = tag.value.key
              value = tag.value.value
            }
          }

          dynamic "and" {
            for_each = filter.value.and != null ? [filter.value.and] : []
            content {
              prefix = and.value.prefix
              tags   = and.value.tags
            }
          }
        }
      }

      dynamic "source_selection_criteria" {
        for_each = rule.value.source_selection_criteria != null ? [rule.value.source_selection_criteria] : []
        content {
          dynamic "sse_kms_encrypted_objects" {
            for_each = source_selection_criteria.value.sse_kms_encrypted_objects != null ? [source_selection_criteria.value.sse_kms_encrypted_objects] : []
            content {
              status = sse_kms_encrypted_objects.value.status
            }
          }

          dynamic "replica_modifications" {
            for_each = source_selection_criteria.value.replica_modifications != null ? [source_selection_criteria.value.replica_modifications] : []
            content {
              status = replica_modifications.value.status
            }
          }
        }
      }

      dynamic "existing_object_replication" {
        for_each = rule.value.existing_object_replication != null ? [rule.value.existing_object_replication] : []
        content {
          status = existing_object_replication.value.status
        }
      }
    }
  }
}

resource "aws_iam_role" "replication" {
  count = var.replication_iam != null ? 1 : 0

  name = var.replication_iam.role_name

  assume_role_policy = var.replication_iam.custom_role_trust_policy != null ? var.replication_iam.custom_role_trust_policy : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "s3.amazonaws.com",
            "batchoperations.s3.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.applied_tags
}

resource "aws_iam_policy" "replication" {
  count = var.replication_iam != null ? 1 : 0

  name        = var.replication_iam.policy_name
  path        = var.replication_iam.policy_path
  description = var.replication_iam.policy_description

  policy = var.replication_iam.custom_policy != null ? var.replication_iam.custom_policy : jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "SourceBucketPermissions"
          Effect = "Allow"
          Action = [
            "s3:GetBucketLocation",
            "s3:GetBucketVersioning",
            "s3:GetInventoryConfiguration",
            "s3:GetObjectLegalHold",
            "s3:GetObjectRetention",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl",
            "s3:GetObjectVersionForReplication",
            "s3:GetObjectVersionTagging",
            "s3:GetReplicationConfiguration",
            "s3:InitiateReplication",
            "s3:ListBucket",
            "s3:ListBucketVersions",
            "s3:PutBucketVersioning",
            "s3:PutInventoryConfiguration"
          ]
          Resource = concat(
            [module.this.s3_bucket_arn, "${module.this.s3_bucket_arn}/*"],
            length(var.replication_iam.destination_bucket_arns) > 0 ? flatten([
              for dest_arn in var.replication_iam.destination_bucket_arns : [
                dest_arn,
                "${dest_arn}/*"
              ]
              ]) : var.replication_configuration != null ? flatten([
              for rule in var.replication_configuration.rules : [
                for dest in rule.destinations : [
                  dest.bucket_arn,
                  "${dest.bucket_arn}/*"
                ]
              ]
            ]) : []
          )
        },
        {
          Sid    = "ReplicationPermissions"
          Effect = "Allow"
          Action = [
            "s3:ObjectOwnerOverrideToBucketOwner",
            "s3:PutObject",
            "s3:ReplicateDelete",
            "s3:ReplicateObject",
            "s3:ReplicateTags"
          ]
          Resource = concat(
            ["${module.this.s3_bucket_arn}/*"],
            length(var.replication_iam.destination_bucket_arns) > 0 ? [
              for dest_arn in var.replication_iam.destination_bucket_arns : "${dest_arn}/*"
              ] : var.replication_configuration != null ? flatten([
                for rule in var.replication_configuration.rules : [
                  for dest in rule.destinations : "${dest.bucket_arn}/*"
                ]
            ]) : []
          )
        },
        # MRAP permissions added here
        {
          Sid    = "MRAPPermissions"
          Effect = "Allow"
          Action = [
            "s3:PutMultiRegionAccessPointPolicy",
            "s3:GetMultiRegionAccessPoint",
            "s3:DeleteMultiRegionAccessPoint",
            "s3:UpdateMultiRegionAccessPointPolicy",
            "s3:ControlMultiRegionAccessPoint"
          ]
          Resource = "*"
        }
      ],
      var.replication_iam.additional_policy_statements
    )
  })

  tags = local.applied_tags
}

resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.replication_iam != null ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

# MRAP resource
resource "aws_s3_multi_region_access_point" "this" {
  count = var.mrap_name != null && length(var.mrap_regions) > 0 ? 1 : 0

  name = var.mrap_name

  endpoints = [
    for r in var.mrap_regions : {
      region = r.region
      bucket = r.bucket_arn
    }
  ]
}

output "mrap_arn" {
  description = "ARN of the Multi-Region Access Point"
  value       = length(aws_s3_multi_region_access_point.this) > 0 ? aws_s3_multi_region_access_point.this[0].arn : null
}

output "mrap_alias" {
  description = "Alias URL of the Multi-Region Access Point"
  value       = length(aws_s3_multi_region_access_point.this) > 0 ? aws_s3_multi_region_access_point.this[0].alias : null
}
