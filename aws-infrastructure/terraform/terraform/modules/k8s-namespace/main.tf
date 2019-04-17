locals {
  name = "${var.env}-${var.namespace_suffix}"
}

resource "k8s_manifest" "namespace" {
  content = <<EOF
kind: Namespace
apiVersion: v1
metadata:
  name: ${local.name}
  annotations:
    iam.amazonaws.com/permitted: "${var.cluster}-${var.env}-${var.app}-.*"
EOF
}

resource "k8s_manifest" "rw-role" {
  content = <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rw
  namespace: ${local.name}
rules:
- apiGroups: ['*']
  resources: ['*']
  verbs: ['*']
EOF

  depends_on = ["k8s_manifest.namespace"]
}

resource "k8s_manifest" "rw-rolebinding" {
  content = <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rw
  namespace: ${local.name}
subjects:
- kind: Group
  name: ${local.name}-rw
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: rw
  apiGroup: rbac.authorization.k8s.io
EOF

  depends_on = ["k8s_manifest.namespace"]
}

# Set default resource request and limit for containers that don't have them specified
resource "k8s_manifest" "resource_defaults" {
  content = <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: ${local.name}
spec:
  limits:
  - type: Container
    defaultRequest:
      cpu: "${var.default_request_cpu}"
      memory: "${var.default_request_memory}"
    default:
      cpu: "${var.default_limit_cpu}"
      memory: "${var.default_limit_memory}"
EOF

  depends_on = ["k8s_manifest.namespace"]
}
