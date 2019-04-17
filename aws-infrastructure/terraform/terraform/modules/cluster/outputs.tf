# VPC Outputs
output "vpc_id" {
  value = "${local.vpc_id}"
}

output "mgmt_vpc_cidr_block" {
  value = "${data.terraform_remote_state.mgmt_vpc.vpc_cidr_block}"
}

output "db_subnet_group" {
  value = "${local.vpc_db_subnet_group}"
}

output "elasticache_subnet_group" {
  value = "${local.vpc_elasticache_subnet_group}"
}

# EKS Outputs
output "eks_cluster_endpoint" {
  value = "${local.eks_cluster_endpoint}"
}

output "eks_cluster_ca_cert" {
  value = "${local.eks_cluster_ca_cert}"
}

output "eks_worker_iam_role_name" {
  value = "${local.eks_worker_iam_role_name}"
}

output "kiam_server_role" {
  value = "${module.kiam.server_role_arn}"
}

output "eks_worker_iam_role_arn" {
  value = "${local.eks_worker_iam_role_arn}"
}

output "eks_worker_security_group" {
  value = "${local.eks_worker_security_group_id}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

output "kubeconfig_path" {
  value = "${local.kubeconfig_path}"
}

resource "aws_ssm_parameter" "kubeconfig" {
  name = "/${var.cluster}/kubeconfig"
  type = "String"

  value = <<EOF
${local.kubeconfig}
        - --role
        - arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/k8s-${var.cluster}-admin
EOF
}

# glidecloud DB outputs
output "glidecloud_db_host" {
  value = "${module.glidecloud_db.host}"
}

output "glidecloud_db_port" {
  value = "${module.glidecloud_db.port}"
}

output "glidecloud_db_user" {
  value = "${module.glidecloud_db.username}"
}

output "glidecloud_db_password" {
  value     = "${module.glidecloud_db.password}"
  sensitive = true
}

# Elasticsearch domain outputs
output "es_host" {
  value     = "${module.elasticsearch_domain.endpoint}"
}
