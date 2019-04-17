output "name" {
  value = "${aws_s3_bucket.this.id}"
}

output "arn" {
  value = "${aws_s3_bucket.this.arn}"
}

output "sns_topic_arn" {
  value = "${ join("", aws_sns_topic.topic.*.arn) }"
}

output "sns_topic_name" {
  value = "${ join("", aws_sns_topic.topic.*.name) }"
}
