locals {
  namespace = "descheduler"

  manifests = [
    "cluster-role",
    "service-account",
    "cluster-role-binding",
    "config-map",
    "cron-job",
  ]
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "${local.namespace}"
  }
}

data "template_file" "manifest" {
  count = "${length(local.manifests)}"

  template = "${file("${path.module}/k8s-manifests/${local.manifests[count.index]}.yaml")}"

  vars {
    namespace = "${kubernetes_namespace.ns.metadata.0.name}"
  }
}

resource "k8s_manifest" "manifest" {
  count = "${length(local.manifests)}"

  content = "${data.template_file.manifest.*.rendered[count.index]}"
}
