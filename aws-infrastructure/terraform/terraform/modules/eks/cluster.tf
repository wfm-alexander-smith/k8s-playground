resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster}-eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = "${
  map(
    "Name", "${var.cluster}-eks-cluster-role",
    "Cluster", "${var.cluster}",
    "kubernetes.io/cluster/${var.cluster}", "shared",
    "Hosting Account", "${var.aws_tag_hosting_account}",
    "Team", "${var.aws_tag_team}",
    "Customer", "${var.aws_tag_customer}",
    "Cost Center", "${var.aws_tag_cost_center}",
  )
}"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster}-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${local.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
      "Name", "${var.cluster}-eks-cluster",
      "Cluster", "${var.cluster}",
      "kubernetes.io/cluster/${var.cluster}", "shared",
      "Hosting Account", "${var.aws_tag_hosting_account}",
      "Team", "${var.aws_tag_team}",
      "Customer", "${var.aws_tag_customer}",
      "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_security_group_rule" "cluster_ingress_worker_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_cluster.id}"
  source_security_group_id = "${aws_security_group.eks_worker.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_eks_cluster" "cluster" {
  name     = "${var.cluster}"
  role_arn = "${aws_iam_role.eks_cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks_cluster.id}"]
    subnet_ids         = ["${local.public_subnet_ids}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy",
  ]
}
