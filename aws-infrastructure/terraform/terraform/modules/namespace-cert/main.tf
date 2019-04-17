resource "tls_private_key" "ca_priv" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = "${tls_private_key.ca_priv.algorithm}"
  private_key_pem   = "${tls_private_key.ca_priv.private_key_pem}"
  is_ca_certificate = true

  subject {
    common_name  = "cluster.local"
    organization = "glidecloud"
  }

  validity_period_hours = 5760 # 24 * 30 * 8
  early_renewal_hours   = 2880 # 24 * 30 * 4

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "data_encipherment",
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "priv" {
  algorithm = "RSA"
}

locals {
  cn = "${coalesce(var.override_cn, "*.${var.namespace}.svc.cluster.local")}"
}

resource "tls_cert_request" "req" {
  key_algorithm   = "${tls_private_key.priv.algorithm}"
  private_key_pem = "${tls_private_key.priv.private_key_pem}"

  subject {
    common_name  = "${local.cn}"
    organization = "glidecloud"
  }

  dns_names = ["${concat(list("${local.cn}"), var.extra_dns_names)}"]
}

resource "tls_locally_signed_cert" "cert" {
  cert_request_pem   = "${tls_cert_request.req.cert_request_pem}"
  ca_key_algorithm   = "${tls_self_signed_cert.ca.key_algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_priv.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 2880 # 24 * 30 * 4
  early_renewal_hours   = 721  # 24 * 30

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "random_string" "pfx_pw" {
  length = 32
}

data "external" "pfx" {
  program = ["bash", "${path.module}/scripts/make_pfx.sh"]

  query {
    cert = <<EOF
${tls_locally_signed_cert.cert.cert_pem}
${tls_self_signed_cert.ca.cert_pem}
EOF

    key      = "${tls_private_key.priv.private_key_pem}"
    password = "${random_string.pfx_pw.result}"
  }
}
