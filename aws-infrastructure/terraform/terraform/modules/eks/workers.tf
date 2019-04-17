locals {
  ssm_policy_statements = [
    # Provides access to SSM for Session Manager
    <<EOF
    {
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:GetManifest",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstanceStatus"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ds:CreateComputer",
        "ds:DescribeDirectories"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": [
        "arn:aws:s3:::aws-ssm-us-east-1/*",
        "arn:aws:s3:::aws-windows-downloads-us-east-1/*",
        "arn:aws:s3:::amazon-ssm-us-east-1/*",
        "arn:aws:s3:::amazon-ssm-packages-us-east-1/*",
        "arn:aws:s3:::us-east-1-birdwatcher-prod/*",
        "arn:aws:s3:::aws-ssm-us-west-2/*",
        "arn:aws:s3:::aws-windows-downloads-us-west-2/*",
        "arn:aws:s3:::amazon-ssm-us-west-2/*",
        "arn:aws:s3:::amazon-ssm-packages-us-west-2/*",
        "arn:aws:s3:::us-west-2-birdwatcher-prod/*"
      ]
    }
EOF
    ,
  ]

  system_policy_statements = [
    # Allow this role to assume itself (to generate temporary credentials with a shorter TTL)
    <<EOF
    {
      "Action": ["sts:AssumeRole"],
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster}-system-eks-worker-role",
      "Effect": "Allow"
    }
EOF
    ,

    # Allow this role to assume the kiam server role
    <<EOF
    {
      "Action": ["sts:AssumeRole"],
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster}-kiam-server",
      "Effect": "Allow"
    }
EOF
    ,
  ]
}

resource "aws_security_group" "eks_worker" {
  name        = "${var.cluster}-eks-worker"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${local.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.cluster}-eks-worker",
     "Cluster", "${var.cluster}",
     "kubernetes.io/cluster/${var.cluster}", "owned",
     "Hosting Account", "${var.aws_tag_hosting_account}",
     "Team", "${var.aws_tag_team}",
     "Customer", "${var.aws_tag_customer}",
     "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_security_group_rule" "eks_worker_ingress_self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.eks_worker.id}"
  source_security_group_id = "${aws_security_group.eks_worker.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_worker_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_worker.id}"
  source_security_group_id = "${aws_security_group.eks_cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_worker_https_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive HTTPS communication from the cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_worker.id}"
  source_security_group_id = "${aws_security_group.eks_cluster.id}"
  to_port                  = 443
  type                     = "ingress"
}

module "app_role" {
  source = "../eks-worker-role"

  name                    = "application"
  cluster                 = "${var.cluster}"
  extra_policy_statements = ["${local.ssm_policy_statements}"]
  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"
}

module "app_workers" {
  source = "../eks-workers"

  name                    = "application"
  instance_profile        = "${module.app_role.instance_profile}"
  extra_security_groups   = ["${aws_security_group.eks_worker.id}"]
  cluster                 = "${var.cluster}"
  cluster_endpoint        = "${aws_eks_cluster.cluster.endpoint}"
  cluster_ca              = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
  worker_type             = "${var.worker_type}"
  num_workers             = "${var.num_workers}"
  min_workers             = "${var.min_workers}"
  max_workers             = "${var.max_workers}"
  vpc_id                  = "${local.vpc_id}"
  private_subnet_ids      = "${local.private_subnet_ids}"
  public_subnet_ids       = "${local.public_subnet_ids}"
  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"
}

module "system_role" {
  source = "../eks-worker-role"

  name                    = "system"
  cluster                 = "${var.cluster}"
  extra_policy_statements = ["${concat(local.system_policy_statements, local.ssm_policy_statements)}"]
  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"
}

module "system_workers" {
  source = "../eks-workers"

  name                    = "system"
  instance_profile        = "${module.system_role.instance_profile}"
  extra_security_groups   = ["${aws_security_group.eks_worker.id}"]
  extra_kubelet_args      = "--register-with-taints node-role.kubernetes.io/system=true:NoSchedule"
  cluster                 = "${var.cluster}"
  cluster_endpoint        = "${aws_eks_cluster.cluster.endpoint}"
  cluster_ca              = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
  worker_type             = "${var.worker_type}"
  num_workers             = "${var.num_workers}"
  min_workers             = "${var.min_workers}"
  max_workers             = "${var.max_workers}"
  vpc_id                  = "${local.vpc_id}"
  private_subnet_ids      = "${local.private_subnet_ids}"
  public_subnet_ids       = "${local.public_subnet_ids}"
  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"
}
