variable "namespace" {
  description = "Kubernetes namespace to make a wildcard service cert for."
}

variable "extra_dns_names" {
  default = []
}

variable "override_cn" {
  default = ""
}
