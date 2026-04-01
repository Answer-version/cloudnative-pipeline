# 云原生流水线重构计划 v2.0

## 问题分析

### 当前项目问题（本质）
```
1. 门槛过高: 需要 Docker Desktop + K3s + Tekton + ArgoCD
2. 配置复杂: 60+ 配置文件，依赖关系不清晰
3. Windows 不友好: 脚本多为 Bash，Windows 需要 WSL
4. 零基础用户无法快速上手
5. 缺少本地开发模式
```

### 重构目标
```
为小白用户提供"零配置"的云原生开发体验
同时保留进阶用户的完整功能
```

---

## 重构方案

### 提供两种安装模式

#### 模式一：Docker Compose 单机版（小白推荐）
```
✅ 无需 Kubernetes
✅ 一键安装
✅ 开箱即用
✅ Windows 原生支持
✅ 包含: App + PostgreSQL + Redis + Prometheus + Grafana + Loki
```

#### 模式二：完整 K8s 云原生版（进阶用户）
```
✅ 分布式架构
✅ Tekton CI/CD
✅ ArgoCD GitOps
✅ 生产级部署
```

---

## 重构后的目录结构

```
cloudnative-pipeline/
├── README.md                      # 入门指南
├── START-WINDOWS.bat             # Windows 一键启动脚本 ⭐
├── START-MAC.sh                   # Mac/Linux 一键启动脚本
├── docker-compose.yml             # 单机版配置 ⭐
├── docker-compose.prod.yml        # 生产版配置
├── .env.example                  # 环境变量模板
├── .env                          # 本地配置（自动生成）
│
├── # 快速开始文档
├── QUICKSTART.md                 # 5分钟快速开始 ⭐
├── INSTALL-DOCKER.md             # Docker 安装指南
├── INSTALL-K8S.md               # K8s 安装指南（进阶）
├── TROUBLESHOOTING.md            # 常见问题 ⭐
│
├── # 源代码
├── app/                          # 应用源码
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── k8s/                         # K8s 配置（完整版）
├── tekton/                       # Tekton CI/CD（完整版）
├── argocd/                       # ArgoCD GitOps（完整版）
│
├── # 监控配置
├── monitoring/
│   ├── docker/                   # Docker Compose 监控栈
│   └── k8s/                     # K8s 监控栈
│
├── # 脚本
├── scripts/
│   ├── install-docker.ps1        # Windows Docker 安装脚本 ⭐
│   ├── install-k8s.ps1           # Windows K3s 安装脚本
│   ├── setup.ps1                 # Windows 环境设置 ⭐
│   └── quickstart.sh             # Linux/Mac 快速安装
│
└── # 文档
├── docs/
    ├── ARCHITECTURE.md           # 架构文档
    ├── DEVELOPMENT.md            # 开发指南
    └── DEPLOYMENT.md            # 部署文档
```

---

## 核心改进

### 1. Windows 一键启动
```batch
# START-WINDOWS.bat
@echo off
echo 欢迎使用云原生流水线
echo 正在检查环境...
call scripts\setup.ps1
docker-compose up -d
echo 安装完成！访问 http://localhost:3000
pause
```

### 2. 环境自动检测
```powershell
# scripts/setup.ps1
# 自动检测并安装：
# - Docker Desktop
# - Kubernetes (可选)
# - kubectl
# - Helm
# - 其他必要工具
```

### 3. 零配置运行
```yaml
# .env 自动生成
APP_PORT=8080
DB_PASSWORD=auto-generated-secure-password
REDIS_PASSWORD=auto-generated-secure-password
```

### 4. 渐进式文档
```
QUICKSTART.md      → 5分钟上手（必读）
TROUBLESHOOTING.md → 常见问题解决方案
INSTALL-DOCKER.md  → Docker 安装详解
ARCHITECTURE.md    → 架构设计理解
DEVELOPMENT.md     → 本地开发指南
```

---

## 执行计划

### Phase 1: 简化 Docker Compose 配置
- [x] 重写 docker-compose.yml
- [x] 添加 Windows 启动脚本
- [x] 环境变量模板
- [x] 自动配置生成

### Phase 2: 创建 Windows 一键安装包
- [x] START-WINDOWS.bat
- [x] scripts/setup.ps1
- [x] scripts/install-docker.ps1

### Phase 3: 完善文档
- [x] QUICKSTART.md
- [x] TROUBLESHOOTING.md
- [x] README.md 更新

### Phase 4: 代码审查 & Bug修复
- [ ] 完整代码审查
- [ ] Bug 修复
- [ ] 回归测试

### Phase 5: Windows Release 打包
- [ ] 创建 release 打包脚本
- [ ] 生成 Windows 可执行文件
- [ ] GitHub Release 发布

---

## 用户旅程

### 小白用户路径
```
1. 下载 release 包
2. 双击 START-WINDOWS.bat
3. 自动安装 Docker（如果没有）
4. 自动启动所有服务
5. 浏览器访问 http://localhost:3000
6. 完成！
```

### 进阶用户路径
```
1. 阅读 ARCHITECTURE.md
2. 阅读 INSTALL-K8S.md
3. 使用 K8s 版本部署
4. 配置 Tekton + ArgoCD
5. 完整云原生体验
```

---

版本: v2.0
更新日期: 2026-04-01
