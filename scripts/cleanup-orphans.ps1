#!/usr/bin/env pwsh
# ============================================
# Script para limpar recursos órfãos na AWS
# ============================================

param(
    [switch]$DryRun = $true,  # Por padrão, só mostra o que faria
    [switch]$Force            # Força a exclusão sem confirmação
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Limpeza de Recursos Órfãos AWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY-RUN] Modo simulação - nenhum recurso será excluído" -ForegroundColor Yellow
    Write-Host "Use -DryRun:`$false para executar de verdade" -ForegroundColor Yellow
    Write-Host ""
}

# Verificar credenciais AWS
Write-Host "[1/5] Verificando credenciais AWS..." -ForegroundColor Cyan
$identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
if (-not $identity) {
    Write-Host "❌ Erro: Credenciais AWS não configuradas" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Conta: $($identity.Account)" -ForegroundColor Green

# Listar Target Groups órfãos
Write-Host ""
Write-Host "[2/5] Procurando Target Groups órfãos..." -ForegroundColor Cyan

$targetGroups = aws elbv2 describe-target-groups --output json 2>$null | ConvertFrom-Json
$orphanTGs = @()

foreach ($tg in $targetGroups.TargetGroups) {
    # Verificar se o nome parece ser do nosso projeto mas não é o atual
    if ($tg.TargetGroupName -like "tech-challenge*" -and $tg.TargetGroupName -ne "tech-challenge-nginx-tg") {
        Write-Host "  🔍 Encontrado: $($tg.TargetGroupName)" -ForegroundColor Yellow
        
        # Verificar se está em uso por algum listener
        $listeners = aws elbv2 describe-listeners --load-balancer-arn $tg.LoadBalancerArns[0] --output json 2>$null | ConvertFrom-Json
        
        $orphanTGs += @{
            Name = $tg.TargetGroupName
            ARN = $tg.TargetGroupArn
            LoadBalancerArns = $tg.LoadBalancerArns
        }
    }
}

if ($orphanTGs.Count -eq 0) {
    Write-Host "✅ Nenhum Target Group órfão encontrado" -ForegroundColor Green
} else {
    Write-Host "⚠️  Encontrados $($orphanTGs.Count) Target Group(s) órfão(s)" -ForegroundColor Yellow
    
    foreach ($orphan in $orphanTGs) {
        Write-Host ""
        Write-Host "  Target Group: $($orphan.Name)" -ForegroundColor White
        Write-Host "  ARN: $($orphan.ARN)" -ForegroundColor Gray
        
        if (-not $DryRun) {
            # Se estiver em uso por listeners, listar quais
            if ($orphan.LoadBalancerArns.Count -gt 0) {
                foreach ($lbArn in $orphan.LoadBalancerArns) {
                    $listeners = aws elbv2 describe-listeners --load-balancer-arn $lbArn --output json 2>$null | ConvertFrom-Json
                    foreach ($listener in $listeners.Listeners) {
                        if ($listener.DefaultActions.TargetGroupArn -eq $orphan.ARN) {
                            Write-Host "  ⚠️  Em uso pelo listener: $($listener.ListenerArn)" -ForegroundColor Yellow
                            
                            if ($Force -or (Read-Host "  Deletar listener? (y/n)") -eq "y") {
                                Write-Host "  🗑️  Deletando listener..." -ForegroundColor Red
                                aws elbv2 delete-listener --listener-arn $listener.ListenerArn
                            }
                        }
                    }
                }
            }
            
            if ($Force -or (Read-Host "  Deletar Target Group '$($orphan.Name)'? (y/n)") -eq "y") {
                Write-Host "  🗑️  Deletando Target Group..." -ForegroundColor Red
                aws elbv2 delete-target-group --target-group-arn $orphan.ARN
                Write-Host "  ✅ Target Group deletado" -ForegroundColor Green
            }
        }
    }
}

# Listar Load Balancers não utilizados
Write-Host ""
Write-Host "[3/5] Verificando Load Balancers..." -ForegroundColor Cyan

$nlbs = aws elbv2 describe-load-balancers --output json 2>$null | ConvertFrom-Json
foreach ($nlb in $nlbs.LoadBalancers) {
    if ($nlb.LoadBalancerName -like "tech-challenge*") {
        Write-Host "  📋 $($nlb.LoadBalancerName) - $($nlb.State.Code)" -ForegroundColor White
    }
}

# Verificar VPC Links órfãos
Write-Host ""
Write-Host "[4/5] Verificando VPC Links do API Gateway..." -ForegroundColor Cyan

$vpcLinks = aws apigatewayv2 get-vpc-links --output json 2>$null | ConvertFrom-Json
if ($vpcLinks.Items) {
    foreach ($link in $vpcLinks.Items) {
        Write-Host "  📋 $($link.Name) - $($link.VpcLinkStatus)" -ForegroundColor White
    }
} else {
    Write-Host "  Nenhum VPC Link encontrado" -ForegroundColor Gray
}

# Resumo
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resumo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "Para executar a limpeza de verdade, rode:" -ForegroundColor Yellow
    Write-Host "  .\cleanup-orphans.ps1 -DryRun:`$false" -ForegroundColor White
    Write-Host ""
    Write-Host "Para forçar sem confirmação:" -ForegroundColor Yellow
    Write-Host "  .\cleanup-orphans.ps1 -DryRun:`$false -Force" -ForegroundColor White
}

Write-Host ""
