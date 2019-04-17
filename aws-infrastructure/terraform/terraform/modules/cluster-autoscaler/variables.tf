variable "cluster" {
  description = "Name of the cluster where this is being deployed"
}

variable "aws_region" {
  description = "AWS Region in which ASGs live"
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

variable "kiam_server_role" {
  description = "ARN of the Kiam server role (used to allow it to assume this role)"
}
