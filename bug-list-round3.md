# CloudNative Pipeline 第三轮代码审查 - Bug 清单

## 审查日期
2026-04-01

## 问题汇总

| 优先级 | 严重度 | 问题数 |
|--------|--------|--------|
| 🔴 高 | 高 | 3 |
| 🟡 中 | 中 | 5 |
| 🟢 低 | 低 | 2 |

---

## 🔴 高优先级问题

### Bug #1: Prometheus 抓取端口配置错误

**文件**: `docker/prometheus.yml`

**当前配置**:
```yaml
- job_name: 'app'
  static_configs:
    - targets: ['app:8080']  # ❌ 错误
  metrics_path: '/metrics'
```

**问题**: 应用在容器端口 **9090** 暴露 Prometheus 指标，8080 是 HTTP 端口。

**正确配置**:
```yaml
- job_name: 'app'
  static_configs:
    - targets: ['app:9090']  # ✅ 正确
  metrics_path: '/metrics'
```

**影响**: Prometheus 无法采集应用指标，监控页面无数据。

---

### Bug #2: ArgoCD 目标分支与项目不一致

**文件**: `argocd/applications/app-dev.yaml`

**当前配置**:
```yaml
source:
  repoURL: https://github.com/your-org/gitops.git  # 占位符
  targetRevision: main  # ❌ 应该是 master
```

**问题**: 项目 Git 分支使用 `master`，但 ArgoCD 配置为 `main`。

**正确配置**:
```yaml
source:
  repoURL: https://github.com/your-org/gitops.git
  targetRevision: master  # ✅ 与项目分支一致
```

---

### Bug #3: ArgoCD Application 重复配置

**文件**: `argocd/applications/app-dev.yaml`

**当前配置**:
```yaml
syncPolicy:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      ...
  
# 下面又重复定义了一次
ignoreDifferences:
  - group: apps
    kind: Deployment
    ...
```

**问题**: `ignoreDifferences` 定义了两次，YAML 中后面的会覆盖前面的，可能导致意外行为。

**正确配置**:
```yaml
syncPolicy:
  ignoreDifferences:  # 只在这里定义一次
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    - group: apps
      kind: StatefulSet
      jsonPointers:
        - /spec/replicas
  # 删除下面的重复定义
```

---

## 🟡 中优先级问题

### Bug #4: Init Container 使用不兼容的 nc 命令

**文件**: `k8s/base/deployment.yaml`

**当前配置**:
```yaml
initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        until nc -z postgres-headless.pipeline.svc.cluster.local 5432; do
```

**问题**: `nc -z` 不是所有 busybox 版本都支持，可能在某些镜像中失败。

**正确配置**:
```yaml
initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        until wget -q -O /dev/null http://postgres-headless.pipeline.svc.cluster.local:5432 2>/dev/null || exit 0; do
          echo "Waiting for PostgreSQL..."
          sleep 2
        done
```

---

### Bug #5: K8s Deployment 缺少 imagePullSecrets

**文件**: `k8s/base/deployment.yaml`

**当前配置**:
```yaml
containers:
  - name: app
    image: registry.example.com/cloudnative-pipeline:v1.0.0
    imagePullPolicy: Always
```

**问题**: 使用私有镜像仓库但未配置 `imagePullSecrets`，会导致镜像拉取失败。

**正确配置**:
```yaml
# 在 spec 下添加
imagePullSecrets:
  - name: registry-secret

# containers 保持不变
containers:
  - name: app
    image: registry.example.com/cloudnative-pipeline:v1.0.0
```

---

### Bug #6: 网络策略 Egress 规则过于宽松

**文件**: `gitops/apps/app/overlays/prod/network-policy.yaml`

**当前配置**:
```yaml
egress:
  - to:
      - podSelector: {}  # ⚠️ 允许所有 Pod 出站流量
    ports:
      - protocol: TCP
        port: 8080
  - to:
      - namespaceSelector: {}  # ⚠️ 允许所有 namespace DNS
    ports:
      - protocol: TCP
        port: 53
      - protocol: UDP
        port: 53
```

**问题**: 生产环境应限制出站流量，只允许访问必要的服务。

**建议配置**:
```yaml
egress:
  # 只允许访问集群内部服务
  - to:
      - namespaceSelector: {}  # 集群内部 DNS
    ports:
      - protocol: TCP
        port: 53
      - protocol: UDP
        port: 53
  # 允许访问依赖的集群内部服务
  - to:
      - podSelector:
          matchLabels:
            app: postgres
      - podSelector:
          matchLabels:
            app: redis
    ports:
      - protocol: TCP
        port: 5432
      - protocol: TCP
        port: 6379
```

---

### Bug #7: ArgoCD 应用仓库地址占位符未替换

**文件**: `argocd/applications/app-dev.yaml`, `argocd/applications/app-prod.yaml`

**问题**: GitOps 仓库地址仍是占位符 `https://github.com/your-org/gitops.git`，无法正常工作。

**修复方案**: 添加环境变量支持或明确文档说明需要手动替换。

---

### Bug #8: 缺少 PodDisruptionBudget 的 topLevel 验证

**文件**: `k8s/base/pdb.yaml`

**当前配置**:
```yaml
spec:
  minAvailable: 2
```

**问题**: PDB 的 `minAvailable: 2` 可能大于某些环境的 replica 数量（dev 环境可能只有 1 个副本），导致无法调度。

**建议配置**:
```yaml
spec:
  # 使用百分比更适合多环境
  minAvailable: 50%
  # 或者确保 dev 环境至少有 2 个副本
  maxUnavailable: 1
```

---

## 🟢 低优先级问题

### Bug #9: Tekton Task namespace 硬编码

**文件**: `tekton/tasks/build-image.yaml`

**当前配置**:
```yaml
metadata:
  name: build-image
  namespace: tekton-ci  # 硬编码
```

**问题**: 不同环境可能使用不同的 namespace。

**建议**: 移除 namespace 硬编码，让 Tekton Pipeline 运行时指定。

---

### Bug #10: Prometheus Alert 规则未设置 inhibition

**文件**: `monitoring/prometheus/rules/pod-alerts.yaml`

**问题**: PodCPUUsageHigh 和 PodCPUUsageCritical 没有设置告警抑制，Critical 可能淹没 Warning。

**建议**: 使用 AlertManager 的 inhibit_rules（已在 alertmanager/configmap.yaml 中配置），确保告警合理分级。

---

## 修复任务分配

### Agent 1: 修复 Prometheus 和 ArgoCD 配置
- Bug #1: prometheus.yml 端口错误
- Bug #2: ArgoCD targetRevision 改为 master
- Bug #3: ArgoCD 重复 ignoreDifferences

### Agent 2: 修复 K8s 部署配置
- Bug #4: busybox nc 改 wget
- Bug #5: 添加 imagePullSecrets

### Agent 3: 修复网络策略
- Bug #6: egress 规则收紧
- Bug #7: ArgoCD 占位符文档说明

### Agent 4: 修复其他问题
- Bug #8: PDB 配置优化
- Bug #9: Tekton namespace
- Bug #10: 告警抑制说明
