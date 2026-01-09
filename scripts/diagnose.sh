#!/bin/bash
# ============================================
# Script de Diagnóstico - Tech Challenge AWS
# ============================================
# Este script verifica o status de todos os recursos
# na AWS e gera um relatório detalhado.
#
# Uso: ./diagnose.sh
# ============================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
CLUSTER_NAME="tech-challenge-cluster"
REGION="us-east-1"
NAMESPACE="tech-challenge"

echo ""
echo "============================================"
echo "🔍 DIAGNÓSTICO TECH CHALLENGE AWS"
echo "============================================"
echo "Data: $(date)"
echo "Região: $REGION"
echo ""

# Função para verificar status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ ERRO${NC}"
    fi
}

# ============================================
# 1. VERIFICAR CREDENCIAIS AWS
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}1. CREDENCIAIS AWS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -n "Verificando credenciais... "
if aws sts get-caller-identity > /tmp/aws-identity.json 2>&1; then
    echo -e "${GREEN}✅ Válidas${NC}"
    echo "  Account: $(jq -r '.Account' /tmp/aws-identity.json)"
    echo "  ARN: $(jq -r '.Arn' /tmp/aws-identity.json)"
else
    echo -e "${RED}❌ Inválidas ou expiradas!${NC}"
    echo -e "${YELLOW}  → Atualize suas credenciais no AWS Academy${NC}"
    exit 1
fi

# ============================================
# 2. VPC E NETWORKING
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}2. VPC E NETWORKING${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -n "VPCs: "
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
echo "$VPC_COUNT encontrada(s)"

echo ""
echo "Detalhes das VPCs:"
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null || echo "Erro ao listar VPCs"

echo ""
echo -n "Subnets: "
SUBNET_COUNT=$(aws ec2 describe-subnets --query 'length(Subnets)' --output text 2>/dev/null || echo "0")
echo "$SUBNET_COUNT encontrada(s)"

# ============================================
# 3. EKS CLUSTER
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}3. EKS CLUSTER${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -n "Cluster '$CLUSTER_NAME': "
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    echo -e "${GREEN}$CLUSTER_STATUS${NC}"
elif [ "$CLUSTER_STATUS" == "NOT_FOUND" ]; then
    echo -e "${RED}NÃO ENCONTRADO${NC}"
    echo -e "${YELLOW}  → Execute o deploy de tech-challenge-infra primeiro${NC}"
else
    echo -e "${YELLOW}$CLUSTER_STATUS${NC}"
fi

if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    echo ""
    echo "Detalhes do Cluster:"
    aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.[name,version,status,endpoint]' --output table 2>/dev/null
    
    echo ""
    echo "Node Groups:"
    aws eks list-nodegroups --cluster-name $CLUSTER_NAME --output table 2>/dev/null || echo "Erro ao listar node groups"
    
    echo ""
    echo -n "Nodes: "
    NODE_GROUP=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --query 'nodegroups[0]' --output text 2>/dev/null)
    if [ -n "$NODE_GROUP" ] && [ "$NODE_GROUP" != "None" ]; then
        NODE_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP --query 'nodegroup.status' --output text 2>/dev/null)
        DESIRED=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP --query 'nodegroup.scalingConfig.desiredSize' --output text 2>/dev/null)
        echo -e "Status: ${GREEN}$NODE_STATUS${NC} | Desired: $DESIRED"
    fi
    
    echo ""
    echo "EKS Addons:"
    aws eks list-addons --cluster-name $CLUSTER_NAME --output table 2>/dev/null || echo "Nenhum addon instalado"
fi

# ============================================
# 4. ECR REPOSITORIES
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}4. ECR REPOSITORIES${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for REPO in "tech-challenge-customer" "tech-challenge-orders" "tech-challenge-payments"; do
    echo -n "$REPO: "
    if aws ecr describe-repositories --repository-names $REPO > /dev/null 2>&1; then
        IMAGE_COUNT=$(aws ecr list-images --repository-name $REPO --query 'length(imageIds)' --output text 2>/dev/null || echo "0")
        echo -e "${GREEN}✅ Existe${NC} ($IMAGE_COUNT imagens)"
    else
        echo -e "${RED}❌ Não encontrado${NC}"
    fi
done

# ============================================
# 5. RDS DATABASE
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}5. RDS DATABASE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Instâncias RDS:"
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,Endpoint.Address]' --output table 2>/dev/null || echo "Nenhuma instância RDS encontrada"

# ============================================
# 6. DYNAMODB
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}6. DYNAMODB${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Tabelas DynamoDB:"
aws dynamodb list-tables --output table 2>/dev/null || echo "Nenhuma tabela encontrada"

# ============================================
# 7. CLOUDWATCH LOGS
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}7. CLOUDWATCH LOGS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Log Groups (tech-challenge):"
aws logs describe-log-groups --log-group-name-prefix "/tech-challenge" --query 'logGroups[*].[logGroupName,storedBytes]' --output table 2>/dev/null || echo "Nenhum log group encontrado"

echo ""
echo "Log Groups (EKS):"
aws logs describe-log-groups --log-group-name-prefix "/aws/eks" --query 'logGroups[*].[logGroupName,storedBytes]' --output table 2>/dev/null || echo "Nenhum log group EKS encontrado"

# ============================================
# 8. CLOUDWATCH ALARMS
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}8. CLOUDWATCH ALARMS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Alarms:"
aws cloudwatch describe-alarms --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table 2>/dev/null || echo "Nenhum alarm configurado"

# ============================================
# 9. KUBERNETES (se cluster ativo)
# ============================================
if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}9. KUBERNETES RESOURCES${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo "Configurando kubectl..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION > /dev/null 2>&1
    
    echo ""
    echo "Namespaces:"
    kubectl get namespaces 2>/dev/null || echo "Erro ao conectar ao cluster"
    
    echo ""
    echo "Pods no namespace '$NAMESPACE':"
    kubectl get pods -n $NAMESPACE -o wide 2>/dev/null || echo "Nenhum pod ou namespace não existe"
    
    echo ""
    echo "Services no namespace '$NAMESPACE':"
    kubectl get svc -n $NAMESPACE 2>/dev/null || echo "Nenhum service encontrado"
    
    echo ""
    echo "Deployments no namespace '$NAMESPACE':"
    kubectl get deployments -n $NAMESPACE 2>/dev/null || echo "Nenhum deployment encontrado"
    
    echo ""
    echo "Eventos recentes (últimos 10):"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "Nenhum evento"
fi

# ============================================
# 10. API GATEWAY
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}10. API GATEWAY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "REST APIs:"
aws apigateway get-rest-apis --query 'items[*].[name,id]' --output table 2>/dev/null || echo "Nenhuma API encontrada"

# ============================================
# RESUMO FINAL
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 RESUMO${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Para ver mais detalhes, acesse:"
echo ""
echo "📈 CloudWatch Dashboard:"
echo "   https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=TechChallenge-Dashboard"
echo ""
echo "📋 CloudWatch Logs:"
echo "   https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups"
echo ""
echo "🎯 EKS Console:"
echo "   https://$REGION.console.aws.amazon.com/eks/home?region=$REGION#/clusters/$CLUSTER_NAME"
echo ""
echo "============================================"
echo "Diagnóstico concluído em $(date)"
echo "============================================"
