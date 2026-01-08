terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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
