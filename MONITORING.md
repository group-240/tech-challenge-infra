# 📊 Guia de Monitoramento AWS - CloudWatch

Este guia explica como obter visibilidade completa sobre seus recursos AWS usando CloudWatch e outras ferramentas.

## 🎯 Índice

1. [Visão Geral](#visão-geral)
2. [Acesso Rápido](#acesso-rápido)
3. [CloudWatch Dashboard](#cloudwatch-dashboard)
4. [CloudWatch Logs](#cloudwatch-logs)
5. [Container Insights](#container-insights)
6. [Scripts de Diagnóstico](#scripts-de-diagnóstico)
7. [Troubleshooting](#troubleshooting)

---

## 📋 Visão Geral

Após o deploy da infraestrutura, você terá acesso a:

| Recurso | O que mostra | Como acessar |
|---------|--------------|--------------|
| **CloudWatch Dashboard** | Visão unificada (CPU, memória, pods) | Console AWS |
| **CloudWatch Logs** | Logs das aplicações e EKS | Console AWS |
| **Container Insights** | Métricas detalhadas do EKS | Console AWS |
| **Scripts locais** | Diagnóstico rápido | Terminal |

---

## 🚀 Acesso Rápido

### Via Console AWS

Após o deploy, os seguintes links estarão disponíveis no output do Terraform:

```bash
# Ver outputs do Terraform
cd tech-challenge-infra/terraform
terraform output
```

**Links diretos (us-east-1):**

- 📈 **Dashboard:** https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=TechChallenge-Dashboard

- 📋 **Logs:** https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups

- 🎯 **EKS:** https://us-east-1.console.aws.amazon.com/eks/home?region=us-east-1#/clusters/tech-challenge-cluster

---

## 📊 CloudWatch Dashboard

O dashboard `TechChallenge-Dashboard` mostra em tempo real:

### Métricas Disponíveis

| Widget | Descrição |
|--------|-----------|
| CPU dos Nodes | % de CPU utilizada pelos nodes do EKS |
| Memória dos Nodes | % de memória utilizada |
| Containers Rodando | Número de containers ativos |
| CPU/Memória Pods | Uso por namespace (tech-challenge) |
| Logs Recentes | Últimos 50 logs das aplicações |
| Tráfego de Rede | Bytes trafegados |
| Uso de Disco | % de disco utilizado |

### Como Acessar

1. Acesse o [Console AWS](https://console.aws.amazon.com/)
2. Vá em **CloudWatch** → **Dashboards**
3. Clique em **TechChallenge-Dashboard**

### Personalização

Você pode adicionar widgets personalizados:
1. Clique em **"Add widget"**
2. Escolha o tipo (Métrica, Log, Texto)
3. Configure a métrica desejada

---

## 📋 CloudWatch Logs

### Log Groups Disponíveis

| Log Group | Conteúdo |
|-----------|----------|
| `/aws/eks/tech-challenge-cluster/cluster` | Logs do EKS Control Plane |
| `/tech-challenge/applications` | Logs gerais das aplicações |
| `/tech-challenge/customer-service` | Logs do Customer Service |
| `/tech-challenge/orders-service` | Logs do Orders Service |
| `/tech-challenge/payments-service` | Logs do Payments Service |

### Como Ver Logs

#### Via Console AWS

1. Acesse **CloudWatch** → **Logs** → **Log groups**
2. Clique no log group desejado
3. Selecione um **Log stream**
4. Use **Filter events** para buscar

#### Via AWS CLI

```bash
# Ver logs recentes do Customer Service (últimos 30 min)
aws logs filter-log-events \
  --log-group-name "/tech-challenge/customer-service" \
  --start-time $(( $(date +%s) - 1800 ))000 \
  --query 'events[*].message' \
  --output text

# Ver logs do EKS
aws logs filter-log-events \
  --log-group-name "/aws/eks/tech-challenge-cluster/cluster" \
  --start-time $(( $(date +%s) - 1800 ))000 \
  --query 'events[*].message' \
  --output text
```

#### Usando o Script

```bash
# Windows (PowerShell)
cd tech-challenge-infra/scripts
.\logs.ps1 customer 30

# Linux/Mac (Bash)
./logs.sh customer 30

# Opções:
# customer, orders, payments, eks, all
# Número = minutos de histórico
```

### Queries no CloudWatch Logs Insights

Acesse **CloudWatch** → **Logs** → **Logs Insights**

```sql
# Erros nas últimas 24h
fields @timestamp, @message
| filter @message like /ERROR|Exception|error/
| sort @timestamp desc
| limit 100

# Requests por endpoint
fields @timestamp, @message
| filter @message like /GET|POST|PUT|DELETE/
| stats count() by bin(1h)

# Latência de requests
fields @timestamp, @message
| filter @message like /completed in/
| parse @message "completed in * ms" as latency
| stats avg(latency), max(latency) by bin(5m)
```

---

## 🐳 Container Insights

O addon `amazon-cloudwatch-observability` fornece métricas detalhadas do EKS.

### Métricas Disponíveis

**Node Level:**
- `node_cpu_utilization`
- `node_memory_utilization`
- `node_filesystem_utilization`
- `node_network_total_bytes`

**Pod Level:**
- `pod_cpu_utilization`
- `pod_memory_utilization`
- `pod_number_of_running_containers`

**Namespace Level:**
- Agregações por namespace (tech-challenge)

### Como Acessar

1. **CloudWatch** → **Container Insights**
2. Selecione **EKS Clusters**
3. Clique em **tech-challenge-cluster**

### Visualizações Disponíveis

- **Map View:** Mapa visual do cluster
- **Resources:** Lista de pods, nodes, services
- **Performance Monitoring:** Gráficos de performance

---

## 🔧 Scripts de Diagnóstico

### diagnose.ps1 (Windows)

```powershell
cd tech-challenge-infra/scripts
.\diagnose.ps1
```

**O que verifica:**
- ✅ Credenciais AWS
- ✅ Status do EKS Cluster
- ✅ Node Groups
- ✅ ECR Repositories
- ✅ RDS Database
- ✅ CloudWatch Logs
- ✅ CloudWatch Alarms
- ✅ Pods Kubernetes
- ✅ Services Kubernetes

### diagnose.sh (Linux/Mac)

```bash
cd tech-challenge-infra/scripts
chmod +x diagnose.sh
./diagnose.sh
```

### Exemplo de Output

```
============================================
🔍 DIAGNÓSTICO TECH CHALLENGE AWS
============================================
Data: Thu Jan  9 10:00:00 2026
Região: us-east-1

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. CREDENCIAIS AWS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Credenciais válidas
   Account: 123456789012
   ARN: arn:aws:sts::123456789012:assumed-role/voclabs/user

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. EKS CLUSTER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Cluster 'tech-challenge-cluster': ACTIVE
   Version: 1.29
   Endpoint: https://xxx.eks.amazonaws.com
...
```

---

## 🚨 CloudWatch Alarms

Alarms configurados automaticamente:

| Alarm | Condição | Descrição |
|-------|----------|-----------|
| `tech-challenge-high-cpu` | CPU > 80% por 10 min | Nodes com CPU alta |
| `tech-challenge-high-memory` | Memory > 85% por 10 min | Nodes com memória alta |

### Verificar Alarms

```bash
# Via CLI
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table
```

### Adicionar Notificações (opcional)

Para receber emails quando um alarm disparar:

1. Crie um **SNS Topic**
2. Adicione seu email como subscriber
3. Configure o alarm para notificar o topic

---

## 🔍 Troubleshooting

### "Credenciais AWS expiradas"

```
❌ Credenciais AWS inválidas ou expiradas!
```

**Solução:**
1. Acesse AWS Academy
2. Inicie/reinicie o Lab
3. Copie novas credenciais
4. Atualize os GitHub Secrets

### "Cluster não encontrado"

```
❌ Cluster 'tech-challenge-cluster' não encontrado
```

**Solução:**
1. Deploy `tech-challenge-infra` primeiro
2. Aguarde ~15 minutos para o cluster ficar ACTIVE

### "Nenhum log encontrado"

```
📭 Nenhum log encontrado no período
```

**Possíveis causas:**
1. Aplicação não está rodando
2. Container Insights não instalado
3. Logs ainda não foram gerados

**Verificar:**
```bash
# Ver pods rodando
kubectl get pods -n tech-challenge

# Ver logs direto do pod
kubectl logs -n tech-challenge deployment/customer-deployment --tail=50
```

### "Container Insights sem dados"

**Causa:** O addon pode demorar ~5 minutos para começar a coletar métricas.

**Verificar:**
```bash
# Ver se addon está instalado
aws eks list-addons --cluster-name tech-challenge-cluster

# Deve mostrar: amazon-cloudwatch-observability
```

---

## 📚 Referências

- [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [EKS Logging](https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)

---

## 🎯 Próximos Passos

1. Faça deploy de `tech-challenge-infra` com as novas configurações
2. Execute o script de diagnóstico: `.\diagnose.ps1`
3. Acesse o CloudWatch Dashboard para ver métricas em tempo real
4. Configure alertas adicionais se necessário
