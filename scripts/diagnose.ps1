# ============================================
# Script de Diagnostico - Tech Challenge AWS
# PowerShell Version
# ============================================
# Uso: .\diagnose.ps1
# ============================================

$ErrorActionPreference = "Continue"

# Configuracoes
$CLUSTER_NAME = "tech-challenge-cluster"
$REGION = "us-east-1"
$NAMESPACE = "tech-challenge"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO TECH CHALLENGE AWS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Data: $(Get-Date)"
Write-Host "Regiao: $REGION"
Write-Host ""

# ============================================
# 1. VERIFICAR CREDENCIAIS AWS
# ============================================
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "1. CREDENCIAIS AWS" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

try {
    $identity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
    if ($identity.Account) {
        Write-Host "[OK] Credenciais validas" -ForegroundColor Green
        Write-Host "   Account: $($identity.Account)"
        Write-Host "   ARN: $($identity.Arn)"
    }
} catch {
    Write-Host "[ERRO] Credenciais invalidas ou expiradas!" -ForegroundColor Red
    Write-Host "   -> Atualize suas credenciais no AWS Academy" -ForegroundColor Yellow
    exit 1
}

# ============================================
# 2. EKS CLUSTER
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "2. EKS CLUSTER" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

$clusterExists = $false
try {
    $clusterJson = aws eks describe-cluster --name $CLUSTER_NAME --output json 2>&1
    if ($clusterJson -notmatch "error" -and $clusterJson -notmatch "ResourceNotFoundException") {
        $cluster = $clusterJson | ConvertFrom-Json
        if ($cluster.cluster.status -eq "ACTIVE") {
            Write-Host "[OK] Cluster '$CLUSTER_NAME': ACTIVE" -ForegroundColor Green
            Write-Host "   Version: $($cluster.cluster.version)"
            Write-Host "   Endpoint: $($cluster.cluster.endpoint)"
            $clusterExists = $true
        } else {
            Write-Host "[WARN] Cluster '$CLUSTER_NAME': $($cluster.cluster.status)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERRO] Cluster '$CLUSTER_NAME' nao encontrado" -ForegroundColor Red
        Write-Host "   -> Execute o deploy de tech-challenge-infra primeiro" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERRO] Cluster '$CLUSTER_NAME' nao encontrado" -ForegroundColor Red
}

# Node Groups
if ($clusterExists) {
    Write-Host ""
    Write-Host "Node Groups:" -ForegroundColor Cyan
    try {
        $nodegroupsJson = aws eks list-nodegroups --cluster-name $CLUSTER_NAME --output json 2>&1
        $nodegroups = $nodegroupsJson | ConvertFrom-Json
        foreach ($ng in $nodegroups.nodegroups) {
            $ngJson = aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --output json 2>&1
            $ngDetails = $ngJson | ConvertFrom-Json
            Write-Host "   $ng : $($ngDetails.nodegroup.status) (Desired: $($ngDetails.nodegroup.scalingConfig.desiredSize))"
        }
    } catch {
        Write-Host "   Nenhum node group encontrado" -ForegroundColor Yellow
    }

    # Addons
    Write-Host ""
    Write-Host "EKS Addons:" -ForegroundColor Cyan
    try {
        $addonsJson = aws eks list-addons --cluster-name $CLUSTER_NAME --output json 2>&1
        $addons = $addonsJson | ConvertFrom-Json
        foreach ($addon in $addons.addons) {
            Write-Host "   - $addon"
        }
        if ($addons.addons.Count -eq 0) {
            Write-Host "   Nenhum addon instalado" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   Erro ao listar addons" -ForegroundColor Yellow
    }
}

# ============================================
# 3. ECR REPOSITORIES
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "3. ECR REPOSITORIES" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

$repos = @("tech-challenge-customer", "tech-challenge-orders", "tech-challenge-payments")
foreach ($repo in $repos) {
    try {
        $repoJson = aws ecr describe-repositories --repository-names $repo --output json 2>&1
        if ($repoJson -notmatch "RepositoryNotFoundException") {
            $imagesJson = aws ecr list-images --repository-name $repo --output json 2>&1
            $images = $imagesJson | ConvertFrom-Json
            $count = if ($images.imageIds) { $images.imageIds.Count } else { 0 }
            Write-Host "[OK] $repo : $count imagens" -ForegroundColor Green
        } else {
            Write-Host "[ERRO] $repo : Nao encontrado" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ERRO] $repo : Nao encontrado" -ForegroundColor Red
    }
}

# ============================================
# 4. RDS DATABASE
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "4. RDS DATABASE" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

try {
    $rdsJson = aws rds describe-db-instances --output json 2>&1
    $rds = $rdsJson | ConvertFrom-Json
    if ($rds.DBInstances.Count -gt 0) {
        foreach ($db in $rds.DBInstances) {
            $status = if ($db.DBInstanceStatus -eq "available") { "[OK]" } else { "[WARN]" }
            $color = if ($db.DBInstanceStatus -eq "available") { "Green" } else { "Yellow" }
            Write-Host "$status $($db.DBInstanceIdentifier): $($db.DBInstanceStatus) ($($db.Engine))" -ForegroundColor $color
            if ($db.Endpoint) {
                Write-Host "   Endpoint: $($db.Endpoint.Address)"
            }
        }
    } else {
        Write-Host "Nenhuma instancia RDS encontrada" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Erro ao verificar RDS" -ForegroundColor Yellow
}

# ============================================
# 5. DYNAMODB
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "5. DYNAMODB" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

try {
    $tablesJson = aws dynamodb list-tables --output json 2>&1
    $tables = $tablesJson | ConvertFrom-Json
    if ($tables.TableNames.Count -gt 0) {
        foreach ($table in $tables.TableNames) {
            Write-Host "   - $table" -ForegroundColor Green
        }
    } else {
        Write-Host "Nenhuma tabela encontrada" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Erro ao verificar DynamoDB" -ForegroundColor Yellow
}

# ============================================
# 6. CLOUDWATCH LOGS
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "6. CLOUDWATCH LOGS" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

Write-Host "Log Groups (tech-challenge):" -ForegroundColor Cyan
try {
    $logsJson = aws logs describe-log-groups --log-group-name-prefix "/tech-challenge" --output json 2>&1
    $logs = $logsJson | ConvertFrom-Json
    foreach ($lg in $logs.logGroups) {
        Write-Host "   $($lg.logGroupName)" -ForegroundColor Green
    }
    if ($logs.logGroups.Count -eq 0) {
        Write-Host "   Nenhum log group encontrado" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Erro ao listar log groups" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Log Groups (EKS):" -ForegroundColor Cyan
try {
    $eksLogsJson = aws logs describe-log-groups --log-group-name-prefix "/aws/eks" --output json 2>&1
    $eksLogs = $eksLogsJson | ConvertFrom-Json
    foreach ($lg in $eksLogs.logGroups) {
        Write-Host "   $($lg.logGroupName)" -ForegroundColor Green
    }
    if ($eksLogs.logGroups.Count -eq 0) {
        Write-Host "   Nenhum log group EKS" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Erro ao listar logs EKS" -ForegroundColor Yellow
}

# ============================================
# 7. CLOUDWATCH ALARMS
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "7. CLOUDWATCH ALARMS" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue

try {
    $alarmsJson = aws cloudwatch describe-alarms --output json 2>&1
    $alarms = $alarmsJson | ConvertFrom-Json
    foreach ($alarm in $alarms.MetricAlarms) {
        $statusColor = switch ($alarm.StateValue) {
            "OK" { "Green" }
            "ALARM" { "Red" }
            default { "Yellow" }
        }
        Write-Host "$($alarm.AlarmName): $($alarm.StateValue)" -ForegroundColor $statusColor
    }
    if ($alarms.MetricAlarms.Count -eq 0) {
        Write-Host "Nenhum alarm configurado" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Erro ao verificar alarms" -ForegroundColor Yellow
}

# ============================================
# 8. KUBERNETES (se cluster ativo)
# ============================================
if ($clusterExists) {
    Write-Host ""
    Write-Host "--------------------------------------------" -ForegroundColor Blue
    Write-Host "8. KUBERNETES" -ForegroundColor Blue
    Write-Host "--------------------------------------------" -ForegroundColor Blue

    try {
        Write-Host "Configurando kubectl..." -ForegroundColor Gray
        aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION 2>&1 | Out-Null
        
        Write-Host ""
        Write-Host "Pods no namespace '$NAMESPACE':" -ForegroundColor Cyan
        kubectl get pods -n $NAMESPACE -o wide 2>&1
        
        Write-Host ""
        Write-Host "Services:" -ForegroundColor Cyan
        kubectl get svc -n $NAMESPACE 2>&1
        
        Write-Host ""
        Write-Host "Eventos recentes:" -ForegroundColor Cyan
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' 2>&1 | Select-Object -Last 10
    } catch {
        Write-Host "Nao foi possivel conectar ao Kubernetes" -ForegroundColor Yellow
    }
}

# ============================================
# LINKS UTEIS
# ============================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host "LINKS UTEIS" -ForegroundColor Blue
Write-Host "--------------------------------------------" -ForegroundColor Blue
Write-Host ""
Write-Host "CloudWatch Dashboard:"
Write-Host "   https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=TechChallenge-Dashboard" -ForegroundColor Cyan
Write-Host ""
Write-Host "CloudWatch Logs:"
Write-Host "   https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups" -ForegroundColor Cyan
Write-Host ""
Write-Host "EKS Console:"
Write-Host "   https://$REGION.console.aws.amazon.com/eks/home?region=$REGION#/clusters/$CLUSTER_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Diagnostico concluido em $(Get-Date)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
