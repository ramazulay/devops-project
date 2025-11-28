output "queue_id" {
  description = "The URL for the created Amazon SQS queue"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "The ARN of the SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "The name of the SQS queue"
  value       = aws_sqs_queue.main.name
}

output "queue_url" {
  description = "The URL of the SQS queue"
  value       = aws_sqs_queue.main.url
}

output "dlq_id" {
  description = "The URL for the created Dead Letter Queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "The ARN of the Dead Letter Queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_name" {
  description = "The name of the Dead Letter Queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].name : null
}
