# ============================================
# CloudWatch - Observabilidade e Logs
# ============================================

# Log Group para logs do EKS Control Plane
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7  # Learner Lab: manter baixo para economizar

  tags = {
    Name        = "tech-challenge-eks-logs"
    Environment = var.environment
  }
}

# ============================================
# Container Insights Log Groups
# NOTA: Criados automaticamente pelo addon amazon-cloudwatch-observability
# Não precisam ser referenciados no Terraform - existem quando os pods iniciam
# ============================================

# ============================================
# CloudWatch Dashboard - Visão Unificada
# ============================================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "TechChallenge-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Header
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# 🎯 Tech Challenge - Dashboard de Monitoramento\n**Cluster:** ${var.cluster_name} | **Região:** ${var.aws_region}"
        }
      },

      # Status dos Recursos
      {
        type   = "text"
        x      = 0
        y      = 1
        width  = 8
        height = 2
        properties = {
          markdown = "## 📊 Status Geral\nPara verificar o status atual, use:\n```\naws eks describe-cluster --name ${var.cluster_name}\n```"
        }
      },

      # EKS Cluster CPU
      {
        type   = "metric"
        x      = 0
        y      = 3
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name, { stat = "Average", period = 300 }]
          ]
          title  = "🖥️ CPU dos Nodes (%)"
          region = var.aws_region
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # EKS Cluster Memory
      {
        type   = "metric"
        x      = 12
        y      = 3
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "node_memory_utilization", "ClusterName", var.cluster_name, { stat = "Average", period = 300 }]
          ]
          title  = "🧠 Memória dos Nodes (%)"
          region = var.aws_region
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # Pods Running
      {
        type   = "metric"
        x      = 0
        y      = 9
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "pod_number_of_running_containers", "ClusterName", var.cluster_name, { stat = "Sum", period = 60 }]
          ]
          title  = "🐳 Containers Rodando"
          region = var.aws_region
          view   = "singleValue"
        }
      },

      # Pod CPU por Namespace
      {
        type   = "metric"
        x      = 8
        y      = 9
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "ClusterName", var.cluster_name, "Namespace", "tech-challenge", { stat = "Average", period = 300 }]
          ]
          title  = "⚡ CPU Pods tech-challenge"
          region = var.aws_region
          view   = "timeSeries"
        }
      },

      # Pod Memory por Namespace
      {
        type   = "metric"
        x      = 16
        y      = 9
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "pod_memory_utilization", "ClusterName", var.cluster_name, "Namespace", "tech-challenge", { stat = "Average", period = 300 }]
          ]
          title  = "💾 Memória Pods tech-challenge"
          region = var.aws_region
          view   = "timeSeries"
        }
      },

      # Logs recentes - Aplicações
      {
        type   = "log"
        x      = 0
        y      = 15
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '/aws/containerinsights/${var.cluster_name}/application' | fields @timestamp, @message, kubernetes.container_name | filter kubernetes.namespace_name = 'tech-challenge' | sort @timestamp desc | limit 50"
          region = var.aws_region
          title  = "📋 Logs Recentes das Aplicações"
        }
      },

      # Network
      {
        type   = "metric"
        x      = 0
        y      = 21
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "node_network_total_bytes", "ClusterName", var.cluster_name, { stat = "Sum", period = 300 }]
          ]
          title  = "🌐 Tráfego de Rede (bytes)"
          region = var.aws_region
          view   = "timeSeries"
        }
      },

      # Disk
      {
        type   = "metric"
        x      = 12
        y      = 21
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "node_filesystem_utilization", "ClusterName", var.cluster_name, { stat = "Average", period = 300 }]
          ]
          title  = "💿 Uso de Disco (%)"
          region = var.aws_region
          view   = "timeSeries"
        }
      }
    ]
  })
}

# ============================================
# CloudWatch Alarms - Alertas Importantes
# ============================================

# Alarm: CPU alta nos nodes
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "tech-challenge-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU dos nodes acima de 80%"

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name = "tech-challenge-cpu-alarm"
  }
}

# Alarm: Memória alta nos nodes
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "tech-challenge-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Memória dos nodes acima de 85%"

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name = "tech-challenge-memory-alarm"
  }
}
