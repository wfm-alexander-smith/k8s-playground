output "server_role_arn" {
  description = "ARN of the Kiam Server role"
  value       = "${aws_iam_role.server_role.arn}"
}
