# =========================================================
# CloudNative Pipeline - 环境配置文件生成脚本
# 自动生成 .env 文件，包含随机安全密码
# =========================================================

$ErrorActionPreference = "Stop"

# 颜色定义
function Write-Success { param($msg) Write-Host "[✅] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "[❌] $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "[⚠️]  $msg" -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host "[ℹ️]  $msg" -ForegroundColor Cyan }

# 生成安全随机密码
function Generate-SecurePassword {
    param(
        [int]$Length = 24
    )
    
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $result = New-Object char[] $Length
    
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 1
        $random.GetBytes($bytes)
        $result[$i] = $chars[$bytes[0] % $chars.Length]
    }
    
    return -join $result
}

# 主流程
function Start-Main {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       环境配置文件生成向导                           ║" -ForegroundColor Cyan
    Write-Host "  ║       自动生成 .env 配置文件                         ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # 确定 .env 文件路径
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $envFile = Join-Path $projectRoot ".env"
    
    Write-Info "项目目录: $projectRoot"
    Write-Info "配置文件: $envFile"
    Write-Host ""
    
    # 检查是否已存在
    if (Test-Path $envFile) {
        Write-Warn ".env 文件已存在"
        $overwrite = Read-Host "是否覆盖？(Y/N)"
        
        if ($overwrite -ne "Y" -and $overwrite -ne "y") {
            Write-Info "保留原有 .env 文件"
            Write-Host ""
            Read-Host "按 Enter 键退出"
            return
        }
        
        Write-Info "覆盖原有文件..."
    }
    
    # 生成密码
    Write-Info "生成安全密码..."
    $dbPassword = Generate-SecurePassword
    $redisPassword = Generate-SecurePassword
    $appPassword = Generate-SecurePassword
    
    Write-Success "密码生成完成"
    Write-Host ""
    
    # 生成配置内容
    $envContent = @"
# ============================================================
# CloudNative Pipeline - 本地配置文件
# ============================================================
# ⚠️  此文件由脚本自动生成
# ⚠️  请勿手动修改，如需重新生成请运行 scripts\env-setup.ps1
# ============================================================

# 应用配置
APP_NAME=cloudnative-pipeline
APP_PORT=8080
APP_ENV=development
APP_DEBUG=true

# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_NAME=pipeline
DB_USER=pipeline_user
DB_PASSWORD=$dbPassword

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=$redisPassword

# Kubernetes 配置
K8S_CONTEXT=docker-desktop
K8S_NAMESPACE=pipeline

# 流水线配置
PIPELINE_TIMEOUT=3600
MAX_CONCURRENT_BUILDS=5

# 监控配置
PROMETHEUS_URL=http://localhost:9090
GRAFANA_URL=http://localhost:3000

# 安全配置
SECRET_KEY=$appPassword
JWT_EXPIRATION=86400

# 日志配置
LOG_LEVEL=info
LOG_FORMAT=json

"@
    
    # 写入文件
    try {
        Set-Content -Path $envFile -Value $envContent -Encoding UTF8
        Write-Success ".env 文件已生成"
        Write-Host ""
        
        # 显示配置摘要（隐藏密码）
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "  配置摘要" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  应用端口:     8080" -ForegroundColor Gray
        Write-Host "  数据库端口:   5432" -ForegroundColor Gray
        Write-Host "  Redis 端口:   6379" -ForegroundColor Gray
        Write-Host "  K8s 上下文:   docker-desktop" -ForegroundColor Gray
        Write-Host "  命名空间:     pipeline" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  密码长度:     24 位" -ForegroundColor Gray
        Write-Host "  密码强度:     高 (随机生成)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Success "配置生成完成!"
        Write-Host ""
        Write-Host "  下一步:" -ForegroundColor Yellow
        Write-Host "  1. 运行 docker-compose up -d 启动服务" -ForegroundColor White
        Write-Host "  2. 访问 http://localhost:8080" -ForegroundColor White
        Write-Host ""
        Write-Host "  ⚠️  请妥善保管 .env 文件，不要提交到代码仓库" -ForegroundColor Yellow
        Write-Host ""
        
    } catch {
        Write-ErrorMsg "写入 .env 文件失败: $_"
        Write-Host ""
        Write-Host "  可能的原因:" -ForegroundColor Yellow
        Write-Host "  - 磁盘空间不足" -ForegroundColor Gray
        Write-Host "  - 文件权限问题" -ForegroundColor Gray
        Write-Host "  - 路径包含特殊字符" -ForegroundColor Gray
        Write-Host ""
    }
}

# 执行
Start-Main
