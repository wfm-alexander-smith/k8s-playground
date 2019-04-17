# Cert outputs
output "ca_cert" {
  value = "${tls_self_signed_cert.ca.cert_pem}"
}

output "cert" {
  value = "${tls_locally_signed_cert.cert.cert_pem}"
}

output "key" {
  value = "${tls_private_key.priv.private_key_pem}"
}

output "cert_pfx" {
  value     = "${data.external.pfx.result["pfx"]}"
  sensitive = true
}

output "cert_password" {
  value     = "${random_string.pfx_pw.result}"
  sensitive = true
}
