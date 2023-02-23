#EKS Required required tagging for EC2
#- k8s.io/cluster-autoscaler/<cluster_name> = owned
#- kubernetes.io/cluster/<cluster_name> = owned 
#- k8s.io/cluster-autoscaler/enabled = true 

#Additional tags
#eks:cluster-name dev-eks-airflow-1-us-east-1
#eks:nodegroup-name 

locals {
  tags = merge(
    { "kubernetes.io/cluster/${var.cluster_name}" = "owned" },
    { "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned" },
    { "k8s.io/cluster-autoscaler/enabled" = "${var.enable_cluster_autoscaler}" },
    { "eks:cluster-name" = "${var.cluster_name}" },
    { "eks:nodegroup-name " = "${var.node_group_name}" },
    { "ec2" = "datadog" },
    var.tags,
  )

  node_pool                  = var.node_group_name
  node_pool_unique_identifer = "${var.cluster_name}-${var.node_group_name}"
  create_role                = var.node_role_arn == null ? true : false
}

#Retrieve aws account number
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "combined_assume_role_policies" {
  source_policy_documents = [
    var.additional_assume_role_policies,
    join("", data.aws_iam_policy_document.assume_role.*.json)
  ]
}

resource "aws_iam_role" "default" {
  name                 = local.node_pool_unique_identifer
  assume_role_policy   = data.aws_iam_policy_document.combined_assume_role_policies.json
  permissions_boundary = coalesce(var.permissions_boundary, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AdminPermissionsBoundary")

  tags = merge(
    {
      compliance-app = ""
    },
    local.tags,
  )
  count = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "amazon_cloud_watch_agent_server_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

#SSM IAM Policies Attachment
resource "aws_iam_role_policy_attachment" "amazon_ssm_managed_instance_core_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "amazon_ssm_patch_association_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "amazon_ssm_policy_forinstance_automation_policy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/EC2SSMPolicyForInstanceAutomationQuickSetup"
  role       = join("", aws_iam_role.default.*.name)
  count      = local.create_role ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "existing_policies_for_eks_workers_role" {
  count      = local.create_role ? var.existing_workers_role_policy_arns_count : 0
  policy_arn = var.existing_workers_role_policy_arns[count.index]
  role       = join("", aws_iam_role.default.*.name)
}

## Need additional work on Security Group and SSH Key creation. 
resource "aws_security_group" "node_group_sg" {
  name   = "cg-sg-${local.node_pool_unique_identifer}-allow"
  vpc_id = var.vpc_id
  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_eks_node_group" "default" {
  cluster_name    = var.cluster_name
  node_group_name = local.node_pool
  node_role_arn   = coalesce(var.node_role_arn, join("", aws_iam_role.default.*.arn))
  subnet_ids      = var.subnet_ids
  ami_type        = var.ami_type
  disk_size       = var.disk_size

  instance_types = var.instance_types

  #Spot or On Demand
  capacity_type = var.capacity_type

  labels          = var.kubernetes_labels
  release_version = var.ami_release_version
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  dynamic "remote_access" {
    for_each = var.node_group_ssh_key != null && var.node_group_ssh_key != "" ? ["true"] : []
    content {
      ec2_ssh_key               = var.node_group_ssh_key
      source_security_group_ids = list(aws_security_group.node_group_sg.id)
    }
  }

  dynamic "taint" {
    #Only available with terraform v1.3
    #for_each = endswith(var.ami_type,"NVIDIA") || endswith(var.ami_type,"GPU") ? [true] : []

    for_each = length(regexall("GPU$|NVIDIA$", var.ami_type)) > 0 ? [true] : []
    content {
      key    = "nvidia.com/gpu"
      effect = "NO_SCHEDULE"
    }
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
    aws_security_group.node_group_sg,
    var.module_depends_on
  ]
}

resource "aws_autoscaling_group_tag" "default" {
  for_each = merge(
    var.tags,
    {
      ec2 = "datadog"
    },
  )
  autoscaling_group_name = flatten(aws_eks_node_group.default.resources)[0].autoscaling_groups[0].name
  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = true
  }
}
