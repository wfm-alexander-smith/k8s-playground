data "aws_ssm_parameter" "sumo_id" {
  name = "/shared/sumologic/access_id"
}

data "aws_ssm_parameter" "sumo_key" {
  name = "/shared/sumologic/access_key"
}

data "aws_ssm_parameter" "sumo_url" {
  name = "/shared/sumologic/collector_url"
}

resource "helm_release" "sumologic_fluentd" {
  name      = "sumologic-fluentd"
  namespace = "${var.namespace}"
  chart     = "stable/sumologic-fluentd"
  version   = "0.6.0"

  values = [<<EOF
rbac:
  create: true
sumologic:
  collectorUrl: ${data.aws_ssm_parameter.sumo_url.value}
persistence:
  enabled: true
  createPath: true
tolerations:
- key: node-role.kubernetes.io/system
  operator: Exists
force_prometheus_dep: ${var.prometheus}
EOF
  ]
}

resource "k8s_manifest" "configmap" {
  content = <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: "sumo-sources"
  namespace: ${var.namespace}
data:
  sources.json: |-
    {
      "api.version": "v1",
      "sources": [
        {
          "name": "KubeMetrics",
          "category": "${var.cluster_short}/kubernetes/aws/${var.cluster_short}/metrics",
          "automaticDateParsing": true,
          "contentType": "Graphite",
          "timeZone": "UTC",
          "encoding": "UTF-8",
          "protocol": "TCP",
          "port": 2003,
          "sourceType": "Graphite"
        }
      ]
    }
EOF
}

resource "k8s_manifest" "secret" {
  content = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sumo-access
  namespace: ${var.namespace}
data:
  id: ${base64encode(data.aws_ssm_parameter.sumo_id.value)}
  key: ${base64encode(data.aws_ssm_parameter.sumo_key.value)}
EOF
}

resource "k8s_manifest" "deployment" {
  content = <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: sumo-graphite
  name: sumo-graphite
  namespace: ${var.namespace}
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: sumo-graphite
    spec:
      volumes:
      - name: sumo-sources
        configMap:
          name: sumo-sources
          items:
          - key: sources.json
            path: sources.json
      containers:
      - name: sumo-graphite
        image: sumologic/collector:latest
        ports:
        - containerPort: 2003
        volumeMounts:
        - mountPath: /sumo
          name: sumo-sources
        env:
        - name: SUMO_ACCESS_ID
          valueFrom:
            secretKeyRef:
              name: sumo-access
              key: id
        - name: SUMO_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: sumo-access
              key: key
        - name: SUMO_SOURCES_JSON
          value: /sumo/sources.json
        resources:
          requests:
            cpu: 32m
            memory: 384Mi
          limits:
            cpu: 100m
            memory: 512Mi

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
EOF
}

resource "k8s_manifest" "service" {
  content = <<EOF
apiVersion: v1
kind: Service
metadata:
  name: sumo-graphite
  namespace: ${var.namespace}
spec:
  ports:
    - port: 2003
  selector:
    app: sumo-graphite
EOF
}

resource "k8s_manifest" "adapter_deployment" {
  content = <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: prom-graphite
  name: prom-graphite
  namespace: ${var.namespace}
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: prom-graphite
    spec:
      containers:
      - name: prom-graphite
        image: suryastef/remote_storage_adapter:latest
        args:
          - -graphite-address=sumo-graphite:2003
          - -log.level=info
        ports:
        - containerPort: 9201
        resources:
          requests:
            cpu: 100m
            memory: 32Mi
          limits:
            cpu: 200m
            memory: 128Mi
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
EOF
}

resource "k8s_manifest" "adapter_service" {
  content = <<EOF
apiVersion: v1
kind: Service
metadata:
  name: prom-graphite
  namespace: ${var.namespace}
spec:
  ports:
    - port: 9201
  selector:
    app: prom-graphite
EOF
}
