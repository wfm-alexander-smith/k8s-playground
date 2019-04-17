locals {
  manifests = [
    "role",
    "service-account",
    "role-binding",
    "cron-job",
  ]
}

data "template_file" "manifest" {
  count = "${length(local.manifests)}"

  template = "${file("${path.module}/k8s-manifests/${local.manifests[count.index]}.yaml")}"

  vars {
    namespace       = "${var.namespace}"
    assume_role_arn = "${var.assume_role_arn}"
    roller_role_arn = "${var.roller_role_arn}"
  }
}

resource "k8s_manifest" "manifest" {
  count = "${length(local.manifests)}"

  content = "${data.template_file.manifest.*.rendered[count.index]}"
}
