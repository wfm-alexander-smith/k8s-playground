terraform {
  backend "s3" {}
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

data "aws_availability_zones" "available" {}

# Shuffle some of the AZs to avoid having all the NAT and Internet gateways in the same AZ
locals {
  az_chunks   = ["${chunklist(data.aws_availability_zones.available.names, 2)}"]
  az_shuffled = ["${concat(local.az_chunks[1], local.az_chunks[0])}"]
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.40.0"

  name = "${var.account}-mgmt-vpc"
  cidr = "${var.vpc_cidr_block}"

  # ===================================
  # Resources modified by adding tags here:
  # - VPC
  # - EIP
  # - Private/Public route tables
  # - Private/Public subnets
  # - IGW
  # - NAT gateway
  # ===================================
  tags = "${
    map(
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"

  azs = ["${local.az_shuffled}"]

  private_subnets = [
    "${cidrsubnet(var.vpc_cidr_block, 8, 1)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 2)}",
  ]

  public_subnets = [
    "${cidrsubnet(var.vpc_cidr_block, 8, 51)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 52)}",
  ]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Include this so default route table gets tagged with the cluster and name
resource "aws_default_route_table" "r" {
  default_route_table_id = "${module.vpc.default_route_table_id}"

  tags = "${
    map(
      "Name", "${var.account}-mgmt-default",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["encr-amazon-linux2*"]
  }

  owners = ["self"]
}

resource "aws_security_group" "bastion" {
  name        = "${var.account}-mgmt-bastion"
  description = "Allow incoming and outgoing bastion connections"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    description = "Allow incoming SSH connections from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow incoming RDP connections from anywhere"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outgoing connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
      map(
       "Name", "${var.account}-mgmt-bastion",
       "Team", "${var.aws_tag_team}",
       "Customer", "${var.aws_tag_customer}",
       "Cost Center", "${var.aws_tag_cost_center}",
      )
    }"
}

resource "aws_launch_configuration" "bastion" {
  name_prefix     = "${var.account}-mgmt-bastion"
  image_id        = "${data.aws_ami.amazon_linux.id}"
  instance_type   = "${var.bastion_instance_type}"
  security_groups = ["${aws_security_group.bastion.id}"]
  key_name        = "prodOregon"

  user_data = <<EOF
#cloud-config
ssh_authorized_keys: ${jsonencode(var.ssh_authorized_keys)}
EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion" {
  name                 = "${var.account}-mgmt-bastion"
  launch_configuration = "${aws_launch_configuration.bastion.name}"
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  vpc_zone_identifier  = ["${module.vpc.public_subnets}"]

  tag {
    key                 = "Name"
    value               = "${var.account}-mgmt-bastion"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["encr-amazon-eks-node-*"]
  }

  most_recent = true
  owners      = ["self"] # Amazon
}

resource "aws_iam_role" "terraform" {
  name = "${var.account}-mgmt-terraform-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = "${
      map(
       "Name", "${var.account}-mgmt-bastion-role",
       "Team", "${var.aws_tag_team}",
       "Customer", "${var.aws_tag_customer}",
       "Cost Center", "${var.aws_tag_cost_center}",
      )
    }"
}

resource "aws_iam_instance_profile" "terraform" {
  name = "${var.account}-mgmt-terraform"
  role = "${aws_iam_role.terraform.name}"
}

resource "aws_iam_role_policy" "terraform" {
  name = "${var.account}-mgmt-terraform"
  role = "${aws_iam_role.terraform.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "acm:*",
        "autoscaling:*",
        "cloudfront:*",
        "dynamodb:*",
        "ec2:*",
        "eks:*",
        "elasticache:*",
        "elasticloadbalancing:*",
        "es:*",
        "iam:*",
        "rds:*",
        "route53:*",
        "s3:*",
        "sns:*",
        "ssm:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": "iam:CreateServiceLinkedRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::*:role/aws-service-role/elasticache.amazonaws.com/AWSServiceRoleForElastiCache",
      "Condition": {
        "StringLike": {
          "iam:AWSServiceName": "elasticache.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

resource "aws_launch_configuration" "terraform" {
  name_prefix          = "${var.account}-mgmt-terraform"
  iam_instance_profile = "${aws_iam_instance_profile.terraform.name}"
  image_id             = "${data.aws_ami.eks_worker.id}"
  instance_type        = "${var.bastion_instance_type}"
  security_groups      = ["${aws_security_group.bastion.id}"]
  key_name             = "prodOregon"

  user_data = <<EOF
#cloud-config
ssh_authorized_keys: ${jsonencode(var.ssh_authorized_keys)}
packages:
  - rsync
EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terraform" {
  name                 = "${var.account}-mgmt-terraform"
  launch_configuration = "${aws_launch_configuration.terraform.name}"
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  vpc_zone_identifier  = ["${module.vpc.public_subnets}"]

  tag {
    key                 = "Name"
    value               = "${var.account}-mgmt-terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Account"
    value               = "${var.account}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
