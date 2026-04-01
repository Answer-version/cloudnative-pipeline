# 常见问题

> 遇到问题了吗？在这里找答案！

---

## Docker 相关

### 🐳 Docker 未安装怎么办？

**症状：** 双击启动脚本后，提示 "Docker not found" 或类似错误。

**解决方法：**

#### 方案一：安装 Docker Desktop（推荐）

1. 访问 [Docker 官网](https://www.docker.com/products/docker-desktop/)
2. 点击 "Download for Windows"
3. 双击下载的 `.exe` 安装包
4. 安装过程中勾选 **"Use WSL 2 instead of Hyper-V"**（推荐）
5. 安装完成后**重启电脑**
6. 启动 Docker Desktop，等待显示 🐳 图标

#### 方案二：使用 Chocolatey 安装

```powershell
# 以管理员身份打开 PowerShell
choco install docker-desktop -y
```

---

### 🚨 Docker 启动失败怎么办？

**症状：** Docker Desktop 无法启动，一直显示 "Starting..." 或报错。

**排查步骤：**

#### 1. 检查 WSL2 是否安装

```powershell
# 打开 PowerShell，运行：
wsl --status
```

如果显示 "WSL 2 安装未启用"，请运行：
```powershell
wsl --install
```

#### 2. 启用 WSL2 和虚拟机功能

以管理员身份打开 PowerShell，运行：

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

然后重启电脑。

#### 3. 设置 WSL2 为默认版本

```powershell
wsl --set-default-version 2
```

#### 4. 重置 Docker Desktop

1. 右键 Docker 图标 → Settings → "Reset to factory defaults"
2. 重启 Docker Desktop

---

### 🔌 端口被占用怎么办？

**症状：** 启动时报错 `EADDRINUSE`，提示某个端口被占用。

**常见占用端口：**

| 端口 | 常用服务 | 解决方案 |
|------|----------|----------|
| 8080 | ArgoCD、Web 服务 | 见下方 |
| 3000 | Grafana | 见下方 |
| 9090 | Prometheus | 见下方 |
| 6443 | Kubernetes API | 见下方 |

**解决方法：**

#### 步骤 1：查找占用程序

打开 PowerShell（管理员），运行：

```powershell
# 检查 8080 端口
netstat -ano | findstr :8080

# 检查 3000 端口
netstat -ano | findstr :3000
```

记下最后一列的数字（PID）。

#### 步骤 2：结束占用进程

```powershell
# 假设 PID 是 12345
taskkill /PID 12345 /F
```

#### 步骤 3：或者修改本项目端口

编辑 `docker-compose.yml` 或 `k8s/values.yaml`：

```yaml
services:
  argocd:
    ports:
      - "9080:8080"  # 改为 9080
```

---

## 应用相关

### 🌐 应用无法访问怎么办？

**症状：** 浏览器打开 `http://localhost:8080` 显示 "无法访问"。

**排查顺序：**

#### 1. 确认服务是否启动

```powershell
# 检查 Docker 容器状态
docker ps

# 应该看到类似输出：
# CONTAINER ID   IMAGE                 STATUS
# xxx            argocd/argocd         Up 2 minutes
# xxx            grafana/grafana       Up 2 minutes
```

#### 2. 查看容器日志

```powershell
# 查看 ArgoCD 日志
docker logs <argocd-container-id>

# 持续跟踪日志
docker logs -f <argocd-container-id>
```

#### 3. 检查端口映射

```powershell
# 查看端口映射
docker port <container-id>
```

#### 4. 重启服务

```powershell
# 重启所有容器
docker-compose down
docker-compose up -d
```

---

### 🗄️ 数据库连接失败怎么办？

**症状：** 应用报错 `Connection refused` 或 `Database unavailable`。

**原因分析：**
- PostgreSQL/MySQL 容器未启动
- 连接信息配置错误
- 磁盘空间不足

**解决方法：**

#### 1. 检查数据库容器

```powershell
docker ps -a | grep -E "postgres|mysql|mariadb"
```

#### 2. 启动数据库容器

```powershell
docker start <database-container-id>
```

#### 3. 检查连接配置

编辑配置文件，确认数据库地址、端口、账号密码：

```yaml
# docker-compose.yml
database:
  image: postgres:15
  environment:
    POSTGRES_PASSWORD: mysecretpassword
    POSTGRES_DB: appdb
```

#### 4. 测试连接

```powershell
# 进入数据库容器
docker exec -it <container-id> psql -U postgres -d appdb

# 测试连接
SELECT 1;
```

---

## 网络相关

### 🔀 WSL2 问题

#### WSL2 导致 Docker 运行缓慢

**解决方法：**

1. 创建 `.wslconfig` 文件：
   ```
   # 文件位置：C:\Users\<你的用户名>\.wslconfig
   ```

2. 添加以下内容：
   ```ini
   [wsl2]
   memory=4GB
   processors=2
   localhostForwarding=true
   ```

3. 重启 WSL：
   ```powershell
   wsl --shutdown
   ```

#### WSL2 与 Docker 冲突

**症状：** Docker Desktop 报错 "WSL2 installation is incomplete"

**解决方法：**

```powershell
# 卸载并重新安装 WSL
wsl --unregister Ubuntu
wsl --install -d Ubuntu
```

---

### 🔥 防火墙问题

#### Windows 防火墙阻止访问

**症状：** 部分服务可以访问，部分不行。

**解决方法：**

#### 方案一：关闭防火墙（不推荐用于生产环境）

```powershell
# 临时关闭防火墙
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

#### 方案二：添加防火墙规则（推荐）

```powershell
# 允许指定端口
New-NetFirewallRule -DisplayName "Allow ArgoCD" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow

New-NetFirewallRule -DisplayName "Allow Grafana" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow

New-NetFirewallRule -DisplayName "Allow Prometheus" -Direction Inbound -Protocol TCP -LocalPort 9090 -Action Allow
```

#### 确认防火墙规则已添加

```powershell
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*ArgoCD*"}
```

---

### 🌏 代理/VPN 干扰

**症状：** Docker 下载镜像极慢或失败。

**解决方法：**

#### 1. 配置 Docker 镜像加速

编辑 Docker Desktop 设置 → Docker Engine，添加：

```json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
```

#### 2. 如使用 VPN

先关闭 VPN，再尝试启动 Docker。

#### 3. 设置代理

```json
{
  "proxies": {
    "http-proxy": "http://127.0.0.1:7890",
    "https-proxy": "http://127.0.0.1:7890"
  }
}
```

---

## 其他常见问题

### 💾 磁盘空间不足

**症状：** Docker 报错 "no space left on device"

**解决方法：**

```powershell
# 清理 Docker 构建缓存
docker builder prune -af

# 清理未使用的镜像
docker image prune -af

# 清理已停止的容器
docker container prune -f

# 清理卷
docker volume prune -f

# 清理所有未使用的资源（一键清理）
docker system prune -af
```

### ⏰ 启动超时

**症状：** 启动脚本运行超过 10 分钟未完成。

**解决方法：**

1. 按 `Ctrl+C` 中止
2. 运行清理脚本：
   ```powershell
   docker-compose down
   docker system prune -f
   ```
3. 重新双击启动

### 🔄 服务状态不一致

**症状：** ArgoCD 显示应用 OutOfSync。

**解决方法：**

1. 打开 ArgoCD UI
2. 点击目标应用
3. 点击 "Sync" 按钮
4. 选择 "Synchronize"

---

## 需要更多帮助？

| 问题类型 | 联系方式 |
|----------|----------|
| Bug 反馈 | [GitHub Issues](https://github.com/your-org/cloudnative-pipeline/issues) |
| 功能建议 | [GitHub Discussions](https://github.com/your-org/cloudnative-pipeline/discussions) |
| 文档纠错 | 提交 PR 到本仓库 |

---

**找不到答案？** [提交 Issue](https://github.com/your-org/cloudnative-pipeline/issues/new) 告诉我们！
