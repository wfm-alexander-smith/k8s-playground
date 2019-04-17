output "tiller_svc_id" {
  value = "${k8s_manifest.service.id}"
}
