variable "vpc_id" {}

variable "vpc_cidr_block" {}

variable "cluster" {}

variable "db_subnet_ids" {
  type        = "list"
  description = "Database subnet ids"
}

variable "db_subnet_group" {
  description = "Subnet group name for DB cluster instance"
}

variable "instance_class" {
  description = "Instance type of data nodes in the cluster"
  default     = "r4.large.elasticsearch"
}

variable "instance_count" {
  description = "Number of instances in the ES cluster"
  default = 2
}

variable "esb_volume_size" {
  description = "The size of EBS volumes attached to data nodes (in GB)"
  default      = 20
}

variable "allowed_security_groups" {
  description = "List of security groups allowed to access the Elasticsearch domain"
  type        = "list"
}

variable "port" {
  description = "Port to use for incoming Elasticsearch connections"
  default     = "443"
}

variable "worker_iam_role_arn" {
  description = "ARN of the role assigned to EKS workers"
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
