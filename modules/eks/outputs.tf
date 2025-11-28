output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.eks.id
}

output "cluster_arn" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks.arn
}

output "cluster_version" {
  description = "The version of the EKS cluster"
  value       = aws_eks_cluster.eks.platform_version
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.eks.endpoint
}
