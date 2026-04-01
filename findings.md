# 云原生流水线开发环境 - 调研发现

## 竞品分析

### 已有类似方案
1. **Docker Desktop + Kubernetes** - 商业软件，需要付费
2. **Minikube** - 单节点 K8s，功能完整但较重
3. **K3s** - 轻量级 K8s，适合开发/边缘计算
4. **Kind** - K8s in Docker，适合 CI

### 差异化机会
- 一站式配置好 CI/CD + GitOps
- 开箱即用的监控/日志
- 自动化程度高

---

## 技术栈调研

### 容器开发
- Docker Compose 用于本地开发
- Kaniko 用于无 Docker 守护进程的镜像构建
- Distroless 最小化镜像

### CI/CD
- Tekton: K8s 原生 CI/CD
- ArgoCD: GitOps 持续交付
- GitHub Actions: 触发流水线

### 监控
- Prometheus: 指标收集
- Grafana: 可视化
- AlertManager: 告警
- Loki: 日志聚合

---

## 更新日志

| 日期 | 内容 |
|------|------|
| 2026-04-01 | 创建调研文档 |
