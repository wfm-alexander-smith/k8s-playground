resource "random_string" "password" {
  length           = 32
  special          = true
  override_special = ",._+%-" # Limit so unescaped shell stuff doesn't break
}

locals {
  name    = "${var.cluster}-${var.env}-${var.app}${var.name_extra}-${var.engine}"
  db_user = "${replace("${var.app}${var.name_extra}", "/\\W+/", "_")}"            # DB name needs to only be "word" characters ([a-zA-Z_])
}

resource "aws_security_group" "this" {
  name        = "${local.name}"
  description = "${local.name} Security Group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    description     = "Allow ${var.cluster} EKS workers to access ${local.name}"
    protocol        = "tcp"
    from_port       = "${var.port}"
    to_port         = "${var.port}"
    security_groups = ["${var.worker_security_group}"]
  }

  ingress {
    description = "Allow ${var.cluster} Management VPC to access ${local.name}"
    protocol    = "tcp"
    from_port   = "${var.port}"
    to_port     = "${var.port}"
    cidr_blocks = ["${var.mgmt_vpc_cidr_block}"]
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

resource "aws_db_parameter_group" "this" {
  name        = "${local.name}"
  family      = "${var.parameter_group_family}"
  description = "${local.name} Parameter Group"

  tags = "${
    map(
      "Name", "${local.name} Parameter Group",
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

resource "aws_db_instance" "this" {
  identifier              = "${local.name}"
  allocated_storage       = "${var.allocated_storage}"
  storage_type            = "${var.storage_type}"
  engine                  = "${var.engine}"
  engine_version          = "${var.engine_version}"
  instance_class          = "${var.instance_class}"
  username                = "${local.db_user}"
  password                = "${random_string.password.result}"
  backup_retention_period = "${var.backup_retention_period}"
  multi_az                = "${var.multi_az}"
  storage_encrypted       = "${var.encrypt_at_rest}"
  parameter_group_name    = "${aws_db_parameter_group.this.name}"
  backup_window           = "${var.backup_window}"
  maintenance_window      = "${var.maintenance_window}"

  final_snapshot_identifier = "${local.name}-final"
  skip_final_snapshot       = "${var.skip_final_snapshot}"

  db_subnet_group_name   = "${var.db_subnet_group}"
  vpc_security_group_ids = ["${aws_security_group.this.id}"]

  apply_immediately = "${var.apply_immediately}"

  tags = "${
    map(
      "Name", "${local.name} DB",
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
