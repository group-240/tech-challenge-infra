# Tech Challenge - Infraestrutura

Repositório responsável pela infraestrutura base da AWS.

## O que este repositório cria

- **VPC** - Rede virtual com subnets públicas e privadas
- **EKS** - Cluster Kubernetes gerenciado
- **ECR** - 3 repositórios de imagens Docker (customer, orders, payments)

## Dependências

| Dependência | Descrição |
|-------------|-----------|
| AWS Account | Conta AWS com permissões de administrador |
| Terraform >= 1.10.0 | Ferramenta de IaC |

## Secrets Necessários (GitHub)

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (obrigatório para AWS Academy Learner Lab)

## Ordem de Execução

1. Executar **bootstrap** primeiro (cria S3 + DynamoDB para state)
2. Depois executar o **main** (VPC, EKS, ECR)

## Outputs

Este repositório exporta outputs usados por outros repositórios:
- VPC ID e Subnets
- EKS Cluster Name e Endpoint
- ECR Repository URLs
