variable "base_name" {
description = "Logical base name of the bucket (primary will use this, DR will add -dr)."
type = string
}

variable "context" {
description = "Label/context object passed to underlying modules."
type = any
}

variable "primary_region" {
description = "AWS region of the primary bucket."
type = string
}

variable "dr_region" {
description = "AWS region of the DR bucket."
type = string
}

variable "enable_mrap" {
description = "Whether to create an MRAP over the primary and DR buckets."
type = bool
default = true
}

variable "enable_bi_directional_crr" {
description = "Whether to enable CRR in both directions (primary->DR and DR->primary)."
type = bool
default = true
}
