variable "cluster" {
  description = "Cluster to tag resources with"
}

variable "vpc_cidr_block" {
  description = "CIDR block to use as the base for the VPC's subnets"
  default     = "10.201.0.0/16"
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

# Variables used for AWS resources
variable "aws_region" {
  description = "AWS Region to use"
}

variable "aws_profile" {
  description = "AWS Profile to load from local AWS configs"
}

# Variables used to access remote state
variable "tfstate_region" {
  description = "AWS region to read remote state from"
}

variable "tfstate_bucket" {
  description = "S3 bucket to read remote state from"
}

variable "tfstate_lock_table" {
  description = "DynamoDB table used to lock remote state"
}
