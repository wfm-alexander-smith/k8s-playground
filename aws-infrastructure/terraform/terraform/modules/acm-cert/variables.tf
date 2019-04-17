variable "cluster" {
  description = "Cluster name"
}

variable "env" {
  description = "Environment name"
}

variable "app" {
  description = "App name"
}

variable "domain" {
  description = "Domain name to generate cert for (can be a wildcard)"
}

variable "san_domains" {
  description = "Optional Subject Alternative Name domains for the cert"
  default     = []
}

variable "zone" {
  description = "Route53 Hosted zone to use for DNS validation of certificate"
}
