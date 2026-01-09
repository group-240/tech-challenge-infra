#!/bin/bash
# ============================================
# Script para ver logs do CloudWatch
# ============================================
# Uso: ./logs.sh [serviço] [minutos]
# 
# Exemplos:
#   ./logs.sh customer 30    # Logs do customer dos últimos 30 min
#   ./logs.sh orders 60      # Logs do orders da última hora
#   ./logs.sh all 15         # Todos os logs dos últimos 15 min
#   ./logs.sh eks 30         # Logs do EKS control plane
# ============================================

SERVICE=${1:-"all"}
MINUTES=${2:-30}
REGION="us-east-1"
CLUSTER_NAME="tech-challenge-cluster"

# Calcular timestamp
START_TIME=$(($(date +%s) - ($MINUTES * 60)))000
END_TIME=$(date +%s)000

echo ""
echo "============================================"
echo "📋 LOGS - Tech Challenge"
echo "============================================"
echo "Serviço: $SERVICE"
echo "Período: últimos $MINUTES minutos"
echo "============================================"
echo ""

get_logs() {
    local LOG_GROUP=$1
    local TITLE=$2
    
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[0;34m$TITLE\033[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    
    # Verificar se log group existe
    if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        echo "⚠️  Log group '$LOG_GROUP' não encontrado"
        echo ""
        return
    fi
    
    # Buscar logs
    aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --query 'events[*].[timestamp,message]' \
        --output text 2>/dev/null | while read -r timestamp message; do
            if [ -n "$timestamp" ]; then
                # Converter timestamp para data legível
                DATE=$(date -d @$((timestamp/1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$timestamp")
                echo "[$DATE] $message"
            fi
        done
    
    EVENTS=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --query 'length(events)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$EVENTS" == "0" ] || [ -z "$EVENTS" ]; then
        echo "📭 Nenhum log encontrado no período"
    fi
    echo ""
}

case $SERVICE in
    "customer")
        get_logs "/tech-challenge/customer-service" "🧑 Customer Service"
        ;;
    "orders")
        get_logs "/tech-challenge/orders-service" "📦 Orders Service"
        ;;
    "payments")
        get_logs "/tech-challenge/payments-service" "💳 Payments Service"
        ;;
    "eks")
        get_logs "/aws/eks/$CLUSTER_NAME/cluster" "🎯 EKS Control Plane"
        ;;
    "all")
        get_logs "/tech-challenge/customer-service" "🧑 Customer Service"
        get_logs "/tech-challenge/orders-service" "📦 Orders Service"
        get_logs "/tech-challenge/payments-service" "💳 Payments Service"
        get_logs "/tech-challenge/applications" "📱 Applications (Geral)"
        ;;
    *)
        echo "Uso: ./logs.sh [serviço] [minutos]"
        echo ""
        echo "Serviços disponíveis:"
        echo "  customer  - Logs do Customer Service"
        echo "  orders    - Logs do Orders Service"
        echo "  payments  - Logs do Payments Service"
        echo "  eks       - Logs do EKS Control Plane"
        echo "  all       - Todos os logs"
        echo ""
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo "📊 Para ver no Console AWS:"
echo "https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups"
echo "============================================"
