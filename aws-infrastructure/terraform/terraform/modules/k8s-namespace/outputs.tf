output "name" {
  # Using coalesce to force this output to depend on the namespace resource
  value = "${coalesce(local.name, k8s_manifest.namespace.id)}"
}
