variable "vpc_id" {}

variable "cluster" {
  description = "Cluster name (should be kept [a-zA-z-_])"
}

variable "env" {
  description = "Environment name (should be kept [a-zA-z-_])"
}

variable "app" {
  description = "App name (should be kept [a-zA-z-_])"
}

variable "worker_security_group" {
  description = "EKS worker security group ID"
}

variable "mgmt_vpc_cidr_block" {
  description = "CIDR block of management VPC"
  default     = ""
}

variable "db_subnet_group" {
  description = "Subnet group name for DB instance"
}

variable "name_extra" {
  description = "Extra stuff to add to the database name (needed if there's more than one DB for the app)"
  default     = ""
}

variable "force_ssl" {
  description = "Force incoming connections to use SSL"
  default     = true
}

variable "encrypt_at_rest" {
  description = "Specifies whether the DB instance is encrypted"
  default     = true
}

variable "port" {
  description = "Port for the DB to listen on (e.g. 5432 for psql)"
}

variable "apply_immediately" {
  description = "Apply database changes immediatley"
  default     = false
}

variable "allocated_storage" {
  description = "Number GB of storage to allocate for the DB"
}

variable "storage_type" {
  description = "RDS storage type to use"
  default     = "gp2"
}

variable "iops" {
  description = "IOPS to provision (only for storage_type of 'io1')"
  default     = ""
}

variable "engine" {
  description = "RDS Engine to use (e.g. 'postgres')"
}

variable "engine_version" {
  description = "RDS engine version to use (e.g. '10.4')"
}

variable "parameter_group_family" {
  description = "RDS Parameter Group family (e.g. postgres10)"
}

variable "instance_class" {
  description = "DB instance class to use (e.g. db.t2.micro)"
}

variable "backup_retention_period" {
  description = "How many days to retain backups for"
  default     = 14
}

variable "backup_window" {
  description = "Preferred time period for Amazon to do daily backups of the instance (UTC, format 00:00-02:30)"
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Preferred time period for Amazon to do maintenance on the instance (UTC, format 'Mon:00:00-Mon:03:00')"
  default     = "Wed:03:00-Wed:04:00"
}

variable "multi_az" {
  description = "Whether or not this should be multi-az"
  default     = true
}

variable "replicate_source_db" {
  description = "If this DB should be a read-replica, the identifier of the master DB (should be in form ENV-NAME-postgresql)"
  default     = ""
}

variable "skip_final_snapshot" {
  description = "Don't create a final snapshot when deleting this RDS instance (bad idea on prod)"
  default     = false
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
