output "instance_profile" {
  value = "${aws_iam_instance_profile.worker.name}"
}

output "iam_role_name" {
  description = "Name of the IAM role for the EKS worker nodes, for adding extra policies to the role."
  value       = "${aws_iam_role.worker.name}"
}

output "iam_role_arn" {
  description = "ARN of the IAM role for the EKS worker nodes, for referencing in policies."
  value       = "${aws_iam_role.worker.arn}"
}
