# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# EKS Outputs
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_security_group.eks_cluster.id
}

# ECR Outputs
output "ecr_customer_url" {
  description = "ECR repository URL for customer service"
  value       = aws_ecr_repository.customer.repository_url
}

output "ecr_orders_url" {
  description = "ECR repository URL for orders service"
  value       = aws_ecr_repository.orders.repository_url
}

output "ecr_payments_url" {
  description = "ECR repository URL for payments service"
  value       = aws_ecr_repository.payments.repository_url
}

# AWS Account Info
output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}
