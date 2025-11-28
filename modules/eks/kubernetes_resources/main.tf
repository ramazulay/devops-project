data "aws_eks_cluster_auth" "eks_auth" {
  name = var.eks_name
}

provider "kubernetes" {
  host                   = var.eks_endpoint
  cluster_ca_certificate = base64decode(var.eks_ca_certificate)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    iopsPerGB  = "3500"
    throughput = "125"
  }

  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = false

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]

    # Prevent destruction during cluster upgrades
    prevent_destroy = false
  }
}

resource "kubernetes_storage_class" "gp3-retain" {
  metadata {
    name = "gp3-retain"
  }
  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    iopsPerGB  = "3500"
    throughput = "125"
  }

  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]

    # Prevent destruction during cluster upgrades
    prevent_destroy = false
  }
}