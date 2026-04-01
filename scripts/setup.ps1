# =========================================================
# CloudNative Pipeline - Windows 环境检测与安装脚本
# 自动检测 Docker Desktop、kubectl、helm 等工具
# =========================================================

param(
    [switch]$AutoInstall,
    [switch]$SkipDocker,
    [switch]$SkipK8sTools
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# 颜色定义
function Write-Success { param($msg) Write-Host "[✅] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "[❌] $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "[⚠️]  $msg" -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host "[ℹ️]  $msg" -ForegroundColor Cyan }

# 打印标题
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       CloudNative Pipeline - 环境检测向导            ║" -ForegroundColor Cyan
    Write-Host "  ║       自动检测并安装所需工具                          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# 检测网络连接
function Test-NetworkConnectivity {
    Write-Info "检测网络连接..."
    try {
        $response = Invoke-WebRequest -Uri "https://www.docker.com" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Success "网络连接正常"
            return $true
        }
    } catch {
        Write-Warn "网络连接可能受限，部分下载可能失败"
        return $false
    }
}

# 检测 Docker Desktop 是否安装
function Test-DockerInstalled {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        $dockerVersion = docker --version 2>$null
        Write-Success "Docker 已安装: $dockerVersion"
        return $true
    }
    
    # 检查注册表
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $dockerApp = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Docker*" }
    if ($dockerApp) {
        Write-Success "Docker 已安装: $($dockerApp.DisplayName)"
        return $true
    }
    
    return $false
}

# 检测 Docker 是否运行
function Test-DockerRunning {
    try {
        $result = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker 服务正在运行"
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# 启动 Docker Desktop
function Start-DockerDesktop {
    Write-Info "正在启动 Docker Desktop..."
    try {
        $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath -WindowStyle Hidden
            Write-Info "Docker Desktop 启动中，请等待..."
            
            # 等待 Docker 就绪
            $maxWait = 120
            $waited = 0
            while ($waited -lt $maxWait) {
                Start-Sleep -Seconds 3
                $waited += 3
                if (Test-DockerRunning) {
                    Write-Success "Docker Desktop 已就绪"
                    return $true
                }
                Write-Info "等待 Docker 启动... ($waited/$maxWait 秒)"
            }
            
            Write-Warn "Docker 启动超时，请手动检查 Docker Desktop 是否正常"
            return $false
        } else {
            Write-ErrorMsg "未找到 Docker Desktop 安装路径"
            return $false
        }
    } catch {
        Write-ErrorMsg "启动 Docker Desktop 失败: $_"
        return $false
    }
}

# 检测 kubectl 是否安装
function Test-KubectlInstalled {
    $kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
    if ($kubectl) {
        $version = kubectl version --client 2>$null | Select-String -Pattern "\d+\.\d+\.\d+" -AllMatches
        Write-Success "kubectl 已安装"
        return $true
    }
    Write-Warn "kubectl 未安装"
    return $false
}

# 检测 helm 是否安装
function Test-HelmInstalled {
    $helm = Get-Command helm -ErrorAction SilentlyContinue
    if ($helm) {
        $version = helm version --short 2>$null
        Write-Success "helm 已安装: $version"
        return $true
    }
    Write-Warn "helm 未安装"
    return $false
}

# 安装 kubectl
function Install-Kubectl {
    Write-Info "正在安装 kubectl..."
    try {
        $kubectlUrl = "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
        $tempDir = $env:TEMP
        $outFile = Join-Path $tempDir "kubectl.exe"
        
        Write-Info "下载 kubectl..."
        Invoke-WebRequest -Uri $kubectlUrl -OutFile $outFile -UseBasicParsing
        
        $destDir = "C:\Program Files\Kubernetes\kubectl"
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item $outFile -Destination $destDir -Force
        Remove-Item $outFile -Force
        
        # 添加到 PATH
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$destDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$destDir", "User")
            $env:Path += ";$destDir"
        }
        
        Write-Success "kubectl 安装成功"
        return $true
    } catch {
        Write-ErrorMsg "kubectl 安装失败: $_"
        return $false
    }
}

# 安装 helm
function Install-Helm {
    Write-Info "正在安装 helm..."
    try {
        $helmUrl = "https://get.helm.sh/helm-v3.12.0-windows-amd64.zip"
        $tempDir = $env:TEMP
        $outFile = Join-Path $tempDir "helm.zip"
        $extractDir = Join-Path $tempDir "helm"
        
        Write-Info "下载 helm..."
        Invoke-WebRequest -Uri $helmUrl -OutFile $outFile -UseBasicParsing
        
        # 解压
        if (Test-Path $extractDir) {
            Remove-Item $extractDir -Recurse -Force
        }
        Expand-Archive -Path $outFile -DestinationPath $extractDir -Force
        
        $destDir = "C:\Program Files\Helm"
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item "$extractDir\windows-amd64\helm.exe" -Destination $destDir -Force
        Remove-Item $outFile -Force
        Remove-Item $extractDir -Recurse -Force
        
        # 添加到 PATH
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$destDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$destDir", "User")
            $env:Path += ";$destDir"
        }
        
        Write-Success "helm 安装成功"
        return $true
    } catch {
        Write-ErrorMsg "helm 安装失败: $_"
        return $false
    }
}

# 主流程
function Start-Main {
    Show-Banner
    
    # 检测网络
    $networkOk = Test-NetworkConnectivity
    if (-not $networkOk) {
        Write-Warn "建议检查网络连接后重试"
    }
    
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "  开始环境检测..." -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    # Docker 检测
    if (-not $SkipDocker) {
        $dockerInstalled = Test-DockerInstalled
        
        if (-not $dockerInstalled) {
            Write-Host ""
            Write-ErrorMsg "Docker Desktop 未安装!"
            Write-Host ""
            Write-Host "  💡 请选择操作:" -ForegroundColor Yellow
            Write-Host "     1. 自动下载并安装 Docker Desktop" -ForegroundColor White
            Write-Host "     2. 稍后手动安装（脚本将继续检测其他工具）" -ForegroundColor White
            Write-Host ""
            
            if ($AutoInstall) {
                $choice = "1"
            } else {
                $choice = Read-Host "请选择 (1/2，默认2)"
            }
            
            if ($choice -eq "1") {
                Write-Info "正在启动 Docker 安装程序..."
                & "$PSScriptRoot\install-docker.ps1"
                
                # 重新检测
                if (Test-DockerInstalled) {
                    Write-Success "Docker 安装完成，正在启动..."
                    Start-DockerDesktop
                }
            } else {
                Write-Info "提示: 从 https://www.docker.com/products/docker-desktop 下载 Docker Desktop"
                Start-Process "https://www.docker.com/products/docker-desktop"
            }
        } else {
            # Docker 已安装，检测是否运行
            if (-not (Test-DockerRunning)) {
                Write-Warn "Docker 已安装但未运行"
                $startChoice = Read-Host "是否自动启动 Docker Desktop？(Y/N)"
                if ($startChoice -eq "Y" -or $startChoice -eq "y") {
                    Start-DockerDesktop
                }
            }
        }
    }
    
    # Kubernetes 工具检测
    if (-not $SkipK8sTools) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "  检测 Kubernetes 工具..." -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
        
        $kubectlInstalled = Test-KubectlInstalled
        if (-not $kubectlInstalled) {
            Write-Host ""
            Write-Host "  💡 kubectl 是 Kubernetes 命令行工具" -ForegroundColor Yellow
            $install = Read-Host "是否自动安装 kubectl？(Y/N)"
            if ($install -eq "Y" -or $install -eq "y") {
                Install-Kubectl
            }
        }
        
        Write-Host ""
        $helmInstalled = Test-HelmInstalled
        if (-not $helmInstalled) {
            Write-Host ""
            Write-Host "  💡 Helm 是 Kubernetes 包管理器" -ForegroundColor Yellow
            $install = Read-Host "是否自动安装 Helm？(Y/N)"
            if ($install -eq "Y" -or $install -eq "y") {
                Install-Helm
            }
        }
    }
    
    # 生成 .env 文件
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "  生成配置文件..." -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    & "$PSScriptRoot\env-setup.ps1"
    
    # 总结
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  🎉 环境检测完成!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  下一步:" -ForegroundColor White
    Write-Host "  1. 确保 Docker 正在运行" -ForegroundColor Gray
    Write-Host "  2. 运行 docker-compose up -d 启动服务" -ForegroundColor Gray
    Write-Host "  3. 访问 http://localhost:8080" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  查看帮助: Get-Help .\setup.ps1 -Detailed" -ForegroundColor Gray
    Write-Host ""
    
    # 保持窗口
    if (-not $AutoInstall) {
        Write-Host "按任意键退出..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# 执行
Start-Main
