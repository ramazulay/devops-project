output "vpc_name" {
  value = var.vpc_name
}
output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "subnets_name" {
  value = [for subnet in var.subnets : subnet.name]
}
output "subnets_id" {
  value = [for subnet in aws_subnet.subnets : subnet.id]
}
output "public_subnet_id" {
  value = [for subnet in aws_subnet.public_subnet : subnet.id]
}