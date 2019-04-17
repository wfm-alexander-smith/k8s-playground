terraform {
  backend "s3" {}
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

data "terraform_remote_state" "mgmt_vpc" {
  backend = "s3"

  config {
    region       = "${var.tfstate_region}"
    bucket       = "${var.tfstate_bucket}"
    key          = "resources/mgmt-vpc/terraform.tfstate"
    profile      = "${var.aws_profile}"
    dynodb_table = "${var.tfstate_lock_table}"
  }
}

data "aws_availability_zones" "available" {}

locals {
  mgmt_vpc_id                  = "${data.terraform_remote_state.mgmt_vpc.vpc_id}"
  mgmt_vpc_cidr_block          = "${data.terraform_remote_state.mgmt_vpc.vpc_cidr_block}"
  mgmt_vpc_private_route_table = "${data.terraform_remote_state.mgmt_vpc.private_route_table_ids[0]}"
  mgmt_vpc_public_route_table  = "${data.terraform_remote_state.mgmt_vpc.public_route_table_ids[0]}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.40.0"

  name = "${var.cluster}-vpc"
  cidr = "${var.vpc_cidr_block}"

  azs = ["${data.aws_availability_zones.available.names}"]

  private_subnets = [
    "${cidrsubnet(var.vpc_cidr_block, 8, 1)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 2)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 3)}",
  ]

  public_subnets = [
    "${cidrsubnet(var.vpc_cidr_block, 8, 51)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 52)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 53)}",
  ]

  elasticache_subnets = [
    "${cidrsubnet(var.vpc_cidr_block, 8, 151)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 152)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 153)}",
  ]

  database_subnets = [
    "${cidrsubnet(var.vpc_cidr_block, 8, 101)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 102)}",
    "${cidrsubnet(var.vpc_cidr_block, 8, 103)}",
  ]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_s3_endpoint = true

  tags = "${
    map(
      "Cluster", "${var.cluster}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"

  private_subnet_tags = "${
    map(
      "kubernetes.io/role/internal-elb", "",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"

  public_subnet_tags = "${
    map(
      "kubernetes.io/role/elb", "",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

# Include this so default route table gets tagged with the cluster and name
resource "aws_default_route_table" "r" {
  default_route_table_id = "${module.vpc.default_route_table_id}"

  tags = "${
    map(
      "Name", "${var.cluster}-default",
      "Cluster", "${var.cluster}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

# Peering connection to the account-wide management VPC
resource "aws_vpc_peering_connection" "mgmt" {
  peer_vpc_id = "${local.mgmt_vpc_id}"
  vpc_id      = "${module.vpc.vpc_id}"
  auto_accept = true

  tags = "${
    map(
      "Name", "${var.cluster}-to-mgmt-vpc",
      "Cluster", "${var.cluster}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

# Routing between management VPC and cluster VPC
resource "aws_route" "private_to_mgmt" {
  route_table_id            = "${module.vpc.private_route_table_ids[0]}"
  destination_cidr_block    = "${local.mgmt_vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.mgmt.id}"
}

resource "aws_route" "public_to_mgmt" {
  route_table_id            = "${module.vpc.public_route_table_ids[0]}"
  destination_cidr_block    = "${local.mgmt_vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.mgmt.id}"
}

resource "aws_route" "mgmt_to_private" {
  route_table_id            = "${local.mgmt_vpc_private_route_table}"
  destination_cidr_block    = "${module.vpc.vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.mgmt.id}"
}

resource "aws_route" "mgmt_to_public" {
  route_table_id            = "${local.mgmt_vpc_public_route_table}"
  destination_cidr_block    = "${module.vpc.vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.mgmt.id}"
}
