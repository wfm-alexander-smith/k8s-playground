resource "aws_iam_role" "worker" {
  name = "${var.cluster}-${var.name}-eks-worker-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${
  map(
   "Name", "${var.cluster}-${var.name}-eks-worker",
   "Cluster", "${var.cluster}",
   "kubernetes.io/cluster/${var.cluster}", "shared",
   "Hosting Account", "${var.aws_tag_hosting_account}",
   "Team", "${var.aws_tag_team}",
   "Customer", "${var.aws_tag_customer}",
   "Cost Center", "${var.aws_tag_cost_center}",
  )
}"
}

resource "aws_iam_role_policy" "worker" {
  name = "${var.cluster}-${var.name}-eks-worker"
  role = "${aws_iam_role.worker.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
${join(",", var.extra_policy_statements)}
  ]
}
EOF
}

# Provides permissions needed for worker nodes to find and attach to the
# cluster (see aws-auth.tf for the other thing needed to allow them to
# connect).
resource "aws_iam_role_policy_attachment" "eks_worker" {
  role       = "${aws_iam_role.worker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Provides permissions needed for workers to use the VPC networking (each pod
# gets an IP in the VPCs subnets).
resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = "${aws_iam_role.worker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Provides permissions for workers to access ECR to pull container images.
resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = "${aws_iam_role.worker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster}-${var.name}-eks-worker"
  role = "${aws_iam_role.worker.name}"
}
