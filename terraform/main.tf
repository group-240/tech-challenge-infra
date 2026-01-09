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
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Create namespace for all microservices
resource "kubernetes_namespace" "tech_challenge" {
  metadata {
    name = "tech-challenge"
    labels = {
      name        = "tech-challenge"
      environment = var.environment
    }
  }

  depends_on = [aws_eks_node_group.main]
}
