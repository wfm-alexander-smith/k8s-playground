variable "aws_region" {}
variable "vpc_id" {}

variable "cluster" {
  description = "Cluster name"
}

variable "kiam_server_role" {
  description = "ARN of the Kiam server role (used to allow it to assume this role)"
}

variable "worker_iam_role" {
  description = "Name of the IAM role associated to EKS workers"
}

variable "worker_security_group" {
  description = "ID of the security group associated to EKS workers"
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
