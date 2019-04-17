locals {
  name = "${replace(var.domain, "/[^\\w.]/", "_")}"
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "${var.domain}"
  validation_method         = "DNS"
  subject_alternative_names = ["${var.san_domains}"]

  tags = "${
      map(
        "Name", "${local.name}",
        "Cluster", "${var.cluster}",
        "kubernetes.io/cluster/${var.cluster}", "shared",
      )
    }"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  flattened_domains = "${aws_acm_certificate.cert.domain_validation_options}"
  len               = "${length(local.flattened_domains)}"
}

data "aws_route53_zone" "zone" {
  name = "${var.zone}"
}

resource "aws_route53_record" "cert_validation" {
  count = "${length(var.san_domains)+1}"

  name    = "${lookup(local.flattened_domains[min(local.len - 1, count.index)], "resource_record_name")}"
  type    = "${lookup(local.flattened_domains[min(local.len - 1, count.index)], "resource_record_type")}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  records = ["${lookup(local.flattened_domains[min(local.len - 1, count.index)], "resource_record_value")}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.*.fqdn}"]
}
