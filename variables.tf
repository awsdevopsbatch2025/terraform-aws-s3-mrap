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
