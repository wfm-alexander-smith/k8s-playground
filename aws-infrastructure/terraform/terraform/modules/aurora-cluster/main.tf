# Shared Aurora cluster (use at the cluster-level)
resource "random_string" "db_password" {
  length           = 32
  special          = true
  override_special = ",._+%-" # Limit so unescaped shell stuff doesn't break
}

locals {
  db_name = "${var.cluster}-${var.app}"
  db_pass = "${random_string.db_password.result}"
}

resource "aws_security_group" "db" {
  name        = "${local.db_name}-db"
  description = "Allow incoming workers and management VPC to access ${var.app} DB cluster"
  vpc_id      = "${var.vpc_id}"

  ingress {
    description = "Allow connections from specified CIDR blocks"
    protocol    = "tcp"
    from_port   = "${var.port}"
    to_port     = "${var.port}"
    cidr_blocks = ["${var.allowed_cidr_blocks}"]
  }

  ingress {
    description     = "Allow connections from specified SGs"
    protocol        = "tcp"
    from_port       = "${var.port}"
    to_port         = "${var.port}"
    security_groups = ["${var.allowed_security_groups}"]
  }

  tags = "${
    map(
     "Name", "${local.db_name}-db",
     "Cluster", "${var.cluster}",
     "Application", "${var.app}",
     "kubernetes.io/cluster/${var.cluster}", "shared",
    )
  }"
}

resource "aws_rds_cluster" "this" {
  cluster_identifier           = "${local.db_name}"
  engine                       = "aurora-postgresql"
  master_username              = "${var.app}"
  master_password              = "${local.db_pass}"
  final_snapshot_identifier    = "${local.db_name}-final"
  skip_final_snapshot          = "${var.skip_final_snapshot}"
  backup_retention_period      = "14"
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "Wed:03:00-Wed:04:00"
  port                         = "${var.port}"
  vpc_security_group_ids       = ["${aws_security_group.db.id}"]
  storage_encrypted            = true
  db_subnet_group_name         = "${var.db_subnet_group}"

  tags = "${
    map(
     "Name", "${local.db_name}",
     "Cluster", "${var.cluster}",
     "Application", "${var.app}",
     "kubernetes.io/cluster/${var.cluster}", "shared",
    )
  }"
}

resource "aws_rds_cluster_instance" "instance" {
  count = 2

  identifier           = "${local.db_name}-${count.index}"
  cluster_identifier   = "${aws_rds_cluster.this.id}"
  engine               = "aurora-postgresql"
  instance_class       = "${var.instance_class}"
  db_subnet_group_name = "${var.db_subnet_group}"

  tags = "${
    map(
     "Name", "${local.db_name}-${count.index}",
     "Cluster", "${var.cluster}",
     "Application", "${var.app}",
     "kubernetes.io/cluster/${var.cluster}", "shared",
    )
  }"
}
