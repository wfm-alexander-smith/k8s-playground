locals {
  db_url    = "postgresql://${var.db_user}:${urlencode(var.db_pass)}@${var.db_host}/${var.db_name}?sslmode=require"
  rails_env = "production"
}

resource "k8s_manifest" "configmap" {
  content = <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: "${var.configmap_name}"
  namespace: "${var.namespace}"
data:
  s3Bucket: "${var.bucket_name}"
  databaseHost: "${var.db_host}"
  databaseName: "${var.db_name}"
  databaseUser: "${var.db_user}"
  databasePassword: "${var.db_pass}"
  databasePort: "${var.db_port}"
  databaseUrl: "${local.db_url}"
  dbCleanerAllowRemoteDbUrl: "true"
  environment: "${local.rails_env}"
  redisUrl: "rediss://:${var.redis_auth}@${var.redis_host}:${var.redis_port}/0"
  certArn: "${var.cert_arn}"
EOF
}
