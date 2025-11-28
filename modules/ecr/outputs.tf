output "repository_url" {
  description = "URL of the created ECR repository"
  value       = aws_ecr_repository.ecr.repository_url
}

output "repository_arn" {
  description = "ARN of the created ECR repository"
  value       = aws_ecr_repository.ecr.arn
}

output "repository_name" {
  description = "Name of the created ECR repository"
  value       = aws_ecr_repository.ecr.name
}