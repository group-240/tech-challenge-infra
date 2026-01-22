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

# Kubernetes Namespace
output "kubernetes_namespace" {
  description = "Kubernetes namespace for all microservices"
  value       = kubernetes_namespace.tech_challenge.metadata[0].name
}

output "namespace_ready" {
  description = "Flag indicating namespace was created and is ready"
  value       = true
  depends_on  = [kubernetes_namespace.tech_challenge]
}

# AWS Account Info
output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

# NLB Outputs
output "nlb_arn" {
  description = "Network Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "nlb_dns_name" {
  description = "Network Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "nlb_target_group_arn" {
  description = "NLB Target Group ARN for NGINX Ingress"
  value       = aws_lb_target_group.nginx_ingress.arn
}

# ============================================
# CloudWatch Outputs - Observabilidade
# ============================================

output "cloudwatch_dashboard_url" {
  description = "URL do CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=TechChallenge-Dashboard"
}

output "cloudwatch_logs_url" {
  description = "URL do CloudWatch Logs"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
}

output "eks_console_url" {
  description = "URL do EKS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/eks/home?region=${var.aws_region}#/clusters/${var.cluster_name}"
}

output "cloudwatch_log_group_apps" {
  description = "CloudWatch Log Group para aplicações (Container Insights)"
  value       = data.aws_cloudwatch_log_group.container_insights_application.name
}

output "cloudwatch_log_group_eks" {
  description = "CloudWatch Log Group para EKS"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "cloudwatch_log_group_performance" {
  description = "CloudWatch Log Group para métricas de performance"
  value       = data.aws_cloudwatch_log_group.container_insights_performance.name
}
