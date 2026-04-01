# =========================================================
# CloudNative Pipeline - 快速安装脚本 (静默模式)
# 自动检测并安装所有必需工具
# =========================================================

param(
    [switch]$SkipConfirmation
)

$ErrorActionPreference = "Continue"

# 颜色定义
function Write-Success { param($msg) Write-Host "[✅] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "[❌] $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "[⚠️]  $msg" -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host "[ℹ️]  $msg" -ForegroundColor Cyan }

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       CloudNative Pipeline - 快速安装模式            ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 生成随机密码
function Generate-SecurePassword {
    param([int]$Length = 24)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 1
        $random.GetBytes($bytes)
        $result += $chars[$bytes[0] % $chars.Length]
    }
    return $result
}

# 检测 Docker
Write-Info "检测 Docker..."
$dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerInstalled) {
    $dockerRunning = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker 已安装并运行"
    } else {
        Write-Warn "Docker 已安装但未运行，尝试启动..."
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden
        Start-Sleep -Seconds 30
    }
} else {
    Write-ErrorMsg "Docker 未安装"
    Write-Host "  运行 install-docker.ps1 安装 Docker Desktop" -ForegroundColor Gray
}

# 检测 kubectl
Write-Info "检测 kubectl..."
$kubectlInstalled = Get-Command kubectl -ErrorAction SilentlyContinue
if ($kubectlInstalled) {
    Write-Success "kubectl 已安装"
} else {
    Write-Warn "kubectl 未安装，自动安装中..."
    try {
        $kubectlUrl = "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
        $outFile = "$env:TEMP\kubectl.exe"
        Invoke-WebRequest -Uri $kubectlUrl -OutFile $outFile -UseBasicParsing
        $destDir = "C:\Program Files\Kubernetes\kubectl"
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item $outFile -Destination $destDir -Force
        Remove-Item $outFile -Force
        $env:Path += ";$destDir"
        Write-Success "kubectl 安装完成"
    } catch {
        Write-ErrorMsg "kubectl 安装失败"
    }
}

# 检测 helm
Write-Info "检测 Helm..."
$helmInstalled = Get-Command helm -ErrorAction SilentlyContinue
if ($helmInstalled) {
    Write-Success "Helm 已安装"
} else {
    Write-Warn "Helm 未安装，自动安装中..."
    try {
        $helmUrl = "https://get.helm.sh/helm-v3.12.0-windows-amd64.zip"
        $outFile = "$env:TEMP\helm.zip"
        $extractDir = "$env:TEMP\helm"
        Invoke-WebRequest -Uri $helmUrl -OutFile $outFile -UseBasicParsing
        Expand-Archive -Path $outFile -DestinationPath $extractDir -Force
        $destDir = "C:\Program Files\Helm"
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item "$extractDir\windows-amd64\helm.exe" -Destination $destDir -Force
        Remove-Item $outFile -Force
        Remove-Item $extractDir -Recurse -Force
        $env:Path += ";$destDir"
        Write-Success "Helm 安装完成"
    } catch {
        Write-ErrorMsg "Helm 安装失败"
    }
}

# 生成 .env
Write-Host ""
Write-Info "生成配置文件..."
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot ".env"

$dbPassword = Generate-SecurePassword
$redisPassword = Generate-SecurePassword

$envContent = @"
# CloudNative Pipeline - 本地配置
# 自动生成，请勿手动修改

APP_PORT=8080
APP_ENV=development
DB_PASSWORD=$dbPassword
REDIS_PASSWORD=$redisPassword
"@

Set-Content -Path $envFile -Value $envContent -Encoding UTF8
Write-Success ".env 文件已生成"

# 总结
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  🎉 快速安装完成!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  运行 docker-compose up -d 启动服务" -ForegroundColor White
Write-Host "  访问 http://localhost:8080" -ForegroundColor White
Write-Host ""
