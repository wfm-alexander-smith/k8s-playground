data "aws_route53_zone" "base" {
  name = "${var.root_domain}"
}

locals {
  name = "${var.cluster}-${var.env}-${var.app}"
}

resource "aws_iam_role" "zone_edit" {
  name        = "${local.name}-zone-edit-policy"
  description = "Provide permissions to allow external-dns to work for ${local.name}."

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
       "Name", "${var.cluster}-${var.env}-${var.app}",
       "Cluster", "${var.cluster}",
       "kubernetes.io/cluster/${var.cluster}", "owned",
       "Hosting Account", "${var.aws_tag_hosting_account}",
       "Team", "${var.aws_tag_team}",
       "Customer", "${var.aws_tag_customer}",
       "Cost Center", "${var.aws_tag_cost_center}",
      )
    }"
}

resource "aws_iam_role_policy" "zone_edit" {
  name = "${local.name}-zone-edit-policy"
  role = "${aws_iam_role.zone_edit.id}"

  policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": [
       "route53:ChangeResourceRecordSets"
     ],
     "Resource": [
       "arn:aws:route53:::hostedzone/${data.aws_route53_zone.base.zone_id}"
     ]
   },
   {
     "Effect": "Allow",
     "Action": [
       "route53:ListHostedZones",
       "route53:ListResourceRecordSets"
     ],
     "Resource": [
       "*"
     ]
   }
 ]
}
POLICY
}

data "template_file" "service_account" {
  template = "${file("${path.module}/k8s-manifests/service-account.yaml")}"

  vars {
    namespace = "${var.namespace}"
  }
}

resource "k8s_manifest" "service_account" {
  content = "${data.template_file.service_account.rendered}"
}

data "template_file" "role" {
  template = "${file("${path.module}/k8s-manifests/role.yaml")}"

  vars {
    namespace = "${var.namespace}"
  }
}

resource "k8s_manifest" "role" {
  content = "${data.template_file.role.rendered}"
}

data "template_file" "role_binding" {
  template = "${file("${path.module}/k8s-manifests/role-binding.yaml")}"

  vars {
    namespace = "${var.namespace}"
  }
}

resource "k8s_manifest" "role_binding" {
  content    = "${data.template_file.role_binding.rendered}"
  depends_on = ["k8s_manifest.service_account", "k8s_manifest.role"]
}

data "template_file" "deployment" {
  template = "${file("${path.module}/k8s-manifests/deployment.yaml")}"

  vars {
    cluster   = "${var.cluster}"
    name      = "${local.name}"
    domain    = "${data.aws_route53_zone.base.name}"
    namespace = "${var.namespace}"
    role_name = "${aws_iam_role.zone_edit.id}"
  }
}

resource "k8s_manifest" "deployment" {
  content    = "${data.template_file.deployment.rendered}"
  depends_on = ["k8s_manifest.role_binding"]
}
