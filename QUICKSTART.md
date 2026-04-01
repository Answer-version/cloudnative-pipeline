# 5分钟快速开始

> ⏱️ 即使你完全不懂 Kubernetes，也能轻松上手！

---

## 第一步：下载项目

### 1.1 下载压缩包

访问 [GitHub Releases](https://github.com/your-org/cloudnative-pipeline/releases) 页面，下载最新版本的 `cloudnative-pipeline-windows.zip`。

![下载 Release](images/download-release.png)

### 1.2 解压文件

右键点击下载的 `cloudnative-pipeline-windows.zip`，选择「全部解压缩」。

![解压文件](images/extract-zip.png)

### 1.3 确认文件结构

解压后，打开文件夹，确认包含以下文件：

```
cloudnative-pipeline/
├── START-WINDOWS.bat      ← 双击这个启动！
├── docker/                 ← Docker 配置
├── k8s/                    ← Kubernetes 配置
├── monitoring/             ← 监控组件
└── scripts/                ← 辅助脚本
```

---

## 第二步：双击启动

### 2.1 检查 Docker 是否运行

启动前，请确认 Docker Desktop 已经启动：

1. 在 Windows 搜索栏中输入 **"Docker Desktop"**
2. 按回车启动
3. 等待 Docker 图标显示为 🐳（不再转动）

![Docker 运行状态](images/docker-running.png)

> ⚠️ 如果看到 "Docker Desktop is starting..."，请耐心等待 1-2 分钟。

### 2.2 双击启动脚本

找到 `START-WINDOWS.bat`，**双击它**！

![双击启动脚本](images/click-start.png)

### 2.3 等待启动完成

黑色窗口会显示启动进度，请耐心等待 **3-5 分钟**。

✅ **启动成功的标志：**
```
🚀 所有服务启动完成！
🌐 访问 http://localhost:8080 开始使用
```

![启动成功](images/start-success.png)

> 💡 如果窗口关闭或卡住超过 5 分钟，请参考 [常见问题](TROUBLESHOOTING.md)。

---

## 第三步：访问服务

### 3.1 打开浏览器

打开 Chrome、Edge 或 Firefox 浏览器。

### 3.2 访问 ArgoCD 控制台

在地址栏输入：

```
http://localhost:8080
```

![ArgoCD 登录页面](images/argocd-login.png)

### 3.3 登录账号

| 账号 | 密码 |
|------|------|
| `admin` | `admin` |

> 🔒 登录后建议修改密码，参考 [常见问题](TROUBLESHOOTING.md)

### 3.4 查看所有服务

恭喜！🎉 你已经成功启动了云原生流水线！

访问其他服务：

| 服务 | 地址 | 用途 |
|------|------|------|
| **ArgoCD** | http://localhost:8080 | 部署管理（主要控制台） |
| **Grafana** | http://localhost:3000 | 监控面板 |
| **Prometheus** | http://localhost:9090 | 指标查询 |
| **示例应用** | http://localhost:8081 | 演示微服务 |

---

## 常见问题

### ❓ 启动脚本报错 "Docker not found"

**原因：** Docker 没有安装或没有启动。

**解决方法：**
1. 打开 Windows 应用商店，搜索 "Docker Desktop"
2. 下载安装后重启电脑
3. 启动 Docker Desktop，等待图标稳定

---

### ❓ 启动后 ArgoCD 打不开

**原因：** 服务还没完全启动。

**解决方法：**
1. 等待 2 分钟后再试
2. 刷新浏览器
3. 重启启动脚本（先关掉，再双击）

---

### ❓ 端口被占用

**常见报错：**
```
Error: listen EADDRINUSE :::8080
```

**解决方法：**
1. 打开 PowerShell（管理员）
2. 运行以下命令查看占用端口的程序：
   ```powershell
   netstat -ano | findstr :8080
   ```
3. 关闭对应程序，或修改 `docker-compose.yml` 中的端口

---

## 下一步

### 📚 继续学习

- 🏗️ [完整架构说明](README.md#架构图) - 了解各组件如何协作
- 📊 [监控系统使用](README.md#监控与日志) - Grafana 图表解读
- 🔄 [GitOps 部署](README.md#gitops-部署流程) - 代码提交自动部署

### 🛠️ 常用操作

| 操作 | 命令 |
|------|------|
| 重启所有服务 | 双击 `START-WINDOWS.bat` |
| 查看运行状态 | 访问 http://localhost:8080 |
| 停止服务 | 在启动窗口按 `Ctrl+C` |

### 🆘 获取帮助

- 📖 查看 [常见问题排查](TROUBLESHOOTING.md)
- 🐛 提交 [Issue](https://github.com/your-org/cloudnative-pipeline/issues)
- 💬 加入讨论群

---

**享受你的云原生开发之旅！** 🚀
