# ============================================
# NGINX Ingress Controller para EKS
# Roteia tráfego do NLB para os serviços corretos
# ============================================

# Namespace para o Ingress Controller
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

# Service Account para o NGINX Ingress Controller
resource "kubernetes_service_account" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

# ConfigMap para configurações do NGINX
resource "kubernetes_config_map" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }

  data = {
    "use-forwarded-headers" = "true"
    "proxy-body-size"       = "50m"
    "proxy-read-timeout"    = "60"
    "proxy-send-timeout"    = "60"
  }
}

# Deployment do NGINX Ingress Controller
resource "kubernetes_deployment" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "ingress-nginx"
        "app.kubernetes.io/component" = "controller"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "ingress-nginx"
          "app.kubernetes.io/component" = "controller"
        }
      }

      spec {
        service_account_name             = kubernetes_service_account.ingress_nginx.metadata[0].name
        termination_grace_period_seconds = 300

        container {
          name  = "controller"
          image = "registry.k8s.io/ingress-nginx/controller:v1.9.5"

          args = [
            "/nginx-ingress-controller",
            "--publish-service=$(POD_NAMESPACE)/ingress-nginx-controller",
            "--election-id=ingress-controller-leader",
            "--controller-class=k8s.io/ingress-nginx",
            "--ingress-class=nginx",
            "--configmap=$(POD_NAMESPACE)/ingress-nginx-controller"
          ]

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          port {
            name           = "https"
            container_port = 443
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = 10254
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 1
            success_threshold     = 1
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = 10254
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 1
            success_threshold     = 1
            failure_threshold     = 3
          }

          security_context {
            allow_privilege_escalation = true
            run_as_user                = 101
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

# Service do NGINX Ingress Controller (NodePort para NLB)
resource "kubernetes_service" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      # Annotation para que o NLB possa descobrir este serviço
      "service.beta.kubernetes.io/aws-load-balancer-type" = "external"
    }
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
      protocol    = "TCP"
      node_port   = 30080
    }

    port {
      name        = "https"
      port        = 443
      target_port = "https"
      protocol    = "TCP"
      node_port   = 30443
    }
  }
}

# IngressClass para o NGINX
resource "kubernetes_ingress_class" "nginx" {
  metadata {
    name = "nginx"
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    controller = "k8s.io/ingress-nginx"
  }
}

# ============================================
# Ingress para rotear tráfego para os serviços
# ============================================

resource "kubernetes_ingress_v1" "tech_challenge" {
  metadata {
    name      = "tech-challenge-ingress"
    namespace = "tech-challenge"
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/api$1"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    # Regras de roteamento baseadas em path
    rule {
      http {
        # Health check - vai para orders
        path {
          path      = "/api/health"
          path_type = "Prefix"
          backend {
            service {
              name = "orders-service"
              port {
                number = 80
              }
            }
          }
        }

        # Categories - vai para orders
        path {
          path      = "/api/categories"
          path_type = "Prefix"
          backend {
            service {
              name = "orders-service"
              port {
                number = 80
              }
            }
          }
        }

        # Products - vai para orders
        path {
          path      = "/api/products"
          path_type = "Prefix"
          backend {
            service {
              name = "orders-service"
              port {
                number = 80
              }
            }
          }
        }

        # Orders - vai para orders
        path {
          path      = "/api/orders"
          path_type = "Prefix"
          backend {
            service {
              name = "orders-service"
              port {
                number = 80
              }
            }
          }
        }

        # Webhooks - vai para orders
        path {
          path      = "/api/webhooks"
          path_type = "Prefix"
          backend {
            service {
              name = "orders-service"
              port {
                number = 80
              }
            }
          }
        }

        # Customers - vai para customer
        path {
          path      = "/api/customers"
          path_type = "Prefix"
          backend {
            service {
              name = "customer-service"
              port {
                number = 80
              }
            }
          }
        }

        # Payments - vai para payments
        path {
          path      = "/api/payments"
          path_type = "Prefix"
          backend {
            service {
              name = "payments-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.ingress_nginx_controller,
    kubernetes_service.ingress_nginx_controller
  ]
}
