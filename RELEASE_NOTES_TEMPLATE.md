# CloudNative Pipeline Release Notes

## 📦 版本信息 / Version Information

| 项目 | 内容 |
|------|------|
| **版本号** | {{VERSION}} |
| **发布日期** | {{RELEASE_DATE}} |
| **发布类型** | Windows 便携版 (Portable) |
| **校验文件** | SHA256SUMS.txt |

---

## 💻 系统要求 / System Requirements

| 组件 | 最低要求 | 推荐配置 |
|------|---------|---------|
| 操作系统 | Windows 10 (1903+) / Windows Server 2019+ | Windows 11 / Windows Server 2022 |
| 内存 | 8 GB RAM | 16 GB RAM 或以上 |
| 磁盘空间 | 10 GB 可用 | 20 GB 或以上 |
| Docker | Docker Desktop ≥ 4.20 | 最新稳定版 |
| 网络 | 稳定的互联网连接 | 宽带网络 |

### 前置依赖

- [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) (已包含 Docker Compose)
- WSL 2 后端（Docker Desktop 设置中启用）
- PowerShell 5.1 或更高版本

---

## 📥 安装步骤 / Installation

### 第一步：下载与解压

1. 下载 `cloudnative-pipeline-{{VERSION}}-windows.zip`
2. 解压到常用目录，例如：`C:\Apps\cloudnative-pipeline`

> **截图占位符 1**: 下载页面截图
> ![下载页面](./docs/screenshots/download-page.png)

### 第二步：配置环境

1. 进入解压目录
2. 复制配置文件：
   ```cmd
   copy .env.example .env
   ```
3. 编辑 `.env` 文件，填入你的配置

> **截图占位符 2**: .env 配置截图
> ![配置文件](./docs/screenshots/config-env.png)

### 第三步：启动服务

双击运行 `START-WINDOWS.bat`，或用 PowerShell 执行：

```powershell
.\START-WINDOWS.bat
```

> **截图占位符 3**: 启动成功截图
> ![启动成功](./docs/screenshots/startup-success.png)

### 验证安装

访问以下地址确认服务正常运行：

| 服务 | 地址 |
|------|------|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Jaeger | http://localhost:16686 |
| Argo CD | http://localhost:8080 |
| Tekton Dashboard | http://localhost:9097 |

> **截图占位符 4**: 服务状态截图
> ![服务状态](./docs/screenshots/services-running.png)

---

## 🆕 更新内容 / What's New

<!-- 每次发布时填写 -->

### {{VERSION}}

- (请填写更新内容)

---

## 🐛 已知问题 / Known Issues

| Issue | 说明 | 状态 |
|-------|------|------|
| WSL2 内存占用 | Docker Desktop WSL2 后端默认占用较高内存 | 已知 |
| 防火墙阻止 | Windows 防火墙可能阻止容器间通信 | 已知 |

### 临时解决方案

#### WSL2 内存限制

在 `%USERPROFILE%\.wslconfig` 中添加：

```ini
[wsl2]
memory=4GB
processors=2
```

#### 防火墙配置

以管理员身份运行 PowerShell：

```powershell
New-NetFirewallRule -DisplayName "CloudNative Pipeline" `
  -Direction Inbound -Protocol TCP `
  -LocalPort 3000,8080,9090,9097,16686 `
  -Action Allow -Profile Any
```

---

## 🔧 故障排除 / Quick Fixes

| 问题 | 解决方案 |
|------|---------|
| Docker 未启动 | 启动 Docker Desktop 并等待 WSL2 就绪 |
| 端口冲突 | 检查 `docker-compose.yml` 修改端口映射 |
| 启动闪退 | 以管理员权限运行 PowerShell 执行脚本 |

详细故障排除请参考 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)。

---

## 📚 相关文档

- [📖 完整安装指南](./README.md)
- [🚀 快速开始](./QUICKSTART.md)
- [🔧 故障排除](./TROUBLESHOOTING.md)

---

## 🙏 致谢 / Credits

CloudNative Pipeline 由开源社区驱动。

---

_此发布包由 GitHub Actions 自动构建生成_
_Built with ❤️ by CloudNative Pipeline Team_
