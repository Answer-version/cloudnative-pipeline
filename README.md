# 云原生流水线

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)
[![Windows](https://img.shields.io/badge/Windows-Support-0078D4?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue)](https://github.com/your-org/cloudnative-pipeline/releases)

开箱即用的云原生开发环境

---

## ✨ 特性

- ✅ **一键安装 (Windows)** - 双击脚本即可启动
- ✅ **无需 Kubernetes** - 无需学习复杂 K8s 知识
- ✅ **包含完整监控栈** - Prometheus + Grafana + Loki
- ✅ **本地开发友好** - 告别繁琐的配置

---

## 🚀 快速开始

### 5 分钟启动！

```
1. 下载 release
      ↓
2. 双击 START-WINDOWS.bat
      ↓
3. 访问 http://localhost:8080
```

详细步骤？查看 [5分钟快速开始](QUICKSTART.md)

---

## 📦 包含组件

| 组件 | 用途 | 端口 |
|------|------|------|
| **ArgoCD** | GitOps 部署管理 | 8080 |
| **Prometheus** | 指标采集 | 9090 |
| **Grafana** | 监控可视化 | 3000 |
| **Loki** | 日志聚合 | 3100 |
| **示例应用** | Go 微服务演示 | 8081 |

---

## 📖 文档

| 文档 | 说明 |
|------|------|
| [📚 快速开始][quickstart] | 5分钟上手指南，面向小白 |
| [🔧 常见问题][troubleshooting] | 常见问题与解决方案 |
| [📋 完整文档][docs] | 架构说明、开发指南 |

[quickstart]: QUICKSTART.md
[troubleshooting]: TROUBLESHOOTING.md
[docs]: docs/

---

## 🏗️ 架构概览

```
代码提交 → GitHub → Tekton CI → 构建镜像
                                  ↓
ArgoCD GitOps ← 镜像仓库 ← 推送镜像
     ↓
K3s 部署 ← 应用
     ↓
监控：Prometheus + Grafana
日志：Loki + Promtail
```

---

## 💻 系统要求

| 要求 | 最低配置 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Windows 10+ | Windows 11 |
| 内存 | 8 GB | 16 GB |
| 磁盘 | 20 GB 可用 | 50 GB 可用 |
| Docker | Docker Desktop 4.x | 最新版 |

---

## 🛠️ 常用命令

```bash
# 启动所有服务
双击 START-WINDOWS.bat

# 停止所有服务
双击 STOP-WINDOWS.bat

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

---

## 📝 示例应用端点

访问 http://localhost:8081

| 端点 | 说明 |
|------|------|
| `GET /` | 首页 |
| `GET /health` | 健康检查 |
| `GET /metrics` | Prometheus 指标 |
| `GET /hello` | 示例接口 |

---

## 🔗 相关资源

- [Docker Desktop 下载](https://www.docker.com/products/docker-desktop/)
- [Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/)
- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [Prometheus 官方文档](https://prometheus.io/docs/)

---

## 📄 License

MIT License - 详见 [LICENSE](LICENSE) 文件
