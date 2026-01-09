terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
  }

  backend "s3" {
    bucket         = "tech-challenge-tfstate-group240"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true  # S3 native locking (Terraform 1.10+)
    dynamodb_table = "tech-challenge-terraform-locks"  # Fallback for backwards compatibility
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TechChallenge"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# EKS cluster auth for Kubernetes provider
# Usando exec para autenticar via AWS CLI (compatível com CONFIG_MAP auth mode)
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name, "--region", var.aws_region]
  }
}

# ============================================
# Namespace para aplicações
# IMPORTANTE: Este é o ÚNICO lugar que cria o namespace tech-challenge
# Os microserviços (customer, orders, payments) devem usar data source
# ============================================
resource "kubernetes_namespace" "tech_challenge" {
  metadata {
    name = "tech-challenge"
    labels = {
      name        = "tech-challenge"
      environment = var.environment
      managed-by  = "terraform"
      repo        = "tech-challenge-infra"
    }
  }

  # Previne recriação se já existe - Terraform fará import automático
  lifecycle {
    # Não destruir o namespace mesmo se removido do código
    prevent_destroy = false
    # Ignora mudanças em labels/annotations feitas por outros sistemas
    ignore_changes = [
      metadata[0].annotations,
    ]
  }

  depends_on = [aws_eks_node_group.main]
}
