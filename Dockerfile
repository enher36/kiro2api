# 简化版 Dockerfile - 无 CGO 依赖
# 构建阶段
FROM golang:alpine AS builder

WORKDIR /app

# 安装 git（部分依赖需要）
RUN apk add --no-cache git ca-certificates tzdata

# 复制依赖文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源码
COPY . .

# 更新依赖并编译（禁用 CGO）
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o kiro2api main.go

# 运行阶段
FROM alpine:3.19

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata

# 创建非 root 用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# 从构建阶段复制
COPY --from=builder /app/kiro2api .
COPY --from=builder /app/static ./static

# 创建数据目录并设置权限
RUN mkdir -p /app/data /home/appuser/.aws/sso/cache && \
    chown -R appuser:appgroup /app /home/appuser && \
    chmod 755 /app/data

USER appuser

EXPOSE 8080

CMD ["./kiro2api"]
