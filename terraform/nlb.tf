# ============================================
# Network Load Balancer para API Gateway -> EKS
# Permite que o API Gateway acesse os serviços no EKS via VPC Link
# Tráfego: API Gateway → NLB → NGINX Ingress Controller → Services
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

  # Permitir tráfego para NodePort do NGINX Ingress
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort for NGINX Ingress HTTP"
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

# Target Group para NGINX Ingress Controller (NodePort 30080)
resource "aws_lb_target_group" "nginx_ingress" {
  name        = "tech-challenge-nginx-tg"
  port        = 30080  # NodePort do NGINX Ingress
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"  # Targets são os nodes do EKS

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "30080"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  # Criar novo target group antes de deletar o antigo
  # Evita erro "target group is in use by a listener"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "tech-challenge-nginx-tg"
  }
}

# Listener HTTP (porta 80) -> NGINX Ingress (NodePort 30080)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_ingress.arn
  }
}

# Registrar os nodes do EKS como targets
# Isso será feito automaticamente pelo AWS Load Balancer Controller
# ou pode ser feito manualmente com aws_lb_target_group_attachment

# Data source para pegar os nodes do EKS
data "aws_instances" "eks_nodes" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [aws_eks_cluster.main.name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_eks_node_group.main]
}

# Registrar cada node como target (dinâmico)
resource "aws_lb_target_group_attachment" "eks_nodes" {
  count            = length(data.aws_instances.eks_nodes.ids)
  target_group_arn = aws_lb_target_group.nginx_ingress.arn
  target_id        = data.aws_instances.eks_nodes.ids[count.index]
  port             = 30080
}

