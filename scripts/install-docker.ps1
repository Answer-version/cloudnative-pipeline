# =========================================================
# CloudNative Pipeline - Docker Desktop 自动安装脚本
# 自动检测 WSL2、安装 Docker Desktop
# =========================================================

$ErrorActionPreference = "Continue"

# 颜色定义
function Write-Success { param($msg) Write-Host "[✅] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "[❌] $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "[⚠️]  $msg" -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host "[ℹ️]  $msg" -ForegroundColor Cyan }

# 检测管理员权限
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 检测 WSL2 是否安装
function Test-WSL2Installed {
    Write-Info "检测 WSL2..."
    try {
        $wsl = Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wsl) {
            return $false
        }
        
        $wslOutput = wsl --list --verbose 2>$null
        if ($wslOutput -match "docker-desktop") {
            Write-Success "WSL2 已配置"
            return $true
        }
        
        # 检查 WSL 版本
        $wslOutput = wsl --status 2>$null
        if ($wslOutput -match "默认版本: 2" -or $wslOutput -match "Default Version: 2") {
            Write-Success "WSL2 已安装"
            return $true
        }
        
        return $false
    } catch {
        return $false
    }
}

# 安装 WSL2
function Install-WSL2 {
    Write-Info "正在启用 WSL2..."
    
    if (-not (Test-AdminRights)) {
        Write-ErrorMsg "安装 WSL2 需要管理员权限"
        Write-Host ""
        Write-Host "  💡 请右键点击 PowerShell，选择「以管理员身份运行」" -ForegroundColor Yellow
        Write-Host "  然后重新执行此脚本" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "按 Enter 键退出"
        exit 1
    }
    
    try {
        # 启用 WSL 功能
        Write-Info "启用 Windows Subsystem for Linux..."
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
        
        # 启用虚拟机平台
        Write-Info "启用虚拟机平台..."
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
        
        # 设置 WSL2 为默认
        Write-Info "设置 WSL2 为默认版本..."
        wsl --set-default-version 2 2>$null | Out-Null
        
        Write-Success "WSL2 启用成功，需要重启电脑"
        Write-Host ""
        Write-Host "  ⚠️  请重启电脑后重新运行此脚本" -ForegroundColor Yellow
        Write-Host ""
        
        $restart = Read-Host "是否立即重启？(Y/N)"
        if ($restart -eq "Y" -or $restart -eq "y") {
            Restart-Computer -Force
        }
        
        exit 0
    } catch {
        Write-ErrorMsg "WSL2 安装失败: $_"
        return $false
    }
}

# 下载 Docker Desktop
function Get-DockerDesktop {
    Write-Info "正在下载 Docker Desktop..."
    
    $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $tempFile = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
    
    try {
        # 显示进度
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $tempFile)
        
        Write-Success "下载完成: $tempFile"
        return $tempFile
    } catch {
        Write-ErrorMsg "下载失败: $_"
        Write-Host ""
        Write-Host "  💡 请手动下载 Docker Desktop:" -ForegroundColor Yellow
        Write-Host "  https://www.docker.com/products/docker-desktop" -ForegroundColor Cyan
        Write-Host ""
        
        $open = Read-Host "是否打开下载页面？(Y/N)"
        if ($open -eq "Y" -or $open -eq "y") {
            Start-Process "https://www.docker.com/products/docker-desktop"
        }
        
        return $null
    }
}

# 安装 Docker Desktop
function Install-DockerDesktop {
    param([string]$InstallerPath)
    
    Write-Info "正在安装 Docker Desktop..."
    Write-Warn "安装过程可能需要几分钟，请耐心等待..."
    Write-Host ""
    
    try {
        # 执行安装
        $process = Start-Process -FilePath $InstallerPath -ArgumentList "install --quiet" -PassThru -Wait
        
        if ($process.ExitCode -eq 0) {
            Write-Success "Docker Desktop 安装完成"
            return $true
        } else {
            Write-ErrorMsg "Docker Desktop 安装失败 (退出码: $($process.ExitCode))"
            return $false
        }
    } catch {
        Write-ErrorMsg "安装过程出错: $_"
        return $false
    }
}

# 启动 Docker Desktop
function Start-DockerDesktopService {
    Write-Info "正在启动 Docker Desktop..."
    
    try {
        $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        
        if (-not (Test-Path $dockerPath)) {
            Write-ErrorMsg "未找到 Docker Desktop 安装路径"
            return $false
        }
        
        # 启动
        Start-Process $dockerPath -WindowStyle Hidden
        
        Write-Info "Docker Desktop 启动中..."
        Write-Host "  首次启动需要等待 WSL2 初始化..." -ForegroundColor Gray
        Write-Host ""
        
        # 等待就绪
        $maxWait = 180
        $waited = 0
        
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 5
            $waited += 5
            
            try {
                $dockerOk = docker info 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Docker Desktop 已就绪"
                    Write-Host ""
                    docker --version
                    return $true
                }
            } catch {
                # 继续等待
            }
            
            Write-Info "等待 Docker 启动... ($waited/$maxWait 秒)"
        }
        
        Write-Warn "Docker 启动超时，但可能已安装成功"
        Write-Host "  请手动启动 Docker Desktop 并检查状态" -ForegroundColor Gray
        return $false
        
    } catch {
        Write-ErrorMsg "启动 Docker Desktop 失败: $_"
        return $false
    }
}

# 主流程
function Start-Main {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       Docker Desktop 安装向导                         ║" -ForegroundColor Cyan
    Write-Host "  ║       自动检测并安装 Docker Desktop                   ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # 检测管理员权限
    Write-Info "检测管理员权限..."
    if (-not (Test-AdminRights)) {
        Write-ErrorMsg "需要管理员权限来安装 Docker Desktop"
        Write-Host ""
        Write-Host "  💡 请右键点击 PowerShell，选择「以管理员身份运行」" -ForegroundColor Yellow
        Write-Host "  然后重新执行: .\install-docker.ps1" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "按 Enter 键退出"
        exit 1
    }
    Write-Success "管理员权限确认"
    
    # 检测 WSL2
    Write-Host ""
    $wslInstalled = Test-WSL2Installed
    
    if (-not $wslInstalled) {
        Write-Host ""
        Write-ErrorMsg "WSL2 未安装，Docker Desktop 需要 WSL2"
        Write-Host ""
        Write-Host "  💡 是否自动安装 WSL2？" -ForegroundColor Yellow
        Write-Host ""
        
        $install = Read-Host "安装 WSL2 需要重启电脑 (Y/N)"
        
        if ($install -eq "Y" -or $install -eq "y") {
            Install-WSL2
        } else {
            Write-Host ""
            Write-Host "  请先安装 WSL2 后再运行此脚本" -ForegroundColor Yellow
            Write-Host "  手动安装: wsl --install" -ForegroundColor Gray
            Read-Host "按 Enter 键退出"
            exit 1
        }
    }
    
    # 检测是否已安装
    Write-Host ""
    Write-Info "检测 Docker Desktop 是否已安装..."
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    
    if (Test-Path $dockerPath) {
        Write-Success "Docker Desktop 已安装"
        
        $start = Read-Host "是否启动 Docker Desktop？(Y/N)"
        if ($start -eq "Y" -or $start -eq "y") {
            Start-DockerDesktopService
        }
    } else {
        # 下载并安装
        Write-Host ""
        Write-Info "开始安装 Docker Desktop..."
        Write-Host ""
        
        $installer = Get-DockerDesktop
        
        if ($installer) {
            Install-DockerDesktop -InstallerPath $installer
            
            # 清理安装包
            Remove-Item $installer -Force -ErrorAction SilentlyContinue
            
            # 启动
            Write-Host ""
            $start = Read-Host "安装完成，是否启动 Docker Desktop？(Y/N)"
            if ($start -eq "Y" -or $start -eq "y") {
                Start-DockerDesktopService
            }
        }
    }
    
    # 完成
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  🎉 Docker 安装流程完成!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  下一步: 运行 .\setup.ps1 继续环境配置" -ForegroundColor White
    Write-Host ""
    
    Read-Host "按 Enter 键退出"
}

# 执行
Start-Main
