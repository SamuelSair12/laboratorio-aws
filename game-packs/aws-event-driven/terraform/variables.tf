variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "aws_access_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "aws_secret_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "use_floci" {
  type    = bool
  default = true
}
variable "endpoint_url" {
  type    = string
  default = "http://localhost:4566"
}
variable "name_prefix" {
  type    = string
  default = "arena-team-01"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.name_prefix))
    error_message = "name_prefix must contain 3-32 lowercase letters, digits, or hyphens."
  }
}
variable "fail_payments" {
  type    = bool
  default = false
}

variable "lambda_endpoint_url" {
  type        = string
  default     = "http://floci:4566"
  description = "Endpoint reachable from Floci-managed Lambda containers. Ignored for real AWS."
}
