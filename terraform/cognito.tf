# ============================================
# AWS Cognito User Pool para autenticação
# Autenticação por CPF (sem senha)
# ============================================

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "tech-challenge-user-pool"

  # Configuração de username - usar CPF como username
  username_attributes      = []
  auto_verified_attributes = []

  # Política de senha (mesmo sendo passwordless, Cognito exige config)
  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  # Schema customizado para CPF
  schema {
    name                     = "cpf"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false

    string_attribute_constraints {
      min_length = 11
      max_length = 11
    }
  }

  # Configuração de verificação
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  # Configuração de conta
  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  # Admin pode criar usuários
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = {
    Name        = "tech-challenge-user-pool"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Cognito User Pool Client (para a aplicação)
resource "aws_cognito_user_pool_client" "main" {
  name         = "tech-challenge-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Fluxos de autenticação permitidos
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Não gerar client secret (para uso com Lambda)
  generate_secret = false

  # Configuração de tokens
  access_token_validity  = 1  # 1 hora
  id_token_validity      = 1  # 1 hora
  refresh_token_validity = 30 # 30 dias

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevenir erros de user existence
  prevent_user_existence_errors = "ENABLED"
}

# Cognito User Pool Domain (para hosted UI - opcional)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "tech-challenge-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Data source para account ID
data "aws_caller_identity" "current" {}
