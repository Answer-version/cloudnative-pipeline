# =================================================================
# Example App Dockerfile
# 多阶段构建：构建阶段 + 运行阶段
# =================================================================

# ===== 阶段 1: 构建阶段 =====
FROM golang:1.21-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache git ca-certificates tzdata

# 设置工作目录
WORKDIR /build

# 复制 go mod 文件
COPY go.mod go.sum* ./

# 下载依赖（利用 Docker 缓存）
RUN go mod download

# 复制源代码
COPY . .

# 构建二进制文件
# CGO_ENABLED=0 表示静态编译，无需 C 运行时
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" \
    -o example-app \
    main.go

# ===== 阶段 2: 运行阶段 =====
FROM alpine:3.19

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    && update-ca-certificates

# 创建非 root 用户
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /build/example-app .

# 复制静态资源（如果有）
COPY --from=builder /build/assets ./assets

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8081

# 环境变量
ENV PORT=8081
ENV GIN_MODE=release

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# 启动命令
ENTRYPOINT ["./example-app"]
