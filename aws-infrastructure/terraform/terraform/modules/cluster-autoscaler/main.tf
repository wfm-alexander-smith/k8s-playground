resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster}-cluster-autoscaler-role"

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
       "Name", "${var.cluster}-cluster-autoscaler-role",
       "Cluster", "${var.cluster}",
       "kubernetes.io/cluster/${var.cluster}", "owned",
       "Hosting Account", "${var.aws_tag_hosting_account}",
       "Team", "${var.aws_tag_team}",
       "Customer", "${var.aws_tag_customer}",
       "Cost Center", "${var.aws_tag_cost_center}",
      )
    }"
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "${var.cluster}-cluster-autoscaler-policy"
  role = "${aws_iam_role.cluster_autoscaler.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster}": "owned"
        }
      }
    }
  ]
}
EOF
}
