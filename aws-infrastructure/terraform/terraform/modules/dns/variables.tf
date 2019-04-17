variable "namespace" {}

variable "cluster" {}
variable "env" {}
variable "app" {}

variable "kiam_server_role" {
  description = "ARN of the Kiam server role (used to allow it to assume this role)"
}

variable "root_domain" {
  description = "Root DNS name from which to base the k8s automatic DNS"
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
