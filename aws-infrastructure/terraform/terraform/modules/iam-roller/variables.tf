variable "namespace" {
  description = "Namespace into which iam-roller and generated secrets will be placed"
}

variable "roller_role_arn" {
  description = "ARN of the iam-roller role to be assigned to the pod"
}

variable "assume_role_arn" {
  description = "ARN of the role to be assumed"
}
