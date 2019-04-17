variable "name" {
  description = "Name of the group of workers (used as part of the ASG and other resource names)"
}

variable "extra_policy_statements" {
  description = "A list of extra IAM policy statements to add to the instance role's policy"
  default     = []
}

variable "cluster" {
  description = "Cluster name"
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
