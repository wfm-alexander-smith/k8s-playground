variable "vpc_id" {}

variable "cluster" {
  description = "Cluster name (should be kept [a-zA-z-_])"
}

variable "app" {
  description = "App name (should be kept [a-zA-z-_])"
}

variable "db_subnet_group" {
  description = "Subnet group name for DB cluster instance"
}

variable "skip_final_snapshot" {
  default = false
}

variable "instance_class" {
  default = "db.r4.large"
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the DB cluster"
  type        = "list"
}

variable "allowed_security_groups" {
  description = "List of security groups allowed to access the DB cluster"
  type        = "list"
}

variable "port" {
  description = "Port to use for incoming DB connections"
  default     = "5432"
}
