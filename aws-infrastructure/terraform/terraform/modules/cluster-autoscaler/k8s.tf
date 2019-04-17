resource "kubernetes_namespace" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"

    annotations {
      "iam.amazonaws.com/permitted" = "${var.cluster}-cluster-autoscaler-role"
    }
  }
}

resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "${kubernetes_namespace.cluster_autoscaler.metadata.0.name}"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
}

resource "kubernetes_cluster_role" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["events", "endpoints"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups     = [""]
    resources      = ["endpoints"]
    resource_names = ["cluster-autoscaler"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["watch", "list", "get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "replicasets"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["watch", "list", "get"]
  }
}

resource "kubernetes_role" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "${kubernetes_namespace.cluster_autoscaler.metadata.0.name}"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cluster-autoscaler-status"]
    verbs          = ["delete", "get", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "cluster_autoscaler" {
  depends_on = ["kubernetes_service_account.cluster_autoscaler", "kubernetes_cluster_role.cluster_autoscaler"]

  metadata {
    name = "cluster-autoscaler"

    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-autoscaler"
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "${kubernetes_namespace.cluster_autoscaler.metadata.0.name}"
  }
}

resource "kubernetes_role_binding" "cluster_autoscaler" {
  depends_on = ["kubernetes_service_account.cluster_autoscaler", "kubernetes_role.cluster_autoscaler"]

  metadata {
    name      = "cluster-autoscaler"
    namespace = "${kubernetes_namespace.cluster_autoscaler.metadata.0.name}"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cluster-autoscaler"
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "${kubernetes_namespace.cluster_autoscaler.metadata.0.name}"
  }
}

resource "k8s_manifest" "cluster_autoscaler_deployment" {
  depends_on = ["kubernetes_role_binding.cluster_autoscaler", "kubernetes_cluster_role_binding.cluster_autoscaler"]

  content = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: ${kubernetes_namespace.cluster_autoscaler.metadata.0.name}
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
      annotations:
        iam.amazonaws.com/role: ${aws_iam_role.cluster_autoscaler.arn}
    spec:
      serviceAccountName: cluster-autoscaler

      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: nodetype
                operator: In
                values: ["system"]
      tolerations:
      - key: node-role.kubernetes.io/system
        operator: Exists

      containers:
      - image: k8s.gcr.io/cluster-autoscaler:v1.3.6
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi

        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --namespace=${kubernetes_namespace.cluster_autoscaler.metadata.0.name}
        - --node-group-auto-discovery=asg:tag=kubernetes.io/cluster/${var.cluster}

        volumeMounts:
        - name: ${kubernetes_service_account.cluster_autoscaler.default_secret_name}
          mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          readOnly: true
        - name: ssl-certs
          mountPath: /etc/ssl/certs/ca-certificates.crt
          readOnly: true

        imagePullPolicy: "Always"
        env:
        - name: AWS_REGION
          value: ${var.aws_region}

      volumes:
      - name: ${kubernetes_service_account.cluster_autoscaler.default_secret_name}
        secret:
          secretName: ${kubernetes_service_account.cluster_autoscaler.default_secret_name}
      - name: ssl-certs
        hostPath:
          path: "/etc/ssl/certs/ca-bundle.crt"
EOF
}
