#!/bin/bash

# =================================================================
# CloudNative Pipeline - 快速开始脚本
# 一键安装云原生开发环境
# =================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查命令是否成功
check_cmd() {
    if [ $? -eq 0 ]; then
        log_success "$1"
    else
        log_error "$1"
        exit 1
    fi
}

echo "=========================================="
echo "  CloudNative Pipeline 快速开始"
echo "=========================================="
echo ""

# =================================================================
# 1. 检测前置工具
# =================================================================
log_info "检查前置要求..."

# 检测操作系统
OS_TYPE=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS_TYPE="windows"
fi

log_info "检测到操作系统: $OS_TYPE"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    log_warn "Docker 未安装，正在安装..."
    if [ "$OS_TYPE" == "linux" ]; then
        curl -fsSL https://get.docker.com | sh
    elif [ "$OS_TYPE" == "macos" ]; then
        brew install --cask docker
    fi
else
    log_success "Docker 已安装: $(docker --version)"
fi

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    log_warn "kubectl 未安装，正在安装..."
    if [ "$OS_TYPE" == "linux" ]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl && sudo mv kubectl /usr/local/bin/
    elif [ "$OS_TYPE" == "macos" ]; then
        brew install kubectl
    elif [ "$OS_TYPE" == "windows" ]; then
        curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
    fi
else
    log_success "kubectl 已安装: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"
fi

# 检查 K3s (如果未安装，脚本安装)
if ! command -v k3s &> /dev/null; then
    log_warn "K3s 未安装，正在安装..."
    log_info "运行 K3s 安装脚本..."
    
    if [ "$OS_TYPE" == "linux" ]; then
        curl -sfL https://get.k3s.io | sh -
        check_cmd "K3s 安装完成"
        
        # 配置 kubectl
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        mkdir -p ~/.kube
        cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    elif [ "$OS_TYPE" == "macos" ]; then
        brew install k3d
        k3d cluster create dev
        check_cmd "K3d 集群创建完成"
    else
        log_error "Windows 用户请手动安装 K3s: https://docs.k3s.io/installation"
        log_info "或使用 Docker Desktop + Kubernetes"
        exit 1
    fi
else
    log_success "K3s 已安装: $(k3s --version)"
fi

# =================================================================
# 2. 配置 kubectl
# =================================================================
log_info "配置 kubectl..."

if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 2>/dev/null || true
fi

# 等待 K8s API 就绪
log_info "等待 Kubernetes API 就绪..."
timeout=60
while ! kubectl get nodes &> /dev/null; do
    sleep 1
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        log_error "Kubernetes API 超时未就绪"
        exit 1
    fi
done
check_cmd "Kubernetes API 就绪"

# =================================================================
# 3. 创建命名空间
# =================================================================
log_info "创建命名空间..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tekton-pipelines --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
check_cmd "命名空间创建完成"

# =================================================================
# 4. 部署监控组件
# =================================================================
log_info "部署 Prometheus + Grafana..."

# Prometheus
kubectl apply -f monitoring/prometheus/prometheus.yaml
check_cmd "Prometheus 部署完成"

# Grafana
kubectl apply -f monitoring/grafana/grafana.yaml
check_cmd "Grafana 部署完成"

# Loki
kubectl apply -f monitoring/loki/loki.yaml
check_cmd "Loki 部署完成"

# Promtail
kubectl apply -f monitoring/promtail/promtail.yaml
check_cmd "Promtail 部署完成"

# AlertManager
kubectl apply -f monitoring/alertmanager/alertmanager.yaml
check_cmd "AlertManager 部署完成"

# =================================================================
# 5. 部署 Tekton
# =================================================================
log_info "部署 Tekton CI/CD..."

# Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
check_cmd "Tekton Pipelines 部署完成"

# Tekton Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
check_cmd "Tekton Dashboard 部署完成"

# Tekton Triggers
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
check_cmd "Tekton Triggers 部署完成"

# 部署自定义 Tasks 和 Pipelines
kubectl apply -f tekton/tasks/
kubectl apply -f tekton/pipelines/
check_cmd "Tekton Tasks 和 Pipelines 部署完成"

# =================================================================
# 6. 部署 ArgoCD
# =================================================================
log_info "部署 ArgoCD..."

# ArgoCD
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
check_cmd "ArgoCD 部署完成"

# ArgoCD Application
kubectl apply -f argocd/app.yaml
check_cmd "ArgoCD Application 创建完成"

# =================================================================
# 7. 部署示例应用
# =================================================================
log_info "部署示例应用..."

kubectl apply -f manifests/example-app.yaml
check_cmd "示例应用部署完成"

# =================================================================
# 8. 等待所有 Pod 就绪
# =================================================================
log_info "等待所有 Pod 就绪（最多等待 5 分钟）..."

kubectl wait --for=condition=ready pod -l app=example-app -n dev --timeout=300s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=argocd-server -n argocd --timeout=300s 2>/dev/null || true

log_success "所有组件部署完成！"

# =================================================================
# 9. 显示访问信息
# =================================================================
echo ""
echo "=========================================="
echo "  🎉 部署完成！访问信息如下："
echo "=========================================="
echo ""

# 获取 ArgoCD 密码
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "admin")

echo -e "${GREEN}示例应用:${NC}"
echo "  URL: http://localhost:8081"
echo "  健康检查: http://localhost:8081/health"
echo "  指标端点: http://localhost:8081/metrics"
echo ""

echo -e "${GREEN}ArgoCD:${NC}"
echo "  URL: http://localhost:8080"
echo "  账号: admin"
echo "  密码: ${ARGOCD_PASSWORD}"
echo ""

echo -e "${GREEN}Grafana:${NC}"
echo "  URL: http://localhost:3000"
echo "  账号: admin"
echo "  密码: admin"
echo ""

echo -e "${GREEN}Prometheus:${NC}"
echo "  URL: http://localhost:9090"
echo ""

echo -e "${GREEN}Tekton Dashboard:${NC}"
echo "  URL: http://localhost:9097"
echo ""

echo -e "${GREEN}Loki:${NC}"
echo "  URL: http://localhost:3100"
echo ""

echo "=========================================="
echo "  端口转发命令："
echo "=========================================="
echo ""
echo "  # ArgoCD"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "  # Grafana"
echo "  kubectl port-forward svc/grafana -n monitoring 3000:3000"
echo ""
echo "  # Prometheus"
echo "  kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090"
echo ""
echo "  # Tekton Dashboard"
echo "  kubectl port-forward svc/tekton-dashboard -n tekton-pipelines 9097:9097"
echo ""
echo "  # 示例应用（已自动端口转发）"
echo "  kubectl port-forward svc/example-app -n dev 8081:8081"
echo ""
echo "=========================================="
echo ""
log_success "快速开始完成！开始你的云原生开发之旅吧 🚀"
