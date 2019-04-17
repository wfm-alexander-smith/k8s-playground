variable "name" {
  description = "Name of the group of workers (used as part of the ASG and other resource names)"
}

variable "instance_profile" {
  description = "Instance profile to assign to instances in the ASG"
}

variable "extra_policy_statements" {
  description = "A list of extra IAM policy statements to add to the instance role's policy"
  default     = []
}

variable "extra_security_groups" {
  description = "A list of extra security groups to add workers to"
  default     = []
}

variable "extra_kubelet_args" {
  description = "A string containing extra arguments to pass to kubelet"
  default     = ""
}

variable "cluster" {
  description = "Cluster name"
}

variable "cluster_endpoint" {
  description = "URL of the EKS cluster API to connect instances to"
}

variable "cluster_ca" {
  description = "CA data of the EKS cluster"
}

variable "worker_type" {
  description = "EC2 instance type to use for EKS workers"
  default     = "m5.large"
}

variable "num_workers" {
  description = "Number of workers to intially set the auto-scaling group to"
  default     = 3
}

variable "min_workers" {
  description = "Minimum number of workers for the auto-scaling group"
  default     = 1
}

variable "max_workers" {
  description = "Maximum number of workers for the auto-scaling group"
  default     = 6
}

# VPC Vars
variable "vpc_id" {
  description = "ID of the VPC to attach the cluster"
}

variable "private_subnet_ids" {
  type = "list"
}

variable "public_subnet_ids" {
  type = "list"
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
