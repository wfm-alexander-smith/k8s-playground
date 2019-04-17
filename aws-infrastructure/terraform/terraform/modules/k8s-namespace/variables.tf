variable "cluster" {
  description = "Cluster name"
}

variable "env" {
  description = "Environment name"
}

variable "app" {
  description = "App name"
}

variable "namespace_suffix" {
  description = "Namespace to create (will be used like {ENV}-{namespace_suffix})"
}

# These defaults can be overridden by specifying resource requests/limits on the container spec.
variable "default_request_cpu" {
  description = "Default amount of CPU to request for containers in this namespace."
  default     = "50m"
}

variable "default_request_memory" {
  description = "Default amount of memory to request for containers in this namespace."
  default     = "384Mi"
}

variable "default_limit_cpu" {
  description = "Default amount of CPU to limit containers to in this namespace."
  default     = "250m"
}

variable "default_limit_memory" {
  description = "Default amount of memory to limit containers to in this namespace."
  default     = "512Mi"
}
