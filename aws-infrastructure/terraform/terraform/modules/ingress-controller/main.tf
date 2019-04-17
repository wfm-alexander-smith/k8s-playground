locals {
  role_name = "${var.cluster}-alb-ingress-role"
}

resource "aws_iam_role" "ingress" {
  name        = "${local.role_name}"
  description = "Provide permissions to allow aws-alb-ingress-controller to work for the ${var.cluster} cluster."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${var.kiam_server_role}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${
    map(
     "Name", "${local.role_name}",
     "Cluster", "${var.cluster}",
     "kubernetes.io/cluster/${var.cluster}", "owned",
     "Hosting Account", "${var.aws_tag_hosting_account}",
     "Team", "${var.aws_tag_team}",
     "Customer", "${var.aws_tag_customer}",
     "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_iam_role_policy" "ingress" {
  name   = "${var.cluster}-alb-ingress-policy"
  role   = "${aws_iam_role.ingress.id}"
  policy = "${file("${path.module}/alb-ingress-policy.json")}"
}

resource "aws_security_group" "alb" {
  name        = "${var.cluster}-ingress-alb"
  description = "Shared security group to allow incoming connections to ALBs and from ALBs to workers."
  vpc_id      = "${var.vpc_id}"

  ingress {
    description = "Allow all incoming HTTP traffic"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all incoming HTTPS traffic"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outgoing traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.cluster}-ingress-alb",
     "Cluster", "${var.cluster}",
     "kubernetes.io/cluster/${var.cluster}", "owned",
     "Hosting Account", "${var.aws_tag_hosting_account}",
     "Team", "${var.aws_tag_team}",
     "Customer", "${var.aws_tag_customer}",
     "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

# Add a rule to the worker security group to allow all incoming traffic from the ingress ALBs
resource "aws_security_group_rule" "eks_worker_ingress_alb" {
  description              = "Allow ALBs to send all traffic"
  protocol                 = "tcp"
  from_port                = 0
  to_port                  = 65535
  security_group_id        = "${var.worker_security_group}"
  source_security_group_id = "${aws_security_group.alb.id}"
  type                     = "ingress"
}

# Manifests based on https://github.com/kubernetes-sigs/aws-alb-ingress-controller/tree/master/examples
locals {
  namespace = "alb-ingress"

  manifests = [
    "service-account",
    "cluster-role",
    "cluster-role-binding",
    "deployment",
  ]
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "${local.namespace}"

    annotations {
      "iam.amazonaws.com/permitted" = "${local.role_name}"
    }
  }
}

data "template_file" "manifest" {
  count = "${length(local.manifests)}"

  template = "${file("${path.module}/k8s-manifests/${local.manifests[count.index]}.yaml")}"

  vars {
    aws_region   = "${var.aws_region}"
    cluster_name = "${var.cluster}"
    namespace    = "${kubernetes_namespace.ns.metadata.0.name}"
    role_name    = "${local.role_name}"
    vpc_id       = "${var.vpc_id}"
  }
}

resource "k8s_manifest" "manifest" {
  count = "${length(local.manifests)}"

  content = "${data.template_file.manifest.*.rendered[count.index]}"
}
