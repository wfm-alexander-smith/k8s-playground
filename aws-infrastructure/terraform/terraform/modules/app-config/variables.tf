variable "cluster" {
  description = "Cluster name"
}

variable "env" {
  description = "Environment name"
}

variable "app" {
  description = "App name"
}

variable "configmap_name" {
  description = "Name of the configmap to create"
}

# DB Variables

variable "db_host" {}
variable "db_name" {}
variable "db_user" {}
variable "db_pass" {}
variable "db_port" {}

# Redis Variables

variable "redis_auth" {}
variable "redis_host" {}
variable "redis_port" {}

# S3 variables
variable "bucket_name" {}

# Namespace variables
variable "namespace" {}

# Cert variables
variable "cert_arn" {}
