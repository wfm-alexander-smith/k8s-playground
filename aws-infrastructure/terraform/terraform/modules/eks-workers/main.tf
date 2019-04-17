data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["encr-amazon-eks-node-*"]
  }

  most_recent = true
  owners      = ["self"]
}

locals {
  worker_userdata = <<EOF
#!/bin/bash -xe
/etc/eks/bootstrap.sh ${var.cluster} \
  --apiserver-endpoint ${var.cluster_endpoint} \
  --b64-cluster-ca ${var.cluster_ca} \
  --kubelet-extra-args '--node-labels nodetype=${var.name} ${var.extra_kubelet_args}'
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
EOF
}

resource "aws_security_group" "worker" {
  name        = "${var.cluster}-${var.name}-eks-worker"
  description = "Security group for ${var.name} nodes in the cluster"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.cluster}-${var.name}-eks-worker",
     "Cluster", "${var.cluster}",
     "kubernetes.io/cluster/${var.cluster}", "owned",
     "Hosting Account", "${var.aws_tag_hosting_account}",
     "Team", "${var.aws_tag_team}",
     "Customer", "${var.aws_tag_customer}",
     "Cost Center", "${var.aws_tag_cost_center}",
    )
  }"
}

resource "aws_launch_configuration" "worker" {
  associate_public_ip_address = false
  iam_instance_profile        = "${var.instance_profile}"
  image_id                    = "${data.aws_ami.eks_worker.id}"
  instance_type               = "${var.worker_type}"
  name_prefix                 = "${var.cluster}-${var.name}-eks-worker"
  security_groups             = ["${concat(list(aws_security_group.worker.id), var.extra_security_groups)}"]
  user_data_base64            = "${base64encode(local.worker_userdata)}"

  root_block_device {
    volume_type = "gp2"
    volume_size = 100
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker" {
  desired_capacity     = "${var.num_workers}"
  launch_configuration = "${aws_launch_configuration.worker.name}"
  max_size             = "${var.max_workers}"
  min_size             = "${var.min_workers}"
  name                 = "${var.cluster}-${var.name}-eks-worker"
  termination_policies = ["OldestLaunchConfiguration", "NewestInstance", "Default"]
  vpc_zone_identifier  = ["${var.private_subnet_ids}"]

  tag {
    key                 = "Name"
    value               = "${var.cluster}-${var.name}-eks-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster"
    value               = "${var.cluster}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster}"
    value               = "owned"
    propagate_at_launch = true
  }
}
