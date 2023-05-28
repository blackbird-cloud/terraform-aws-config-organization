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

variable "administrator_arns" {
  type        = list(string)
  description = "List of AWS principals that will receive Administrative permissions on the resources created."
  default     = []
}

variable "viewers_arns" {
  type        = list(string)
  description = "(Optional) List of AWS principals that will receive viewing permissions on the Config bucket."
  default     = []
}

variable "writers_arns" {
  type        = list(string)
  description = "(Optional) List of AWS principals that will receive writing permissions on the Config bucket."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Map of tags to assign to the trail. If configured with a provider `default_tags` configuration block present, tags with matching keys will overwrite those defined at the provider-level."
  default     = {}
}
