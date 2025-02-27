output "host" {
  description = "Redis host"
  value       = "${aws_elasticache_replication_group.this.primary_endpoint_address}"
}

output "port" {
  description = "Redis port"
  value       = "${aws_elasticache_replication_group.this.port}"
}

output "auth_token" {
  description = "Redis AUTH token"
  value       = "${random_string.auth_token.result}"
  sensitive   = true
}
