# Need a copy of the provider in us-east-1 for Cloudfront ACM certs
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "${var.aws_profile}"
}

data "aws_route53_zone" "base" {
  name = "${var.root_domain}"
}

locals {
  domain_name = "${var.name_prefix}${var.root_domain}"
  name        = "glidecloud-${var.cluster}-${var.env}-${var.app}-frontend"
}

resource "aws_s3_bucket" "this" {
  bucket = "${local.name}"
  acl    = "public-read"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:GetObject",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${local.name}/*",
      "Principal": "*"
    }
  ]
}
EOF

  tags = "${
    map(
      "Name", "${local.name} Application frontend bucket",
      "Cluster", "${var.cluster}",
      "Environment", "${var.env}",
      "Application", "${var.app}",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

module "acm_cert" {
  providers = {
    aws = "aws.us_east_1"
  }

  source = "../acm-cert"

  cluster = "${var.cluster}"
  env     = "${var.env}"
  app     = "${local.app}"

  domain      = "${var.root_domain}"
  san_domains = ["*.${var.root_domain}"]
  zone        = "${var.root_domain}"
}

resource "aws_cloudfront_distribution" "this" {
  aliases = ["*.${local.domain_name}"]

  origin {
    domain_name = "${aws_s3_bucket.this.bucket_regional_domain_name}"
    origin_id   = "${local.name}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  viewer_certificate {
    acm_certificate_arn = "${module.acm_cert.certificate_arn}"
    ssl_support_method  = "sni-only"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = "${
    map(
      "Name", "${local.name} Application frontend",
      "Cluster", "${var.cluster}",
      "Environment", "${var.env}",
      "Application", "${var.app}",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_route53_record" "this" {
  zone_id = "${data.aws_route53_zone.base.zone_id}"
  name    = "*.${local.domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.this.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.this.hosted_zone_id}"
    evaluate_target_health = false
  }
}
