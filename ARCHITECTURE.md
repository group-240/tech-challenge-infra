# Arquitetura Tech Challenge - Fase 4

## ✅ ARQUITETURA FINAL COM NGINX INGRESS CONTROLLER

### Fluxo de Tráfego

```
Internet
    ↓
┌─────────────────────────────────────────┐
│         API GATEWAY (REST)              │
│   - Lambda Validator (CPF format)      │
│   - Rate Limiting                      │
└─────────────────┬───────────────────────┘
                  │ VPC Link
                  ↓
┌─────────────────────────────────────────┐
│              NLB (porta 80)             │
│   - Internal Load Balancer             │
│   - Target: NodePort 30080             │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│     NGINX INGRESS CONTROLLER           │
│   - NodePort: 30080                    │
│   - Roteamento baseado em path         │
│   - 2 réplicas (HA)                    │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┼─────────┐
        ↓         ↓         ↓
┌───────────┐ ┌───────────┐ ┌───────────┐
│/customers │ │ /orders   │ │ /payments │
│/health    │ │/products  │ │           │
│           │ │/categories│ │           │
│           │ │/webhooks  │ │           │
└─────┬─────┘ └─────┬─────┘ └─────┬─────┘
      ↓             ↓             ↓
┌───────────┐ ┌───────────┐ ┌───────────┐
│ customer- │ │  orders-  │ │ payments- │
│  service  │ │  service  │ │  service  │
│ ClusterIP │ │ ClusterIP │ │ ClusterIP │
└───────────┘ └───────────┘ └───────────┘
```

### Por que NGINX Ingress Controller?

| Critério | NGINX Ingress | ALB Controller | API Gateway Direto |
|----------|---------------|----------------|-------------------|
| **Custo** | ✅ Só compute (~$5/mês) | ⚠️ ALB + compute (~$20/mês) | ❌ $3.50/milhão req |
| **Flexibilidade** | ✅ Alta (rewrites, headers) | ⚠️ Média | ⚠️ Baixa |
| **AWS Academy** | ✅ Funciona | ✅ Funciona | ✅ Funciona |
| **Padrão mercado** | ✅ Sim (70%+ do mercado) | ✅ Sim | ⚠️ Não p/ K8s |
| **Gateway API** | ✅ Suporta | ⚠️ Parcial | ❌ Não |

---

## ⚠️ PROBLEMAS IDENTIFICADOS E CORRIGIDOS

### ✅ RESOLVIDO: Falta de Ingress Controller

**Problema Original**: O NLB tinha um único Target Group, mas existiam 3 serviços como `ClusterIP`. O NLB não sabia rotear baseado em path.

**Solução Implementada**: 
- Criado `ingress.tf` com NGINX Ingress Controller
- NLB agora aponta para NodePort 30080 (NGINX)
- NGINX roteia para os serviços corretos baseado em path

### 🟡 INCONSISTÊNCIAS DE PATH (API Gateway vs Serviços) - ✅ CORRIGIDAS

| API Gateway Path | Serviço | Path Real | Status |
|-----------------|---------|-----------|--------|
| `/health` | orders | `/health` | ✅ OK |
| `/categories` | orders | `/categories` | ✅ OK |
| `/products` | orders | `/products` | ✅ OK |
| `/orders` | orders | `/orders` | ✅ OK |
| `/webhooks` | orders | `/webhooks` | ✅ CORRIGIDO |
| `/customers` | customer | `/customers` | ✅ OK |
| `/payments` | payments | `/payments` | ✅ CORRIGIDO |

**Correções Aplicadas**:
1. ✅ `PaymentRestController.java` alterado de `/payment` para `/payments`
2. ✅ `WebhookRestController.java` alterado de `/webhook` para `/webhooks`
3. ✅ Testes atualizados para usar os novos paths

---

## Diagrama de Comunicação Detalhado

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                              │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                           API GATEWAY (REST)                                       │
│                    ┌───────────────────────────────┐                              │
│                    │   tech-challenge-api          │                              │
│                    │   /customers, /orders,        │                              │
│                    │   /payments, /products,       │                              │
│                    │   /categories, /health        │                              │
│                    └───────────────────────────────┘                              │
│                              │                                                     │
│                    ┌─────────┴─────────┐                                          │
│                    │                   │                                          │
│                    ▼                   ▼                                          │
│           ┌───────────────┐   ┌───────────────┐                                   │
│           │    COGNITO    │   │    LAMBDA     │                                   │
│           │  User Pool    │   │  CPF Auth     │                                   │
│           │  Authorizer   │   │  Function     │                                   │
│           └───────────────┘   └───────────────┘                                   │
│                                                                                    │
│  📦 Repositório: tech-challenge-gateway                                           │
│  📁 State: gateway/terraform.tfstate                                              │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                    │ VPC Link
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                     NETWORK LOAD BALANCER (NLB)                                   │
│                    ┌───────────────────────────────┐                              │
│                    │   tech-challenge-nlb          │                              │
│                    │   Port 80 → NodePort 30080    │                              │
│                    └───────────────────────────────┘                              │
│                                                                                    │
│  📦 Repositório: tech-challenge-infra                                             │
│  📁 State: infra/terraform.tfstate                                                │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                       NGINX INGRESS CONTROLLER                                    │
│                    ┌───────────────────────────────┐                              │
│                    │   ingress-nginx-controller    │                              │
│                    │   NodePort: 30080             │                              │
│                    │   Réplicas: 2 (HA)            │                              │
│                    └───────────────────────────────┘                              │
│                              │                                                     │
│               ┌──────────────┼──────────────┐                                     │
│               │              │              │                                     │
│               ▼              ▼              ▼                                     │
│     /customers,/health   /orders,etc    /payments                                 │
│  📦 Repositório: tech-challenge-infra (ingress.tf)                               │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              EKS CLUSTER                                          │
│                        Namespace: tech-challenge                                  │
│                                                                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                   │
│  │    CUSTOMER     │  │     ORDERS      │  │    PAYMENTS     │                   │
│  │    Service      │  │    Service      │  │    Service      │                   │
│  │  (ClusterIP)    │  │  (ClusterIP)    │  │  (ClusterIP)    │                   │
│  │   Port 80       │  │   Port 80       │  │   Port 80       │                   │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘                   │
│           │                    │                    │                             │
│           ▼                    ▼                    ▼                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                   │
│  │    customer     │  │     orders      │  │    payments     │                   │
│  │   Deployment    │  │   Deployment    │  │   Deployment    │                   │
│  │   (1 replica)   │  │   (1 replica)   │  │   (1 replica)   │                   │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                   │
│                                                                                    │
│  📦 Repositórios: tech-challenge-customer, tech-challenge-orders,                │
│                   tech-challenge-payments                                         │
│  📁 States: customer/terraform.tfstate, orders/terraform.tfstate,                │
│            payments/terraform.tfstate                                             │
└───────────┬───────────────────────────────────────────┬──────────────────────────┘
            │                                           │
            ▼                                           ▼
┌───────────────────────────────┐     ┌───────────────────────────────────────────┐
│        RDS POSTGRESQL         │     │              DYNAMODB                      │
│  ┌─────────────────────────┐  │     │  ┌─────────────────────────────────────┐  │
│  │   tech-challenge-db     │  │     │  │         Tables                      │  │
│  │   PostgreSQL 18         │  │     │  │   - tech-challenge-orders           │  │
│  │   db.t3.micro           │  │     │  │   - tech-challenge-payments         │  │
│  └─────────────────────────┘  │     │  └─────────────────────────────────────┘  │
│                               │     │                                            │
│  📦 Repositório:              │     │  📦 Repositório:                          │
│     tech-challenge-rds        │     │     tech-challenge-dynamoDB               │
│  📁 State:                    │     │  📁 State:                                │
│     rds/terraform.tfstate     │     │     dynamodb/terraform.tfstate            │
└───────────────────────────────┘     └───────────────────────────────────────────┘
```

---

## Matriz de Responsabilidade

| Repositório | Recursos AWS | State File | Dependências |
|-------------|--------------|------------|--------------|
| **tech-challenge-infra** | VPC, Subnets, EKS, ECR, Cognito, NLB | `infra/terraform.tfstate` | Nenhuma (base) |
| **tech-challenge-rds** | RDS PostgreSQL, DB Subnet Group, Security Groups | `rds/terraform.tfstate` | infra (VPC, Subnets) |
| **tech-challenge-dynamoDB** | DynamoDB Tables | `dynamodb/terraform.tfstate` | Nenhuma |
| **tech-challenge-gateway** | API Gateway, Lambda, VPC Link | `gateway/terraform.tfstate` | infra (Cognito, NLB) |
| **tech-challenge-customer** | K8s Deployment, Service | `customer/terraform.tfstate` | infra (EKS, ECR), dynamoDB |
| **tech-challenge-orders** | K8s Deployment, Service, Secret | `orders/terraform.tfstate` | infra (EKS, ECR), rds |
| **tech-challenge-payments** | K8s Deployment, Service, Secret | `payments/terraform.tfstate` | infra (EKS, ECR), dynamoDB |

---

## Ordem de Deploy

```
1. tech-challenge-infra     → VPC, EKS, ECR, Cognito, NLB (BASE)
       │
       ├── 2. tech-challenge-rds       → PostgreSQL Database
       │
       ├── 3. tech-challenge-dynamoDB  → DynamoDB Tables
       │
       └── 4. tech-challenge-gateway   → API Gateway, Lambda
              │
              ├── 5. tech-challenge-customer  → Build Docker + Deploy K8s
              │
              ├── 6. tech-challenge-orders    → Build Docker + Deploy K8s
              │
              └── 7. tech-challenge-payments  → Build Docker + Deploy K8s
```

## Ordem de Destroy (REVERSA - OBRIGATÓRIA)

```
1. tech-challenge-payments  → Remove K8s resources
2. tech-challenge-orders    → Remove K8s resources
3. tech-challenge-customer  → Remove K8s resources
4. tech-challenge-gateway   → Remove API Gateway, Lambda
5. tech-challenge-dynamoDB  → Remove DynamoDB Tables
6. tech-challenge-rds       → Remove PostgreSQL
7. tech-challenge-infra     → Remove VPC, EKS, ECR, Cognito, NLB (ÚLTIMO!)
```

⚠️ **IMPORTANTE**: Se destruir o `infra` antes dos outros, os recursos dos outros repos ficarão órfãos!

---

## Como Testar Após Deploy

### 1. Obter URL da API Gateway

```bash
# Via AWS CLI
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='tech-challenge-api'].id" \
  --output text)

API_URL="https://${API_ID}.execute-api.us-east-1.amazonaws.com/dev"
echo "API URL: $API_URL"
```

### 2. Health Check (Público)

```bash
curl $API_URL/health
# Esperado: {"status": "UP"}
```

### 3. Listar Produtos (Público)

```bash
curl $API_URL/products
# Esperado: Lista de produtos
```

### 4. Autenticação via Cognito

```bash
# Obter Client ID do Cognito
CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
  --user-pool-id {user-pool-id} \
  --query "UserPoolClients[0].ClientId" \
  --output text)

# Criar usuário (se ainda não existir)
aws cognito-idp sign-up \
  --client-id $CLIENT_ID \
  --username email@example.com \
  --password "SenhaSegura123!"

# Confirmar usuário (admin)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id {user-pool-id} \
  --username email@example.com

# Obter token
TOKEN=$(aws cognito-idp initiate-auth \
  --client-id $CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=email@example.com,PASSWORD="SenhaSegura123!" \
  --query "AuthenticationResult.IdToken" \
  --output text)

# Usar token em chamadas protegidas
curl -H "Authorization: Bearer $TOKEN" $API_URL/orders
```

### 5. Autenticação via CPF (Lambda Authorizer)

```bash
# Para endpoints que usam Lambda authorizer
curl -H "x-cpf: 12345678901" $API_URL/customers/identify
```

### 6. Verificar Status no EKS

```bash
# Configurar kubectl
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1

# Ver todos os recursos
kubectl get all -n tech-challenge

# Ver pods
kubectl get pods -n tech-challenge

# Ver serviços
kubectl get svc -n tech-challenge

# Ver logs de um pod
kubectl logs -n tech-challenge deployment/orders-deployment --tail=100

# Descrever um pod com problemas
kubectl describe pod -n tech-challenge {pod-name}
```

### 7. Testar NLB

```bash
# Ver NLB
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'tech-challenge')]"

# Ver Target Groups
aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName, 'tech-challenge')]"

# Ver health dos targets
TG_ARN=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName, 'tech-challenge')].TargetGroupArn" \
  --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

---

## Troubleshooting

### ❌ API Gateway retorna 401 Unauthorized
- Verificar se o token Cognito é válido e não expirou
- Verificar se o header está correto: `Authorization: Bearer {token}`
- Verificar se o Authorizer está apontando para o User Pool correto

### ❌ API Gateway retorna 502 Bad Gateway
- NLB não consegue alcançar os pods no EKS
- Verificar se os pods estão Running: `kubectl get pods -n tech-challenge`
- Verificar Target Group health (targets devem estar healthy)
- Verificar Security Groups permitem tráfego

### ❌ API Gateway retorna 504 Gateway Timeout
- Timeout entre API Gateway e NLB
- Verificar se o VPC Link está configurado corretamente
- Verificar se o NLB Listener está na porta correta

### ❌ Pods em CrashLoopBackOff
- Verificar logs: `kubectl logs -n tech-challenge {pod-name} --previous`
- Verificar se secrets existem: `kubectl get secrets -n tech-challenge`
- Verificar conexão com RDS (database URL correta?)
- Verificar conexão com DynamoDB

### ❌ Pods em Pending
- Verificar se há nodes suficientes: `kubectl get nodes`
- Verificar resource requests vs limits
- Verificar events: `kubectl describe pod -n tech-challenge {pod-name}`

### ❌ Terraform state locked
- Verificar DynamoDB table: `tech-challenge-tfstate-lock`
- Ver locks ativos: `aws dynamodb scan --table-name tech-challenge-tfstate-lock`
- Remover lock se necessário: `terraform force-unlock {lock-id}`

---

## Segurança dos Destroy Workflows

### ⚠️ REGRA CRÍTICA

Cada repositório possui um workflow `destroy.yml` que:

1. ✅ **REQUER** confirmação manual (digitar texto específico)
2. ✅ **SOMENTE** executa `terraform destroy` no seu próprio state
3. ✅ **NÃO** usa AWS CLI para deletar recursos por padrão de nome

### ❌ O que NÃO deve existir em destroy.yml

```yaml
# ❌ NUNCA faça isso - deleta recursos de TODOS os repos!
aws lambda list-functions --query "Functions[?contains(FunctionName, 'tech-challenge')]"
aws apigateway get-rest-apis --query "items[?contains(name, 'tech-challenge')]"
aws logs delete-log-group --log-group-name "/aws/lambda/tech-challenge*"
```

### ✅ O que DEVE existir em destroy.yml

```yaml
# ✅ CORRETO - apenas destroy do Terraform
terraform init
terraform destroy -auto-approve
```

Esta regra garante que destruir um repositório **NÃO** afete recursos de outros repositórios.

---

## Validação Pós-Deploy Completa

Checklist para validar que tudo está funcionando:

- [ ] API Gateway responde no health check
- [ ] Cognito User Pool existe e tem client configurado
- [ ] Lambda authorizer está configurado
- [ ] NLB está healthy
- [ ] Todos os pods estão Running
- [ ] Todos os services existem
- [ ] RDS está acessível pelos pods
- [ ] DynamoDB tables existem
- [ ] Logs estão sendo gerados no CloudWatch
