#!/usr/bin/env bash
# ===================================================================
# K3s 快速安装脚本
# ===================================================================
# 支持: Ubuntu/Debian, CentOS/RHEL, macOS
# 用法:
#   单节点: curl -sfL https://get.k3s.io | sh -
#   高可用: curl -sfL https://get.k3s.io | sh -s - server --cluster-init
#
# 验证集群:
#   kubectl get nodes
#   kubectl get pods -A
# ===================================================================

set -e

# ===================================================================
# 配置
# ===================================================================
K3S_VERSION="${K3S_VERSION:-v1.28.4}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube}"
KUBECONFIG_FILE="${KUBECONFIG_FILE:-config}"
INSTALL_DIR="/usr/local/bin"
SKIP_TRAEFLIK="${SKIP_TRAEFLIK:-false}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===================================================================
# 函数定义
# ===================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/debian_version ]]; then
            echo "debian"
        elif [[ -f /etc/redhat-release ]]; then
            echo "rhel"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "建议以 root 权限运行 (sudo)"
    fi
}

# 检查 kubectl
check_kubectl() {
    if command -v kubectl &> /dev/null; then
        local version
        version=$(kubectl version --client -o yaml | grep gitVersion | head -1 | awk '{print $2}')
        log_info "kubectl 已安装: $version"
        return 0
    else
        log_info "kubectl 未安装，正在安装..."
        return 1
    fi
}

# 安装 kubectl
install_kubectl() {
    local os
    local arch
    local tmp_dir

    os=$(detect_os)
    arch=$(uname -m)
    tmp_dir=$(mktemp -d)

    # 架构转换
    case $arch in
        x86_64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            log_error "不支持的架构: $arch"
            exit 1
            ;;
    esos

    # 下载 kubectl
    log_info "下载 kubectl..."
    curl -sL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/${os}/${arch}/kubectl" \
        -o "${tmp_dir}/kubectl"

    # 安装
    chmod +x "${tmp_dir}/kubectl"
    sudo mv "${tmp_dir}/kubectl" "${INSTALL_DIR}/kubectl"

    # 清理
    rm -rf "$tmp_dir"

    log_success "kubectl 安装完成"
}

# 创建 kubeconfig 目录
setup_kubeconfig() {
    mkdir -p "$KUBECONFIG_PATH"
    chmod 700 "$KUBECONFIG_PATH"

    # 如果使用 K3s 安装，设置 kubeconfig
    if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
        log_info "复制 kubeconfig..."
        cp /etc/rancher/k3s/k3s.yaml "${KUBECONFIG_PATH}/${KUBECONFIG_FILE}"
        chmod 600 "${KUBECONFIG_PATH}/${KUBECONFIG_FILE}"
        export KUBECONFIG="${KUBECONFIG_PATH}/${KUBECONFIG_FILE}"
        log_success "kubeconfig 已配置: $KUBECONFIG"
    fi
}

# 等待 K3s 就绪
wait_for_k3s() {
    log_info "等待 K3s 就绪..."
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if kubectl get nodes &> /dev/null; then
            log_success "K3s 已就绪"
            return 0
        fi
        log_info "等待中... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done

    log_error "K3s 启动超时"
    return 1
}

# 验证集群状态
verify_cluster() {
    log_info "验证集群状态..."

    echo ""
    echo "=========================================="
    echo "  K3s 集群节点"
    echo "=========================================="
    kubectl get nodes -o wide

    echo ""
    echo "=========================================="
    echo "  系统 Pods"
    echo "=========================================="
    kubectl get pods -A

    echo ""
    echo "=========================================="
    echo "  集群信息"
    echo "=========================================="
    kubectl cluster-info

    echo ""
    echo "=========================================="
    echo "  API 版本"
    echo "=========================================="
    kubectl version
}

# 安装 Helm
install_helm() {
    if command -v helm &> /dev/null; then
        log_info "Helm 已安装: $(helm version --short)"
        return 0
    fi

    log_info "安装 Helm..."
    local tmp_dir
    tmp_dir=$(mktemp -d)

    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
        DESIRED_VERSION="v3.14.0" bash

    log_success "Helm 安装完成"
}

# 安装 Nginx Ingress Controller
install_ingress() {
    if [[ "$SKIP_TRAEFLIK" == "true" ]]; then
        log_info "跳过 Ingress 安装"
        return 0
    fi

    log_info "安装 Nginx Ingress Controller..."

    # 添加 Helm repo
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    # 安装
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.publishService.enabled=true \
        --set controller.service.type=LoadBalancer \
        --wait --timeout 5m

    log_success "Nginx Ingress Controller 安装完成"
}

# 安装 cert-manager
install_cert_manager() {
    log_info "安装 cert-manager..."

    # 安装 CRDs
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

    # 等待就绪
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

    log_success "cert-manager 安装完成"
}

# 创建 namespace
create_namespaces() {
    log_info "创建 namespaces..."

    kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: pipeline
  labels:
    name: pipeline
    app.kubernetes.io/name: cloudnative-pipeline
---
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    name: ingress-nginx
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    name: cert-manager
EOF

    log_success "Namespaces 创建完成"
}

# 部署示例应用
deploy_sample_app() {
    log_info "部署 CloudNative Pipeline 示例应用..."

    # 创建 namespace
    kubectl create namespace pipeline --dry-run=client -o yaml | kubectl apply -f -

    # 部署 ConfigMap
    kubectl apply -f ../k8s/base/configmap.yaml

    # 部署 Secret (模板，需要替换真实值)
    # kubectl apply -f ../k8s/base/secret.yaml

    # 部署 Deployment
    kubectl apply -f ../k8s/base/deployment.yaml

    # 部署 Service
    kubectl apply -f ../k8s/base/service.yaml

    # 等待就绪
    kubectl wait --for=condition=Ready pods -l app=cloudnative-pipeline -n pipeline --timeout=180s

    log_success "示例应用部署完成"
}

# 打印后续步骤
print_next_steps() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}  K3s 安装完成！${NC}"
    echo "=========================================="
    echo ""
    echo "  后续步骤:"
    echo ""
    echo "  1. 配置 kubectl:"
    echo "     export KUBECONFIG=$KUBECONFIG_PATH/$KUBECONFIG_FILE"
    echo "     # 或添加到 ~/.bashrc"
    echo ""
    echo "  2. 验证集群:"
    echo "     kubectl get nodes"
    echo "     kubectl get pods -A"
    echo ""
    echo "  3. 部署应用:"
    echo "     cd $(dirname "$0")/.."
    echo "     kubectl apply -f k8s/base/"
    echo ""
    echo "  4. 查看应用:"
    echo "     kubectl get pods -n pipeline"
    echo "     kubectl logs -n pipeline -l app=cloudnative-pipeline"
    echo ""
    echo "  5. 访问应用:"
    echo "     # 添加到 /etc/hosts"
    echo "     echo \"127.0.0.1 pipeline.example.com\" | sudo tee -a /etc/hosts"
    echo "     curl http://pipeline.example.com/health"
    echo ""
    echo "  6. 卸载 K3s:"
    echo "     /usr/local/bin/k3s-uninstall.sh"
    echo "     # 或 (server 节点)"
    echo "     /usr/local/bin/k3s-agent-uninstall.sh"
    echo ""
    echo "=========================================="
}

# ===================================================================
# 主流程
# ===================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  K3s 快速安装脚本"
    echo "  版本: $K3S_VERSION"
    echo "=========================================="
    echo ""

    check_root

    local os
    os=$(detect_os)
    log_info "检测到操作系统: $os"

    # 安装 kubectl
    if ! check_kubectl; then
        install_kubectl
    fi

    # 检查 K3s 是否已安装
    if command -v k3s &> /dev/null; then
        log_warn "K3s 已安装: $(k3s --version)"
        setup_kubeconfig
        wait_for_k3s
        verify_cluster
        print_next_steps
        exit 0
    fi

    # 安装 K3s
    log_info "开始安装 K3s $K3S_VERSION..."

    if [[ "$os" == "macos" ]]; then
        # macOS 使用 Docker Desktop 或 Rancher Desktop
        log_warn "macOS 检测到"
        log_info "推荐使用 Rancher Desktop: https://rancherdesktop.io/"
        log_info "或 Docker Desktop Kubernetes"
        exit 1
    else
        # Linux 安装
        curl -sfL https://get.k3s.io | \
            INSTALL_K3S_VERSION="$K3S_VERSION" \
            INSTALL_K3S_SKIP_START=true \
            sh -
    fi

    # 配置 kubeconfig
    setup_kubeconfig

    # 启动 K3s
    log_info "启动 K3s 服务..."
    sudo systemctl enable k3s
    sudo systemctl start k3s

    # 等待就绪
    wait_for_k3s

    # 安装 Helm
    install_helm

    # 创建 namespaces
    create_namespaces

    # 安装 Ingress
    install_ingress

    # 部署示例应用
    deploy_sample_app

    # 验证集群
    verify_cluster

    # 打印后续步骤
    print_next_steps
}

# ===================================================================
# 脚本入口
# ===================================================================

case "${1:-}" in
    --help|-h)
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --skip-ingress    跳过 Ingress Controller 安装"
        echo "  --skip-app        跳过示例应用部署"
        echo "  --version <ver>   指定 K3s 版本"
        echo "  --help            显示帮助信息"
        exit 0
        ;;
    --skip-ingress)
        SKIP_TRAEFLIK=true
        shift
        ;;
    --skip-app)
        SKIP_APP=true
        shift
        ;;
    --version)
        K3S_VERSION="$2"
        shift 2
        ;;
esac

main
