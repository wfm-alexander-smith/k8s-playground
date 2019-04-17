variable "bastion_instance_type" {
  description = "EC2 instance type to use for the bastion host"
  default     = "t3.small"
}

variable "win_bastion_instance_type" {
  description = "EC2 instance type to use for the Windows bastion host"
  default     = "t3.large"
}

variable "account" {
  description = "AWS account name to tag resources with (production/development)"
}

variable "ssh_authorized_keys" {
  description = "SSH public keys to add to the ~/.ssh/authorized_keys file of the ec2-user account on the bastion node"
  type        = "list"
  default     = []
}

variable "vpc_cidr_block" {
  description = "CIDR block to use as the base for the VPC's subnets"
  default     = "172.31.0.0/16"
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

