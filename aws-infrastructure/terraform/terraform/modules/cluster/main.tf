terraform {
  backend "s3" {}
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

data "terraform_remote_state" "mgmt_vpc" {
  backend = "s3"

  config {
    region       = "${var.tfstate_region}"
    bucket       = "${var.tfstate_bucket}"
    key          = "resources/mgmt-vpc/terraform.tfstate"
    profile      = "${var.aws_profile}"
    dynodb_table = "${var.tfstate_lock_table}"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    region       = "${var.tfstate_region}"
    bucket       = "${var.tfstate_bucket}"
    key          = "clusters/${var.cluster}/resources/vpc/terraform.tfstate"
    profile      = "${var.aws_profile}"
    dynodb_table = "${var.tfstate_lock_table}"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config {
    region       = "${var.tfstate_region}"
    bucket       = "${var.tfstate_bucket}"
    key          = "clusters/${var.cluster}/resources/eks/terraform.tfstate"
    profile      = "${var.aws_profile}"
    dynodb_table = "${var.tfstate_lock_table}"
  }
}

locals {
  kubeconfig                   = "${data.terraform_remote_state.eks.kubeconfig}"
  kubeconfig_path              = "${data.terraform_remote_state.eks.kubeconfig_path}"
  eks_worker_iam_role_name     = "${data.terraform_remote_state.eks.eks_worker_iam_role_name}"
  eks_worker_iam_role_arn      = "${data.terraform_remote_state.eks.eks_worker_iam_role_arn}"
  eks_worker_security_group_id = "${data.terraform_remote_state.eks.eks_worker_security_group_id}"
  eks_cluster_endpoint         = "${data.terraform_remote_state.eks.cluster_endpoint}"
  eks_cluster_ca_cert          = "${data.terraform_remote_state.eks.cluster_ca_cert}"
  vpc_id                       = "${data.terraform_remote_state.vpc.vpc_id}"
  vpc_cidr_block               = "${data.terraform_remote_state.vpc.vpc_cidr_block}"
  vpc_db_subnet_ids            = "${data.terraform_remote_state.vpc.database_subnet_ids}"
  vpc_db_subnet_group          = "${data.terraform_remote_state.vpc.db_subnet_group_name}"
  vpc_elasticache_subnet_group = "${data.terraform_remote_state.vpc.elasticache_subnet_group_name}"
}

provider "k8s" {
  kubeconfig = "${local.kubeconfig_path}"
}

provider "kubernetes" {
  config_path = "${local.kubeconfig_path}"
}

provider "helm" {
  install_tiller  = true
  namespace       = "kube-system"
  service_account = "tiller"
  tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.10.0"

  automount_service_account_token = true

  override = [
    "spec.template.spec.tolerations[0].key=node-role.kubernetes.io/system",
    "spec.template.spec.tolerations[0].operator=Exists",
    "spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=nodetype",
    "spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=In",
    "spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]=system",
    "spec.template.metadata.annotations.cluster-autoscaler\\.kubernetes\\.io/safe-to-evict=true",
  ]

  kubernetes {
    config_path = "${local.kubeconfig_path}"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_dashboard" {
  name      = "kubernetes-dashboard"
  namespace = "kube-system"
  chart     = "stable/kubernetes-dashboard"
  version   = "1.2.0"

  values = [<<EOF
rbac:
  create: true
serviceAccount:
  create: true
  name: 'kubernetes-dashboard'
fullnameOverride: 'kubernetes-dashboard'
resources:
  limits:
    memory: 300Mi
nodeSelector:
  nodetype: system
tolerations:
- key: node-role.kubernetes.io/system
  operator: Exists
podAnnotations:
  "cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
EOF
  ]
}

resource "k8s_manifest" "coredns_disruption_budget" {
  content = <<EOF
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: coredns-pdb
  namespace: kube-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      eks.amazonaws.com/component: coredns
      k8s-app: kube-dns
EOF

  provisioner "local-exec" {
    command = "kubectl -n kube-system patch deployment/coredns --patch \"$PATCH\""

    environment {
      KUBECONFIG = "${local.kubeconfig_path}"

      PATCH = <<EOF
spec:
  template:
    spec:
      tolerations:
      - key: node-role.kubernetes.io/system
        operator: Exists
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: nodetype
                operator: In
                values: ["system"]
EOF
    }
  }
}

module "cluster_autoscaler" {
  source = "../cluster-autoscaler"

  cluster    = "${var.cluster}"
  aws_region = "${var.aws_region}"

  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"

  kiam_server_role = "${module.kiam.server_role_arn}"
}

module "kiam" {
  source = "../kiam"

  cluster = "${var.cluster}"
}

module "ingress" {
  source = "../ingress-controller"

  vpc_id     = "${local.vpc_id}"
  cluster    = "${var.cluster}"
  aws_region = "${var.aws_region}"

  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"

  kiam_server_role      = "${module.kiam.server_role_arn}"
  worker_iam_role       = "${local.eks_worker_iam_role_name}"
  worker_security_group = "${local.eks_worker_security_group_id}"
}

module "descheduler" {
  source = "../descheduler"
}

module "glidecloud_db" {
  source = "../aurora-cluster"

  vpc_id  = "${local.vpc_id}"
  cluster = "${var.cluster}"
  app     = "glidecloud"

  db_subnet_group         = "${local.vpc_db_subnet_group}"
  allowed_security_groups = ["${local.eks_worker_security_group_id}"]
  allowed_cidr_blocks     = ["${data.terraform_remote_state.mgmt_vpc.vpc_cidr_block}"]
  skip_final_snapshot     = "${var.glidecloud_db_skip_final_snapshot}"
  instance_class          = "${var.glidecloud_db_instance_class}"
}

module "elasticsearch_domain" {
  source = "../elasticsearch-domain"

  vpc_id         = "${local.vpc_id}"
  vpc_cidr_block = "${local.vpc_cidr_block}"
  db_subnet_ids  = "${local.vpc_db_subnet_ids}"

  cluster                 = "${var.cluster}"
  allowed_security_groups = "${local.eks_worker_security_group_id}"

  db_subnet_group     = "${data.terraform_remote_state.mgmt_vpc.vpc_cidr_block}"
  instance_class      = "${var.elasticsearch_instance_class}"
  worker_iam_role_arn = "${local.eks_worker_iam_role_name}"

  aws_tag_hosting_account = "${var.aws_tag_hosting_account}"
  aws_tag_team            = "${var.aws_tag_team}"
  aws_tag_customer        = "${var.aws_tag_customer}"
  aws_tag_cost_center     = "${var.aws_tag_cost_center}"
}

resource "null_resource" "init_glidecloud_db" {
  provisioner "local-exec" {
    command = "psql -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"'"

    environment {
      PGHOST     = "${module.glidecloud_db.host}"
      PGPORT     = "${module.glidecloud_db.port}"
      PGDATABASE = "template1"
      PGUSER     = "${module.glidecloud_db.username}"
      PGPASSWORD = "${module.glidecloud_db.password}"
      PGSSLMODE  = "require"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  namespace = "monitoring"
  chart     = "stable/metrics-server"
  version   = "2.0.4"

  values = [<<EOF
rbac:
  create: true
serviceAccount:
  create: true
  name: metrics-server
args:
  - --logtostderr
  - --kubelet-preferred-address-types=InternalIP
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
resources:
  requests:
    memory: 64Mi
    cpu: 10m
  limits:
    memory: 256Mi
    cpu: 100m
EOF
  ]
}

resource "helm_release" "prometheus" {
  name      = "prometheus"
  namespace = "monitoring"
  chart     = "stable/prometheus"
  version   = "8.1.0"

  # See https://github.com/prometheus/prometheus/blob/release-2.4/documentation/examples/prometheus-kubernetes.yml
  values = [<<EOF
alertmanager:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodetype
            operator: In
            values: ["system"]
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi
  tolerations:
  - key: node-role.kubernetes.io/system
    operator: Exists
kubeStateMetrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodetype
            operator: In
            values: ["system"]
  resources:
    requests:
      cpu: 32m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 256Mi
  tolerations:
  - key: node-role.kubernetes.io/system
    operator: Exists
nodeExporter:
  tolerations:
  - key: node-role.kubernetes.io/system
    operator: Exists
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 50m
      memory: 128Mi
pushgateway:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodetype
            operator: In
            values: ["system"]
  resources:
    requests:
      cpu: 10m
      memory: 16Mi
    limits:
      cpu: 50m
      memory: 128Mi
  tolerations:
  - key: node-role.kubernetes.io/system
    operator: Exists
server:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodetype
            operator: In
            values: ["system"]
  resources:
    requests:
      cpu: 32m
      memory: 256Mi
    limits:
      cpu: 100m
      memory: 1024Mi
  tolerations:
  - key: node-role.kubernetes.io/system
    operator: Exists
serverFiles:
  prometheus.yml:
    remote_write:
      - url: "http://prom-graphite:9201/write"
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets:
            - localhost:9090

      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          # insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https

      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
        - role: node

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics

      - job_name: 'kubernetes-cadvisor'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
        - role: node

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

      - job_name: 'kubernetes-service-endpoints'

        kubernetes_sd_configs:
        - role: endpoints

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name

      - job_name: 'kubernetes-pods'

        kubernetes_sd_configs:
        - role: pod

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
EOF
  ]
}

module "sumologic" {
  source = "../sumologic"

  account       = "${var.account}"
  account_short = "${var.account_short}"
  cluster       = "${var.cluster}"
  cluster_short = "${var.cluster_short}"

  prometheus = "${helm_release.prometheus.metadata.0.revision}"
  namespace  = "${kubernetes_namespace.monitoring.metadata.0.name}"
}
