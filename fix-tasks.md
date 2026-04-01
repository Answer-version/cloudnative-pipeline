# 代码审查问题修复任务

## 必须修复 (5个)

### 1. ArgoCD App 硬编码占位符
- 文件: argocd/applications/app-dev.yaml
- 修复: 使用环境变量引用或添加注释说明需要替换

### 2. AlertManager 抑制规则逻辑漏洞
- 文件: monitoring/alertmanager/configmap.yaml
- 修复: equal 字段添加 'node' 标签

### 3. 示例应用随机健康检查
- 文件: example-app/main.go
- 修复: 移除随机失败逻辑，添加 /ready 端点

### 4. Trivy 阻断策略过于激进
- 文件: .github/workflows/ci.yaml
- 修复: 只对 CRITICAL 阻断，HIGH 仅警告

### 5. Redis 弱密码
- 文件: docker/docker-compose.yml
- 修复: 使用更强的密码或环境变量

---

## 建议修改 (5个)

### 6. 缺少 PodDisruptionBudget
- 文件: k8s/base/deployment.yaml
- 修复: 添加 PDB 配置

### 7. kubectl apply 路径错误
- 文件: scripts/quickstart.sh
- 修复: 修正为正确的文件路径

### 8. Tekton extract-digest 无法工作
- 文件: tekton/tasks/build-image.yaml
- 修复: 使用 crane 或记录 Kaniko 输出

### 9. terminationGracePeriodSeconds 过短
- 文件: k8s/base/deployment.yaml
- 修复: 增加到 120s

### 10. 网络策略过于宽松
- 文件: gitops/apps/app/overlays/prod/network-policy.yaml
- 修复: 限制只有 Ingress Controller 可访问

---

## 仅供参考 (4个)

### 11. 缺少 /ready 端点
- 文件: example-app/main.go
- 修复: 添加 readiness handler

### 12. Prometheus 配置缺失
- 文件: docker/docker-compose.yml
- 修复: 创建 docker/prometheus.yml 或使用内联配置
