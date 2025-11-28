output "environment" {
  description = "The environment"
  value       = var.environment
}

output "region" {
  description = "The region"
  value       = var.region
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = module.vpc.vpc_name
}

output "security_group_name" {
  description = "The name of the security group"
  value       = module.asg.security_group_name
}

# output "iam_role_name" {
#   description = "The name of the IAM role"
#   value       = module.iam_role.role_name
# }

output "eks_cluster_id" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_id
}

output "ecr_registry_uri" {
  description = "The URI of the ECR registry"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "sqs_queue_url" {
  description = "The URL of the SQS queue"
  value       = var.sqs_queue_name != null ? module.sqs[0].queue_url : null
}

output "sqs_queue_arn" {
  description = "The ARN of the SQS queue"
  value       = var.sqs_queue_name != null ? module.sqs[0].queue_arn : null
}

output "sqs_dlq_url" {
  description = "The URL of the SQS Dead Letter Queue"
  value       = var.sqs_queue_name != null && var.sqs_create_dlq ? module.sqs[0].dlq_id : null
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = var.s3_bucket_name != null ? module.s3[0].bucket_name : null
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = var.s3_bucket_name != null ? module.s3[0].bucket_arn : null
}

output "s3_bucket_domain_name" {
  description = "The domain name of the S3 bucket"
  value       = var.s3_bucket_name != null ? module.s3[0].bucket_domain_name : null
}