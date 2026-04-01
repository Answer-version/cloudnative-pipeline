# =================================================================
# CloudNative Pipeline - Makefile
# 云原生流水线开发环境管理
# =================================================================

# 默认目标
.PHONY: help
help: ## 显示帮助信息
	@echo "CloudNative Pipeline - Makefile"
	@echo ""
	@echo "使用方法:"
	@echo "  make install-dev      安装开发环境（K3s + 所有组件）"
	@echo "  make deploy-dev       部署到开发环境"
	@echo "  make logs             查看日志"
	@echo "  make monitor          打开监控 Dashboard"
	@echo "  make clean            清理开发环境"
	@echo "  make test             运行测试"
	@echo "  make build            构建镜像"
	@echo ""
	@echo "示例应用:"
	@echo "  make app-build        构建示例应用镜像"
	@echo "  make app-deploy       部署示例应用"
	@echo "  make app-logs         查看示例应用日志"
	@echo "  make app-test         测试示例应用"
	@echo ""

# =================================================================
# 变量定义
# =================================================================
NAMESPACE ?= dev
APP_NAME ?= example-app
IMAGE_REGISTRY ?= docker.io
IMAGE_TAG ?= latest
IMAGE_FULL = $(IMAGE_REGISTRY)/$(APP_NAME):$(IMAGE_TAG)

KUBECTL = kubectl
K3S_KUBECONFIG = ~/.kube/config
export KUBECONFIG ?= $(K3S_KUBECONFIG)

# 颜色输出
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m

# =================================================================
# 安装开发环境
# =================================================================
.PHONY: install-dev
install-dev: ## 安装开发环境（K3s + 所有组件）
	@echo "$(BLUE)[INFO]$(NC) 开始安装开发环境..."
	@bash scripts/quickstart.sh

# =================================================================
# 部署到开发环境
# =================================================================
.PHONY: deploy-dev
deploy-dev: ## 部署到开发环境
	@echo "$(BLUE)[INFO]$(NC) 部署所有组件到开发环境..."
	@$(KUBECTL) apply -f manifests/
	@$(KUBECTL) apply -f monitoring/
	@$(KUBECTL) apply -f tekton/
	@$(KUBECTL) apply -f argocd/
	@echo "$(GREEN)[SUCCESS]$(NC) 部署完成！"

# =================================================================
# 查看日志
# =================================================================
.PHONY: logs
logs: ## 查看日志（支持 app= 参数指定应用）
	@if [ -n "$(app)" ]; then \
		echo "$(BLUE)[INFO]$(NC) 查看 $(app) 日志..."; \
		$(KUBECTL) logs -l app=$(app) -n $(NAMESPACE) -f --tail=100; \
	else \
		echo "$(YELLOW)[WARN]$(NC) 请指定 app 参数: make logs app=example-app"; \
		echo "$(BLUE)[INFO]$(NC) 可用的应用:"; \
		$(KUBECTL) get pods -n $(NAMESPACE) --no-headers 2>/dev/null | awk '{print $$1}'; \
	fi

# =================================================================
# 打开监控
# =================================================================
.PHONY: monitor
monitor: ## 打开监控 Dashboard（Grafana）
	@echo "$(BLUE)[INFO]$(NC) 打开 Grafana Dashboard..."
	@echo "$(BLUE)[INFO]$(NC) 等待端口转发..."
	@$(KUBECTL) port-forward -n monitoring svc/grafana 3000:3000 &
	@sleep 3
	@echo "$(GREEN)[SUCCESS]$(NC) Grafana 已打开: http://localhost:3000"
	@echo "$(YELLOW)[提示]$(NC) 账号: admin / 密码: admin"
	@echo "$(YELLOW)[提示]$(NC) 按 Ctrl+C 停止端口转发"

# =================================================================
# 清理环境
# =================================================================
.PHONY: clean
clean: ## 清理开发环境
	@echo "$(YELLOW)[WARN]$(NC) 即将清理开发环境..."
	@read -p "确认清理? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)[INFO]$(NC) 删除命名空间..."; \
		$(KUBECTL) delete namespace $(NAMESPACE) --ignore-not-found=true; \
		$(KUBECTL) delete namespace monitoring --ignore-not-found=true; \
		$(KUBECTL) delete namespace tekton-pipelines --ignore-not-found=true; \
		$(KUBECTL) delete namespace argocd --ignore-not-found=true; \
		echo "$(GREEN)[SUCCESS]$(NC) 清理完成！"; \
	else \
		echo "$(BLUE)[INFO]$(NC) 取消清理操作"; \
	fi

# =================================================================
# 运行测试
# =================================================================
.PHONY: test
test: ## 运行测试
	@echo "$(BLUE)[INFO]$(NC) 运行测试..."
	@cd example-app && go test -v -race -cover ./...

# =================================================================
# 构建镜像
# =================================================================
.PHONY: build
build: app-build ## 构建镜像（默认构建示例应用）

.PHONY: app-build
app-build: ## 构建示例应用镜像
	@echo "$(BLUE)[INFO]$(NC) 构建示例应用镜像: $(IMAGE_FULL)"
	@cd example-app && docker build -t $(IMAGE_FULL) .
	@echo "$(GREEN)[SUCCESS]$(NC) 镜像构建完成: $(IMAGE_FULL)"

# =================================================================
# 示例应用操作
# =================================================================
.PHONY: app-deploy
app-deploy: ## 部署示例应用
	@echo "$(BLUE)[INFO]$(NC) 部署示例应用..."
	@$(KUBECTL) apply -f example-app/kubernetes/deployment.yaml
	@$(KUBECTL) apply -f manifests/example-app.yaml
	@echo "$(GREEN)[SUCCESS]$(NC) 部署完成！"

.PHONY: app-logs
app-logs: ## 查看示例应用日志
	@echo "$(BLUE)[INFO]$(NC) 查看示例应用日志..."
	@$(KUBECTL) logs -l app=$(APP_NAME) -n $(NAMESPACE) -f --tail=100

.PHONY: app-test
app-test: ## 测试示例应用
	@echo "$(BLUE)[INFO]$(NC) 测试示例应用健康检查..."
	@$(KUBECTL) port-forward svc/$(APP_NAME) -n $(NAMESPACE) 8081:8081 &
	@sleep 2
	@curl -s http://localhost:8081/health | head -20
	@curl -s http://localhost:8081/hello | head -20
	@echo ""
	@kill %1 2>/dev/null || true

.PHONY: app-restart
app-restart: ## 重启示例应用
	@echo "$(BLUE)[INFO]$(NC) 重启示例应用..."
	@$(KUBECTL) rollout restart deployment/$(APP_NAME) -n $(NAMESPACE)
	@$(KUBECTL) rollout status deployment/$(APP_NAME) -n $(NAMESPACE)
	@echo "$(GREEN)[SUCCESS]$(NC) 重启完成！"

# =================================================================
# Tekton CI/CD
# =================================================================
.PHONY: ci-logs
ci-logs: ## 查看 Tekton Pipeline 日志
	@echo "$(BLUE)[INFO]$(NC) 查看最近的 PipelineRun..."
	@tkn pipelinerun list --last 5
	@echo ""
	@read -p "输入 PipelineRun 名称查看日志 (直接回车跳过): " pr_name; \
	if [ -n "$$pr_name" ]; then \
		tkn pipelinerun logs $$pr_name -f; \
	fi

.PHONY: ci-trigger
ci-trigger: ## 手动触发 Tekton Pipeline
	@echo "$(BLUE)[INFO]$(NC) 手动触发 Pipeline..."
	@kubectl apply -f tekton/triggers/trigger-binding.yaml
	@echo "$(GREEN)[SUCCESS]$(NC) 触发器已配置"

# =================================================================
# ArgoCD
# =================================================================
.PHONY: argocd-login
argocd-login: ## 登录 ArgoCD
	@echo "$(BLUE)[INFO]$(NC) 获取 ArgoCD 密码..."
	@ARGOCD_PASSWORD=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d); \
	kubectl port-forward -n argocd svc/argocd-server 8080:443 &; \
	sleep 3; \
	argocd login localhost:8080 --username admin --password $$ARGOCD_PASSWORD --insecure; \
	echo "$(GREEN)[SUCCESS]$(NC) 登录成功！"

.PHONY: argocd-sync
argocd-sync: ## 同步 ArgoCD 应用
	@echo "$(BLUE)[INFO]$(NC) 同步 ArgoCD 应用..."
	@argocd app sync $(APP_NAME) --force
	@argocd app wait $(APP_NAME)

# =================================================================
# 监控
# =================================================================
.PHONY: prometheus
prometheus: ## 打开 Prometheus
	@echo "$(BLUE)[INFO]$(NC) 打开 Prometheus..."
	@kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
	@echo "$(GREEN)[SUCCESS]$(NC) Prometheus 已打开: http://localhost:9090"

.PHONY: loki
loki: ## 打开 Loki 查询
	@echo "$(BLUE)[INFO]$(NC) 测试 Loki API..."
	@curl -s "http://localhost:3100/ready"
	@echo ""
	@echo "$(GREEN)[INFO]$(NC) Grafana 中添加 Loki 数据源进行查询"
	@echo "$(BLUE)[INFO]$(NC) Loki API: http://localhost:3100"

# =================================================================
# 清理 Docker 资源
# =================================================================
.PHONY: docker-clean
docker-clean: ## 清理 Docker 资源
	@echo "$(BLUE)[INFO]$(NC) 清理 Docker 资源..."
	@docker system prune -af --volumes
	@echo "$(GREEN)[SUCCESS]$(NC) Docker 清理完成！"

# =================================================================
# 状态查看
# =================================================================
.PHONY: status
status: ## 查看所有组件状态
	@echo "$(BLUE)===== Namespace: $(NAMESPACE) =====$(NC)"
	@$(KUBECTL) get pods -n $(NAMESPACE)
	@echo ""
	@echo "$(BLUE)===== Namespace: monitoring =====$(NC)"
	@$(KUBECTL) get pods -n monitoring
	@echo ""
	@echo "$(BLUE)===== Namespace: argocd =====$(NC)"
	@$(KUBECTL) get pods -n argocd
	@echo ""
	@echo "$(BLUE)===== Tekton PipelineRuns =====$(NC)"
	@tkn pipelinerun list --last 5 2>/dev/null || echo "Tekton 未安装或无 PipelineRun"

# =================================================================
# 开发辅助
# =================================================================
.PHONY: port-forward
port-forward: ## 端口转发（支持 service= 和 port= 参数）
	@if [ -n "$(service)" ]; then \
		ns=$(if $(namespace),$(namespace),default); \
		p=$(if $(port),$(port),8080); \
		echo "$(BLUE)[INFO]$(NC) 转发: service/$(service) -n $$ns -> localhost:$$p"; \
		$(KUBECTL) port-forward svc/$(service) -n $$ns $$p:$$p; \
	else \
		echo "$(YELLOW)[WARN]$(NC) 请指定 service 参数: make port-forward service=example-app port=8081"; \
	fi

# =================================================================
# 快速检查
# =================================================================
.PHONY: check
check: ## 检查所有服务健康状态
	@echo "$(BLUE)[INFO]$(NC) 检查服务健康状态..."
	@echo ""
	@echo "--- K8s 节点 ---"
	@$(KUBECTL) get nodes -o wide
	@echo ""
	@echo "--- 示例应用 ---"
	@$(KUBECTL) exec -n $(NAMESPACE) deployment/$(APP_NAME) -- wget -qO- http://localhost:8081/health 2>/dev/null || echo "示例应用未就绪"
