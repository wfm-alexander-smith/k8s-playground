locals {
  bucket_name    = "glidecloud-${var.cluster}-${var.env}-${var.app}${var.name_extra}"
  sns_topic_name = "${var.cluster}-${var.env}-${var.app}${var.topic_name_extra}"
  worker_role    = "${var.worker_iam_role_arn}"
}

resource "aws_s3_bucket" "this" {
  bucket = "${local.bucket_name}"
  acl    = "private"
  region = "${var.aws_region}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${local.bucket_name}",
      "Principal": {
        "AWS": ["${local.worker_role}"]
      }
    },
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${local.bucket_name}/*",
      "Principal": {
        "AWS": ["${local.worker_role}"]
      }
    }
  ]
}
EOF

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  tags = "${
    map(
      "Name", "${local.bucket_name} Application bucket",
      "Cluster", "${var.cluster}",
      "Environment", "${var.env}",
      "Application", "${var.app}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_sns_topic" "topic" {
  count = "${var.enable_sns_notifications}"

  name = "${local.sns_topic_name}"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}

resource "aws_sns_topic_policy" "default" {
  count = "${var.enable_sns_notifications}"

  arn = "${aws_sns_topic.topic.arn}"

  policy = "${data.aws_iam_policy_document.sns-topic-policy.json}"
}

data "aws_iam_policy_document" "sns-topic-policy" {
  count = "${var.enable_sns_notifications}"

  policy_id = "${local.sns_topic_name}"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:Receive",
      "SNS:GetTopicAttributes",
    ]

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["${local.worker_role}"]
    }

    resources = [
      "${aws_sns_topic.topic.arn}",
    ]

    sid = "${local.sns_topic_name}-process"
  }

  statement {
    actions = [
      "SNS:Publish"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    resources = [
      "${aws_sns_topic.topic.arn}",
    ]

    condition {
      test = "ArnLike"
      variable = "aws:SourceArn"
      values = ["${aws_s3_bucket.this.arn}"]
    }

    sid = "${local.sns_topic_name}-s3"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count = "${var.enable_sns_notifications}"

  bucket = "${aws_s3_bucket.this.id}"

  topic {
    topic_arn     = "${aws_sns_topic.topic.0.arn}"
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "content/"
  }
}
