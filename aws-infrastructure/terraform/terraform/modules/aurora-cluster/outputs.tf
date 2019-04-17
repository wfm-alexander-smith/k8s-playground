output "username" {
  value = "${aws_rds_cluster.this.master_username}"
}

output "password" {
  value     = "${local.db_pass}"
  sensitive = true
}

output "host" {
  value = "${aws_rds_cluster.this.endpoint}"
}

output "port" {
  value = "${element(concat(aws_rds_cluster_instance.instance.*.port, list("")), 0)}"
}
