resource "k8s_manifest" "service_account" {
  content = "${file("${path.module}/k8s-manifests/service-account.yaml")}"
}

resource "k8s_manifest" "cluster_role_binding" {
  content    = "${file("${path.module}/k8s-manifests/cluster-role-binding.yaml")}"
  depends_on = ["k8s_manifest.service_account"]
}

resource "k8s_manifest" "deployment" {
  content    = "${file("${path.module}/k8s-manifests/deployment.yaml")}"
  depends_on = ["k8s_manifest.cluster_role_binding"]
}

resource "k8s_manifest" "service" {
  content    = "${file("${path.module}/k8s-manifests/service.yaml")}"
  depends_on = ["k8s_manifest.deployment"]
}
