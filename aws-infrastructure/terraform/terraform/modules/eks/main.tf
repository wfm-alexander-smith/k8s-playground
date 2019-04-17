terraform {
  backend "s3" {}
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    region       = "${var.tfstate_region}"
    bucket       = "${var.tfstate_bucket}"
    key          = "clusters/${var.cluster}/resources/vpc/terraform.tfstate"
    profile      = "${var.aws_profile}"
    dynodb_table = "${var.tfstate_lock_table}"
  }
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

locals {
  # VPC vars
  vpc_id             = "${data.terraform_remote_state.vpc.vpc_id}"
  private_subnet_ids = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]
  public_subnet_ids  = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]
  terraform_role_arn = "${data.terraform_remote_state.mgmt_vpc.terraform_role_arn}"
}

data "external" "auth_token" {
  program = ["bash", "${path.module}/scripts/auth-token.sh"]

  query {
    aws_profile  = "${var.aws_profile}"
    cluster_name = "${aws_eks_cluster.cluster.name}"
  }
}

data "external" "ensure_kubeconfig" {
  program = ["bash", "${path.module}/scripts/ensure_file.sh"]

  query {
    filename = "${path.module}/.kube/config"
    content  = "${local.kubeconfig}"
  }
}

provider "kubernetes" {
  host                   = "${aws_eks_cluster.cluster.endpoint}"
  cluster_ca_certificate = "${base64decode(aws_eks_cluster.cluster.certificate_authority.0.data)}"
  token                  = "${data.external.auth_token.result["token"]}"
  load_config_file       = false
}
