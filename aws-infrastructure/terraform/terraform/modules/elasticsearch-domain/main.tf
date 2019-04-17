# Shared Elasticsearch domain (use at the cluster-level)

locals {
  domain_name   = "${var.cluster}"
  instance_type = "${var.instance_class}"
  worker_role   = "${var.worker_iam_role_arn}"
}

resource "aws_security_group" "es" {
  name        = "${local.domain_name}-elasticsearch"
  description = "${local.domain_name} Security Group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    description = "Allow ${var.cluster} Management VPC to access ${local.domain_name}"
    protocol    = "tcp"
    from_port   = "${var.port}"
    to_port     = "${var.port}"
    cidr_blocks = ["${var.vpc_cidr_block}"]
  }

  tags = "${
    map(
      "Name", "${local.domain_name} Security Group",
      "Cluster", "${var.cluster}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_elasticsearch_domain" "es" {
  domain_name           = "${local.domain_name}"
  elasticsearch_version = "6.4"

  encrypt_at_rest {
    enabled = true
  }

  cluster_config {
    instance_type          = "${local.instance_type}"
    instance_count         = "${var.instance_count}"
    zone_awareness_enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = "${var.esb_volume_size}"
  }

  vpc_options {
    subnet_ids = [
      "${var.db_subnet_ids[0]}",
      "${var.db_subnet_ids[1]}",
    ]

    security_group_ids = ["${aws_security_group.es.id}"]
  }

  advanced_options {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": "es:*",
        "Resource": "arn:aws:es:::domain/${local.domain_name}/*"
      }
    ]
}
CONFIG

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  tags = "${
    map(
      "Name", "${local.domain_name} Elasticsearch Domain",
      "Cluster", "${var.cluster}",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}
