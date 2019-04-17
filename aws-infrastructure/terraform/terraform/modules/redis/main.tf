locals {
  name       = "${var.cluster}-${var.env}-${var.app}${var.name_extra}-redis"
  short_name = "${length(local.name) > 20 ? substr(format("%s-%s%s", var.cluster, var.env, md5(local.name)), 0, 20) : local.name}"
}

resource "random_string" "auth_token" {
  length      = 64
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

resource "aws_security_group" "this" {
  name        = "${local.name}"
  description = "${local.name} Redis Security Group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    description     = "Allow ${var.cluster} EKS workers to access ${local.name}"
    protocol        = "tcp"
    from_port       = "${var.port}"
    to_port         = "${var.port}"
    security_groups = ["${var.worker_security_group}"]
  }

  tags = "${
    map(
      "Name", "${local.name} Security Group",
      "Cluster", "${var.cluster}",
      "Environment", "${var.env}",
      "Application", "${var.app}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id          = "${local.short_name}"
  replication_group_description = "${local.name} cluster for the ${var.app} app"
  node_type                     = "${var.node_type}"
  port                          = "${var.port}"
  automatic_failover_enabled    = "${var.automatic_failover_enabled}"
  auth_token                    = "${random_string.auth_token.result}"

  subnet_group_name  = "${var.elasticache_subnet_group}"
  security_group_ids = ["${aws_security_group.this.id}"]

  engine                     = "redis"
  engine_version             = "4.0.10"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  number_cache_clusters = "${var.replicas_per_node_group}"

  # Disabling cluster_mode for now because it requires a separate library to support
  /* cluster_mode {
    replicas_per_node_group = "${var.replicas_per_node_group}"
    num_node_groups         = "${var.num_node_groups}"
  } */

  tags = "${
    map(
      "Name", "${local.name}",
      "Cluster", "${var.cluster}",
      "Environment", "${var.env}",
      "Application", "${var.app}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}
