# ============================================
# EKS para AWS Academy Learner Lab
# Usa roles pré-existentes (LabRole)
# ============================================

# Data source para LabRole pré-existente do Learner Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "tech-challenge-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tech-challenge-eks-cluster-sg"
  }
}

# EKS Cluster - Usando LabRole do Learner Lab
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab_role.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }
}

# EKS Node Group - Usando LabRole e limitado a 2 nodes
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "tech-challenge-node-group"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = aws_subnet.private[*].id

  # Learner Lab: Apenas t3.small, t3.medium, t3.large permitidos
  instance_types = ["t3.small"]

  # Learner Lab: Limite de 9 instâncias EC2 no total
  # Mantendo 2 nodes para não exceder limites
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    environment = "tech-challenge"
  }

  tags = {
    Name = "tech-challenge-node-group"
  }
}
