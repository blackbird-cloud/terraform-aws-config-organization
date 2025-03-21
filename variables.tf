variable "name" {
  type        = string
  default     = "config"
  description = "(Optional) Name used for all created resources. Defaults to `config`."
}

variable "conformance_packs" {
  type        = map(any)
  default     = {}
  description = "(Optional) Map of AWS Config Organization Conformance Packs. More information can be found in the Managing Conformance Packs Across all Accounts in Your Organization and AWS Config Managed Rules documentation."
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Map of tags to assign to the trail. If configured with a provider `default_tags` configuration block present, tags with matching keys will overwrite those defined at the provider-level."
  default     = {}
}

variable "s3_bucket_name" {
  type        = string
  description = "The name of the S3 bucket to store Config history."
}

variable "role_arn" {
  type        = string
  description = "The ARN of the IAM role to use for this configuration recorder."
}

variable "recording_frequency" {
  type        = string
  description = "The recording frequency for the resources in the override block. CONTINUOUS or DAILY."
  default     = "DAILY"
}