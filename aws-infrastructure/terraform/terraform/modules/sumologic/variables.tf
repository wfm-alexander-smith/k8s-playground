# Common variables
variable "account" {
  description = "Account to tag resources with"
}

variable "cluster" {
  description = "Cluster to tag resources with"
}

variable "account_short" {
  description = "Shortened account to tag resources with (i.e. dev, prod)"
}

variable "cluster_short" {
  description = "Shortened cluster to tag resources with (i.e. dev, prod)"
}

variable "prometheus" {
  description = "Prometheus chart revision to enforce dependency on prometheus"
}

variable "namespace" {
  description = "Namespace in which resources should be placed"
}
