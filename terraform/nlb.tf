# ============================================
# Network Load Balancer para API Gateway -> EKS
# Permite que o API Gateway acesse os serviços no EKS via VPC Link
# ============================================

# Security Group para o NLB
resource "aws_security_group" "nlb" {
  name        = "tech-challenge-nlb-sg"
  description = "Security group for NLB to EKS communication"
  vpc_id      = aws_vpc.main.id

  # Permitir tráfego HTTP do API Gateway
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from API Gateway"
  }

  # Permitir tráfego HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from API Gateway"
  }

  # Permitir todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tech-challenge-nlb-sg"
  }
}

# Network Load Balancer
resource "aws_lb" "main" {
  name               = "tech-challenge-nlb"
  internal           = true  # NLB interno (API Gateway acessa via VPC Link)
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "tech-challenge-nlb"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Target Group para os serviços do EKS (porta 80)
resource "aws_lb_target_group" "eks_services" {
  name        = "tech-challenge-eks-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = {
    Name = "tech-challenge-eks-tg"
  }
}

# Listener HTTP (porta 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_services.arn
  }
}

# Nota: Os targets (IPs dos pods) serão registrados automaticamente
# pelo AWS Load Balancer Controller no EKS, ou manualmente via Terraform
# se necessário. Para simplificar, o NLB está configurado para receber
# IPs dos serviços Kubernetes.
