# ===================================================================
# Stage 1: Builder - 编译阶段
# ===================================================================
# 使用 Go 官方镜像作为构建环境
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache git ca-certificates tzdata

# 设置工作目录
WORKDIR /build

# ===================================================================
# Stage 2: Development - 开发环境
# ===================================================================
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS dev

# 安装开发工具
RUN apk add --no-cache git docker-cli-compose

# 设置工作目录
WORKDIR /app

# 复制源码（利用 Docker 缓存层）
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# 挂载源码卷（开发时热重载）
VOLUME [ "/app" ]

# 暴露端口
EXPOSE 8080

# 启动命令
CMD ["air", "-c", ".air.toml"]

# ===================================================================
# Stage 3: Builder - 实际编译（交叉编译支持）
# ===================================================================
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS builder-actual

ARG TARGETOS
ARG TARGETARCH

WORKDIR /build

# 复制 go.mod 和 go.sum 以利用缓存
COPY go.mod go.sum ./
RUN go mod download

# 复制源码
COPY . .

# 使用静态编译选项构建二进制文件
# CGO_ENABLED=0: 静态编译，不需要 C 运行时库
# -ldflags: 剥离调试信息，减小二进制大小
# -trimpath: 移除文件系统路径信息，提高可重复性
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w -extldflags=-static" \
    -o app .

# ===================================================================
# Stage 4: Distroless Runtime - 生产环境
# ===================================================================
# 使用 distroless 镜像，体积最小，仅包含运行时依赖
FROM --platform=$BUILDPLATFORM gcr.io/distroless/static:nonroot AS runtime

# 创建非 root 用户组
USER nonroot:nonroot

# 设置工作目录
WORKDIR /app

# 从 builder 阶段复制编译好的二进制文件
COPY --from=builder-actual /build/app .

# 复制静态资源（如果存在）
COPY --from=builder-actual /build/public ./public

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

# 设置环境变量
ENV PORT=8080
ENV GIN_MODE=release

# 启动应用
ENTRYPOINT ["./app"]

# ===================================================================
# 构建说明
# -------------------------------------------------------------------
# 开发环境构建:
#   docker build --target dev -t cloudnative-pipeline:dev .
#
# 生产环境构建 (默认):
#   docker build -t cloudnative-pipeline:latest .
#
# 交叉编译示例 (Linux amd64):
#   docker buildx build --platform linux/amd64 -t cloudnative-pipeline:latest .
#
# 运行:
#   docker run -p 8080:8080 cloudnative-pipeline:latest
# ===================================================================
