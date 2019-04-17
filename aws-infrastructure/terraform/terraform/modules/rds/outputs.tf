output "name" {
  description = "Database name"
  value       = "${local.db_user}" # Same as DB username
}

output "username" {
  description = "Database master username"
  value       = "${local.db_user}"
}

output "password" {
  description = "Database master password"
  value       = "${random_string.password.result}"
  sensitive   = true
}

output "host" {
  description = "Database host"
  value       = "${aws_db_instance.this.address}"
}

output "port" {
  description = "Database port"
  value       = "${aws_db_instance.this.port}"
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.cluster}/${var.env}/${var.app}/db/host"
  type  = "String"
  value = "${aws_db_instance.this.address}"
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.cluster}/${var.env}/${var.app}/db/port"
  type  = "String"
  value = "${aws_db_instance.this.port}"
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/${var.cluster}/${var.env}/${var.app}/db/username"
  type  = "String"
  value = "${local.db_user}"
}

resource "aws_ssm_parameter" "db_pass" {
  name  = "/${var.cluster}/${var.env}/${var.app}/db/password"
  type  = "SecureString"
  value = "${random_string.password.result}"
}
