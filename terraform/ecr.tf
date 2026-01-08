# ECR Repositories for microservices
resource "aws_ecr_repository" "customer" {
  name                 = "tech-challenge-customer"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tech-challenge-customer"
  }
}

resource "aws_ecr_repository" "orders" {
  name                 = "tech-challenge-orders"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tech-challenge-orders"
  }
}

resource "aws_ecr_repository" "payments" {
  name                 = "tech-challenge-payments"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tech-challenge-payments"
  }
}

# Lifecycle policy to keep only last 10 images
resource "aws_ecr_lifecycle_policy" "customer" {
  repository = aws_ecr_repository.customer.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "orders" {
  repository = aws_ecr_repository.orders.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "payments" {
  repository = aws_ecr_repository.payments.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
