output "id" {
  value = "${aws_elasticsearch_domain.es.domain_id}"
}

output "domain_name" {
  value = "${aws_elasticsearch_domain.es.domain_name}"
}

output "arn" {
  value = "${aws_elasticsearch_domain.es.arn}"
}

output "endpoint" {
  value = "${aws_elasticsearch_domain.es.endpoint}"
}

output "kibana_endpoint" {
  value = "${aws_elasticsearch_domain.es.kibana_endpoint}"
}
