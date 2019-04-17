variable "vpc_id" {}

variable "worker_security_group" {}

variable "elasticache_subnet_group" {}

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
  description = "Extra stuff to add to the redis cluster name (needed if there's more than one redis cluster for the app)"
  default     = ""
}

variable "node_type" {
  description = "Elasticache instance type to use for Redis nodes"
}

variable "num_node_groups" {
  description = "Number of Redis shards to create"
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Number of failover replicas to create per Redis shard"
}

variable "port" {
  description = "Port to use for Redis"
  default     = 6379
}

variable "automatic_failover_enabled" {
  default = true
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
