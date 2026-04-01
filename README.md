# CloudNative Pipeline - 云原生流水线开发环境

## 一句话介绍

开箱即用的云原生开发环境，包含 K8s、CI/CD、GitOps、监控日志，一键部署即可拥有完整的云原生开发流水线。

---

## 特性列表

- ✅ **K3s** 轻量级 Kubernetes，单节点开发环境首选
- ✅ **Tekton** Cloud Native CI，原生 Kubernetes CI/CD 框架
- ✅ **ArgoCD** GitOps CD，声明式持续交付
- ✅ **Prometheus + Grafana** 监控，自定义告警规则
- ✅ **Loki** 日志聚合，告别 kubectl logs
- ✅ **示例 Go 微服务** 开箱即用的演示应用

---

## 快速开始

### 前置要求

| 工具 | 版本 | 说明 |
|------|------|------|
| Docker | ≥ 20.10 | 容器运行时 |
| K3s CLI (kubectl) | ≥ 1.25 | Kubernetes CLI |
| K3s | 已安装或使用脚本自动安装 | 轻量级 K8s 发行版 |

### 一键安装

```bash
# 克隆项目
git clone https://github.com/your-org/cloudnative-pipeline.git
cd cloudnative-pipeline

# 运行快速开始脚本
bash scripts/quickstart.sh
```

或手动安装：

```bash
# 安装 K3s
curl -sfL https://get.k3s.io | sh -

# 部署所有组件
kubectl apply -f manifests/
kubectl apply -f monitoring/
kubectl apply -f tekton/
kubectl apply -f argocd/
```

### 访问地址

| 服务 | 地址 | 默认账号 |
|------|------|----------|
| ArgoCD UI | http://localhost:8080 | admin / admin |
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| Tekton Dashboard | http://localhost:9097 | - |
| Loki | http://localhost:3100 | - |
| Example App | http://localhost:8081 | - |

---

## 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        开发本地环境                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                  │
│  │  VSCode  │───▶│   Git    │───▶│  GitHub  │                  │
│  └──────────┘    └──────────┘    └──────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        CI 层 (Tekton)                           │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                  │
│  │ Pipeline │───▶│  Build   │───▶│  Push    │                  │
│  │  Trigger │    │ (Kaniko) │    │ (Registry)│                  │
│  └──────────┘    └──────────┘    └──────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              CD 层 (ArgoCD) + K8s 层 (K3s)                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐   │
│  │ ArgoCD   │───▶│  Deploy  │───▶│ Example  │───▶│  Ingress │   │
│  │ (GitOps) │    │  to K8s  │    │   App    │    │ Controller│   │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────┐
                    ▼                       ▼                   ▼
         ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
         │    Prometheus    │   │     Grafana      │   │       Loki       │
         │   (监控指标)      │   │   (可视化面板)    │   │    (日志聚合)     │
         └──────────────────┘   └──────────────────┘   └──────────────────┘
```

**数据流向：**

1. **代码提交** → GitHub Webhook → Tekton Trigger
2. **CI 执行** → Kaniko 构建镜像 → 推送到镜像仓库
3. **GitOps 同步** → ArgoCD 检测镜像更新 → 部署到 K3s
4. **监控采集** → Prometheus 抓取指标 → Grafana 可视化
5. **日志收集** → Promtail 采集 → Loki 聚合查询

---

## 组件说明

### K3s

轻量级 Kubernetes 发行版，适合本地开发和 CI 环境。

- **版本：** v1.28+
- **端口：** 6443 (API Server)
- **Kubeconfig：** `~/.kube/config`

### Tekton

Kubernetes 原生 CI/CD 框架，Pipeline 即代码。

| 组件 | 说明 |
|------|------|
| tekton-pipelines | 核心 CRD 和控制器 |
| tekton-triggers | 事件驱动触发器 |
| Dashboard | Web UI 查看 Pipeline 运行 |

### ArgoCD

声明式 GitOps 持续交付工具。

- **端口：** 8080
- **Sync 策略：** 自动或手动
- **架构：** Pull-based，自动检测 Git 变更

### Prometheus + Grafana

监控系统，采集 K8s、应用和业务指标。

| 端口 | 服务 | 用途 |
|------|------|------|
| 9090 | Prometheus | 指标查询 |
| 3000 | Grafana | 可视化面板 |

**预置告警规则：**
- Pod OOMKilled
- CPU/内存使用率过高
- PVC 使用率超阈值
- 自定义业务指标告警

### Loki

日志聚合系统，兼容 Prometheus 查询语法。

- **端口：** 3100
- **查询接口：** `/loki/api/v1/query`
- **数据源配置：** Grafana 中添加 Loki 数据源

### 示例应用

基于 Go + Gin 的微服务演示应用。

| 端点 | 说明 |
|------|------|
| `GET /health` | 健康检查 |
| `GET /metrics` | Prometheus 指标 |
| `GET /hello` | 示例接口 |

---

## 开发指南

### 本地开发

```bash
# 进入示例应用目录
cd example-app

# 本地运行（需要 Go 1.21+）
go run main.go

# 或使用 Docker
docker build -t example-app:latest .
docker run -p 8081:8081 example-app:latest
```

### 提交代码触发 CI

```bash
# 1. 提交代码
git add .
git commit -m "feat: update something"
git push origin main

# 2. 查看 Tekton Pipeline 运行状态
kubectl get pipelineruns

# 3. 查看日志
tkn pipelinerun logs <pipelinerun-name>

# 4. 访问 Tekton Dashboard
kubectl port-forward svc/tekton-dashboard 9097:9097
# 打开 http://localhost:9097
```

### GitOps 部署流程

```
┌─────────┐     ┌───────────┐     ┌─────────┐     ┌─────────┐
│  代码   │────▶│   Git     │────▶│ ArgoCD  │────▶│   K3s   │
│  Push   │     │  Webhook  │     │  Sync   │     │  Deploy │
└─────────┘     └───────────┘     └─────────┘     └─────────┘
```

**手动部署流程：**

```bash
# 1. 更新镜像 tag
export NEW_VERSION=v1.2.3
sed -i "s/image: .*/image: example-app:${NEW_VERSION}/" argocd/app.yaml

# 2. 提交并推送
git add argocd/app.yaml
git commit -m "chore: bump version to ${NEW_VERSION}"
git push origin main

# 3. 登录 ArgoCD 查看同步状态
argocd app sync example-app
argocd app wait example-app
```

---

## 监控与日志

### 访问 Grafana

```bash
# 端口转发
kubectl port-forward svc/grafana 3000:3000

# 打开浏览器
# http://localhost:3000
# 默认账号: admin / admin
```

**预置面板：**
- Kubernetes 集群概览
- Pod 资源使用率
- 应用请求 QPS / 延迟
- 自定义业务指标

### 查看日志

```bash
# 通过 Loki 查询（使用 Grafana）
# 路径: Explore > Loki > 输入查询

# 或通过命令行
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="example-app"}' \
  --data-urlencode 'start=1699996800000000000' \
  --data-urlencode 'end=1700000400000000000' | jq .

# 查看最近日志
kubectl logs -l app=example-app -f
```

### 设置告警

```bash
# 1. 编辑告警规则
vim monitoring/prometheus/rules/app-alerts.yaml

# 2. 应用规则
kubectl apply -f monitoring/prometheus/rules/app-alerts.yaml

# 3. 查看告警状态
kubectl get prometheusrules

# 4. 配置 AlertManager 通知
vim monitoring/alertmanager/alertmanager.yaml
kubectl apply -f monitoring/alertmanager/alertmanager.yaml
```

---

## 目录结构

```
cloudnative-pipeline/
├── README.md                    # 主文档
├── Makefile                     # Makefile
├── manifests/                   # K8s 资源清单
│   ├── namespace.yaml
│   └── example-app.yaml
├── tekton/                      # Tekton CI 配置
│   ├── tasks/
│   │   ├── build.yaml
│   │   └── push.yaml
│   ├── pipelines/
│   │   └── example-pipeline.yaml
│   └── triggers/
│       └── trigger-binding.yaml
├── argocd/                      # ArgoCD 配置
│   ├── namespace.yaml
│   └── app.yaml
├── monitoring/                  # 监控日志配置
│   ├── prometheus/
│   │   ├── prometheus.yaml
│   │   └── rules/
│   │       ├── node-alerts.yaml
│   │       └── app-alerts.yaml
│   ├── grafana/
│   │   ├── grafana.yaml
│   │   └── dashboards/
│   │       └── app-dashboard.json
│   ├── loki/
│   │   └── loki.yaml
│   ├── promtail/
│   │   └── promtail.yaml
│   └── alertmanager/
│       ├── alertmanager.yaml
│       └── notifiers/
│           └── config.yaml
├── example-app/                 # 示例应用
│   ├── main.go
│   ├── go.mod
│   ├── Dockerfile
│   └── kubernetes/
│       └── deployment.yaml
└── scripts/                     # 脚本
    └── quickstart.sh            # 快速开始脚本
```

---

## 常见问题

### Q: K3s 安装失败怎么办？

**A:** 检查系统要求并尝试以下步骤：

```bash
# 确认 Docker 已启动
systemctl status docker

# 确认端口未被占用
ss -tlnp | grep -E '6443|2379|2380'

# 查看 K3s 日志
journalctl -u k3s -f

# 如仍失败，使用安装脚本并开启调试模式
curl -sfL https://get.k3s.io | sh -x -v
```

### Q: ArgoCD 登录密码是什么？

**A:** 默认密码为 `admin`。首次登录后请修改密码：

```bash
# 查看密码
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# 或通过 ArgoCD CLI 修改
argocd login localhost:8080
argocd account update-password
```

### Q: Tekton Pipeline 触发失败怎么排查？

**A:** 按以下顺序检查：

```bash
# 1. 检查 EventListener 是否运行
kubectl get pods -n tekton-pipelines

# 2. 查看 Trigger 日志
kubectl logs -n tekton-pipelines <eventlistener-pod> -f

# 3. 检查 PipelineRun 状态
kubectl get pipelineruns
tkn pipelinerun logs <name> --last

# 4. 确认 GitHub Webhook 配置
# Settings > Webhooks > 检查 Payload URL 和 Secret
```

### Q: Prometheus 无法抓取到指标？

**A:** 按以下步骤排查：

```bash
# 1. 确认 ServiceMonitor 存在
kubectl get servicemonitors

# 2. 检查 Prometheus Targets 页面
# http://localhost:9090/targets

# 3. 查看 Prometheus 日志
kubectl logs -n monitoring prometheus-prometheus-0 -c prometheus

# 4. 确认应用暴露了 /metrics 端点
curl http://example-app:8081/metrics
```

### Q: Loki 查询不到日志？

**A:** 检查 Promtail 配置和 Loki 状态：

```bash
# 1. 确认 Promtail 在运行
kubectl get pods -n monitoring -l app=promtail

# 2. 查看 Promtail 日志
kubectl logs -n monitoring -l app=promtail --tail=100

# 3. 确认 Loki 在运行
kubectl get pods -n monitoring -l app=loki

# 4. 测试 Loki API
curl "http://localhost:3100/ready"

# 5. Grafana Loki 查询示例
# {app="example-app", namespace="default"}
```

### Q: 如何更新组件版本？

**A:** 推荐使用 GitOps 方式：

```bash
# 1. 更新 values 文件
vim manifests/values.yaml

# 2. 提交代码
git add . && git commit -m "chore: upgrade components"

# 3. ArgoCD 会自动检测变更并同步
# 或手动同步
argocd app sync cloudnative-pipeline
```

### Q: 磁盘空间不足？

**A:** K3s 和监控组件会占用一定磁盘空间：

```bash
# 清理 Docker 资源
docker system prune -af

# 清理 K3s 旧数据
k3s crictl rmi --prune

# 清理旧日志
kubectl delete old PodLogs
kubectl logs --tail=1000 -f <pod> > /dev/null 2>&1 &
```

---

## License

MIT License - 详见 [LICENSE](LICENSE) 文件。
