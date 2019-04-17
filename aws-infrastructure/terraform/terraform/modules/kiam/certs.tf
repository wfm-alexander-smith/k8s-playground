resource "tls_private_key" "ca_priv" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = "${tls_private_key.ca_priv.algorithm}"
  private_key_pem   = "${tls_private_key.ca_priv.private_key_pem}"
  is_ca_certificate = true

  subject {
    common_name  = "Kiam CA"
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

resource "tls_private_key" "server" {
  algorithm = "RSA"
}

resource "tls_cert_request" "server" {
  key_algorithm   = "${tls_private_key.server.algorithm}"
  private_key_pem = "${tls_private_key.server.private_key_pem}"

  subject {
    common_name  = "Kiam Server"
    organization = "glidecloud"
  }

  dns_names    = ["kiam-server", "localhost"]
  ip_addresses = ["127.0.0.1", "::1"]
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = "${tls_cert_request.server.cert_request_pem}"
  ca_key_algorithm   = "${tls_self_signed_cert.ca.key_algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_priv.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 2880 # 24 * 30 * 4
  early_renewal_hours   = 721  # 24 * 30

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "agent" {
  algorithm = "RSA"
}

resource "tls_cert_request" "agent" {
  key_algorithm   = "${tls_private_key.agent.algorithm}"
  private_key_pem = "${tls_private_key.agent.private_key_pem}"

  subject {
    common_name  = "Kiam Agent"
    organization = "glidecloud"
  }
}

resource "tls_locally_signed_cert" "agent" {
  cert_request_pem   = "${tls_cert_request.agent.cert_request_pem}"
  ca_key_algorithm   = "${tls_self_signed_cert.ca.key_algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_priv.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 2880 # 24 * 30 * 4
  early_renewal_hours   = 721  # 24 * 30

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
