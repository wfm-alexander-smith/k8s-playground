variable "aws_profile" {}

variable "cluster" {
  description = "Cluster name"
}

variable "env" {
  description = "Environment name"
}

variable "app" {
  description = "App name"
}

variable "name_prefix" {
  description = "Bucket name prefix"
  default     = ""
}

variable "root_domain" {
  description = "Base domain to attach name prefix and environment to ({prefix}{env}.{base_domain})"
}

variable "aws_tag_hosting_account" {
  description = "The AWS account hosting the resources."
}

variable "aws_tag_team" {
  description = "The team within glidecloud responsible for managing this resource."
}

variable "aws_tag_customer" {
  description = "Customer name if this resource is targeted for a specific customer."
}

variable "aws_tag_cost_center" {
  description = "Business unit of specific customer."
}
