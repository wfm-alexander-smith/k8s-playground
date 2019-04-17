data "aws_caller_identity" "current" {}

locals {
  ns = "kiam"
}

resource "aws_iam_role" "server_role" {
  name        = "${var.cluster}-kiam-server"
  description = "Role for the Kiam Server process to assume in the ${var.cluster} cluster"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster}-system-eks-worker-role"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Allow Kiam server to assume any role
resource "aws_iam_role_policy" "server_policy" {
  name = "${var.cluster}-kiam-server"
  role = "${aws_iam_role.server_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "${local.ns}"
  }
}

locals {
  ca_cert = "${tls_self_signed_cert.ca.cert_pem}"
}

resource "kubernetes_secret" "server_tls" {
  metadata {
    name      = "kiam-server-tls"
    namespace = "${local.ns}"
  }

  data {
    "ca.pem"         = "${tls_self_signed_cert.ca.cert_pem}"
    "server.pem"     = "${tls_locally_signed_cert.server.cert_pem}"
    "server-key.pem" = "${tls_private_key.server.private_key_pem}"
  }
}

resource "kubernetes_secret" "agent_tls" {
  metadata {
    name      = "kiam-agent-tls"
    namespace = "${local.ns}"
  }

  data {
    "ca.pem"        = "${tls_self_signed_cert.ca.cert_pem}"
    "agent.pem"     = "${tls_locally_signed_cert.agent.cert_pem}"
    "agent-key.pem" = "${tls_private_key.agent.private_key_pem}"
  }
}

locals {
  manifests = [
    "service-account",
    "read-role",
    "read-role-binding",
    "write-role",
    "write-role-binding",
    "server-daemonset",
    "server-service",
    "agent-daemonset",
  ]
}

data "template_file" "manifest" {
  count = "${length(local.manifests)}"

  template = "${file("${path.module}/k8s-manifests/${local.manifests[count.index]}.yaml")}"

  vars {
    namespace       = "${local.ns}"
    server_role_arn = "${aws_iam_role.server_role.arn}"
  }
}

resource "k8s_manifest" "manifest" {
  count = "${length(local.manifests)}"

  content = "${data.template_file.manifest.*.rendered[count.index]}"
}
