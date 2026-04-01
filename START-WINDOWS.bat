@echo off
chcp 65001 >nul
title CloudNative Pipeline - 安装向导

echo.
echo  ╔══════════════════════════════════════════════════════╗
echo  ║       CloudNative Pipeline - Windows 一键安装        ║
echo  ║       云原生流水线 - 自动环境配置                     ║
echo  ╚══════════════════════════════════════════════════════╝
echo.

REM 检查 PowerShell 是否可用
where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 未找到 PowerShell，请升级 Windows 系统
    pause
    exit /b 1
)

REM 检查是否以管理员运行
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [提示] 建议以管理员身份运行以获得最佳体验
    echo.
)

REM 获取脚本目录
set SCRIPT_DIR=%~dp0scripts

REM 检查脚本是否存在
if not exist "%SCRIPT_DIR%\setup.ps1" (
    echo [错误] 找不到 setup.ps1 脚本
    echo 请确保脚本文件位于 scripts 目录下
    pause
    exit /b 1
)

echo [信息] 准备启动环境检测向导...
echo.
echo ------------------------------------------------------------
echo  操作说明:
echo  1. 脚本将检测 Docker、kubectl、helm 等工具
echo  2. 未安装的工具会提供安装选项
echo  3. 完成后自动生成配置文件
echo ------------------------------------------------------------
echo.

REM 询问是否继续
set /p CONTINUE="是否继续？(Y/N): "
if /i not "%CONTINUE%"=="Y" (
    echo 已取消
    pause
    exit /b 0
)

echo.
echo [信息] 启动 PowerShell 环境检测...
echo.

REM 启动 PowerShell 脚本
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\setup.ps1"

echo.
echo [完成] 安装向导已退出
pause
