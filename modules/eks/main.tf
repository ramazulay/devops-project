resource "aws_launch_template" "eks_nodes_launch_template" {
  name = "eks-nodes-launch-template"

  block_device_mappings {
    device_name = "/dev/xvda" # Root volume for EKS nodes
    ebs {
      volume_size = 50
      volume_type = "gp3"
      iops        = 3000
      throughput  = 125
      encrypted   = true
    }
  }
}

resource "aws_iam_role" "eks_cluster_iam_role" {
  name        = "${var.cluster_name}-CLUSTER-ROLE"
  description = "IAM role for ${var.cluster_name} EKS cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["eks.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-CLUSTER-ROLE"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_policy_attachments" {
  for_each   = toset(var.policy_arns.eks_cluster)
  role       = aws_iam_role.eks_cluster_iam_role.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_iam_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# IAM role for EBS CSI Driver
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc_provider.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver_role" {
  name               = "${var.cluster_name}-EBS-CSI-DRIVER-ROLE"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-EBS-CSI-DRIVER-ROLE"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

resource "aws_iam_role" "eks_node_group_iam_role" {
  name        = "${var.cluster_name}-NODE-ROLE"
  description = "IAM role for ${var.cluster_name} EKS node groups for the cluster"

  # Update/add the assume role policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com", "ecr.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      },
      {
        # Add OIDC provider for Kubernetes service accounts
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-NODE-ROLE"
    }
  )
}

resource "aws_iam_policy" "eks_secrets_policy" {
  name        = "EKS-SecretsManagerKMSPolicy"
  description = "Custom policy to allow access to resources in Secret Manager and KMS decryption for secrets"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:BatchGetSecretValue",
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:*",
          "arn:aws:kms:*:*:key/*"
        ],
        Condition = {
          "StringEquals" = {
            "aws:ResourceTag/Product" = var.product_name
          }
        }
      }
    ]
  })
}

locals {
  eks_node_group_policies = concat(
    var.policy_arns.eks_node_group,
    [aws_iam_policy.eks_secrets_policy.arn]
  )
}

resource "aws_iam_role_policy_attachment" "eks_node_group_role_policy_attachments" {
  for_each   = { for idx, policy in local.eks_node_group_policies : idx => policy }
  role       = aws_iam_role.eks_node_group_iam_role.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "eks-node" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name}-${var.spot ? "SPOT" : "ON_DEMAND"}-NODES"
  node_role_arn   = aws_iam_role.eks_node_group_iam_role.arn
  version         = var.cluster_version


  scaling_config {
    desired_size = var.desired_capacity
    min_size     = var.min_capacity
    max_size     = var.max_capacity
  }

  subnet_ids     = var.subnet_ids
  instance_types = var.instance_types
  capacity_type  = var.spot ? "SPOT" : "ON_DEMAND"

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-${var.spot ? "SPOT" : "ON_DEMAND"}-NODES"
    }
  )

  labels = {
    type      = var.spot ? "spot" : "ondemand"
    lifecycle = var.spot ? "spot" : "ondemand"
  }

  launch_template {
    id      = aws_launch_template.eks_nodes_launch_template.id
    version = aws_launch_template.eks_nodes_launch_template.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_role_policy_attachments
  ]
}

# Addons for EKS Cluster
resource "aws_eks_addon" "eks-addons" {
  for_each      = { for idx, addon in var.addons : idx => addon }
  cluster_name  = aws_eks_cluster.eks.name
  addon_name    = each.value.name
  addon_version = each.value.version

  # Use EBS CSI driver role for EBS addon, node role for others if attach=true
  service_account_role_arn = each.value.name == "aws-ebs-csi-driver" ? aws_iam_role.ebs_csi_driver_role.arn : (each.value.attach ? aws_iam_role.eks_node_group_iam_role.arn : null)

  depends_on = [
    aws_eks_node_group.eks-node,
    aws_iam_role_policy_attachment.ebs_csi_driver_policy
  ]
}

module "kubernetes_resources" {
  source = "./kubernetes_resources"

  eks_name           = aws_eks_cluster.eks.name
  eks_endpoint       = aws_eks_cluster.eks.endpoint
  eks_ca_certificate = aws_eks_cluster.eks.certificate_authority[0].data
}
