data "aws_caller_identity" "current" {}

locals {
  roles_to_map = [
    "admin",
    "dev-glidecloud",
    "qa-glidecloud",
    "prod-glidecloud",
    "stage-glidecloud",
  ]

  groups_to_map = [
    "system:masters",
    "dev-glidecloud-rw",
    "qa-glidecloud-rw",
    "prod-glidecloud-rw",
    "stage-glidecloud-rw",
  ]
}

resource "aws_iam_role" "mapped" {
  count = "${length(local.roles_to_map)}"

  name        = "k8s-${var.cluster}-${local.roles_to_map[count.index]}"
  description = "Allow users to access the ${local.groups_to_map[count.index]} group in the ${var.cluster} k8s cluster."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
    "Action": "sts:AssumeRole"
  }
}
EOF

  tags = "${
  map(
    "Name", "k8s-${var.cluster}-${local.roles_to_map[count.index]}",
    "Cluster", "${var.cluster}",
    "kubernetes.io/cluster/${var.cluster}", "shared",
    "Hosting Account", "${var.aws_tag_hosting_account}",
    "Team", "${var.aws_tag_team}",
    "Customer", "${var.aws_tag_customer}",
    "Cost Center", "${var.aws_tag_cost_center}",
  )
}"
}

resource "aws_iam_policy" "allow_assume" {
  count = "${length(local.roles_to_map)}"

  name        = "k8s-${var.cluster}-${local.roles_to_map[count.index]}"
  description = "Allow users to assume the k8s-${var.cluster}-${local.roles_to_map[count.index]} role"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "${aws_iam_role.mapped.*.arn[count.index]}"
    }
  ]
}
EOF
}

data "template_file" "role_mapping" {
  count = "${length(local.roles_to_map)}"

  template = <<EOF
- rolearn: ${aws_iam_role.mapped.*.arn[count.index]}
  username: ${local.roles_to_map[count.index]}:{{SessionName}}
  groups:
    - ${local.groups_to_map[count.index]}
EOF
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data {
    mapRoles = <<YAML
- rolearn: ${module.app_role.iam_role_arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
- rolearn: ${module.system_role.iam_role_arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
- rolearn: ${local.terraform_role_arn}
  username: terraform
  groups:
    - system:masters
${join("", data.template_file.role_mapping.*.rendered)}
YAML

    mapUsers = <<YAML
    - userarn: arn:aws:iam::815667184744:user/brian.baker
      username: brian.baker
      groups:
        - system:masters
    - userarn: arn:aws:iam::815667184744:user/paul.bonser
      username: paul.bonser
      groups:
        - system:masters
    - userarn: arn:aws:iam::815667184744:user/circleci.builder
      username: circleci.builder
      groups:
        - system:masters
YAML
  }
}
