variable "cluster" {
  description = "Cluster name"
}

variable "env" {
  description = "Environment name"
}

variable "app" {
  description = "App name"
}

variable "name_extra" {
  description = "Extra stuff to append to the end of the bucket name in case of more than one bucket per app"
  default     = ""
}

variable "topic_name_extra" {
  description = "Extra stuff to append to the end of the sns topic name in case of more than one topic per app"
  default     = ""
}

variable "worker_iam_role_arn" {
  description = "ARN of the role assigned to EKS workers"
}

# Variables used for AWS resources
variable "aws_region" {
  description = "AWS Region to use"
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

variable "enable_sns_notifications" {
  description = "If set to true, configure sns notification on bucket put objects"
  default = false
}