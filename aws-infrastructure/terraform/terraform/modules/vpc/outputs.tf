output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "vpc_cidr_block" {
  value = "${module.vpc.vpc_cidr_block}"
}

output "public_subnet_ids" {
  value = "${module.vpc.public_subnets}"
}

output "private_subnet_ids" {
  value = "${module.vpc.private_subnets}"
}

output "database_subnet_ids" {
  value = "${module.vpc.database_subnets}"
}

output "public_route_table_ids" {
  value = "${module.vpc.public_route_table_ids}"
}

output "private_route_table_ids" {
  value = "${module.vpc.private_route_table_ids}"
}

output "elasticache_subnet_group_name" {
  value = "${module.vpc.elasticache_subnet_group_name}"
}

output "db_subnet_group_name" {
  value = "${module.vpc.database_subnet_group}"
}
