#!/bin/bash
# Kiro2API Docker 一键启动脚本
# 无需本地 Go 环境，仅需 Docker

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONTAINER_NAME="kiro2api"
IMAGE_NAME="kiro2api:latest"
PORT="${PORT:-8080}"

log_info() { echo -e "${GREEN}[信息]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error() { echo -e "${RED}[错误]${NC} $1"; }
log_step() { echo -e "${BLUE}[步骤]${NC} $1"; }

# 生成随机密码
generate_password() {
    local length=${1:-16}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# 检查 Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "未找到 Docker，请先安装 Docker"
        log_info "安装命令: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    log_info "Docker 已安装: $(docker --version)"
}

# 停止旧容器
stop_existing() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warn "停止旧容器..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
}

# 构建镜像
build_image() {
    log_step "构建 Docker 镜像..."
    docker build -t "$IMAGE_NAME" . || {
        log_error "构建失败"
        exit 1
    }
    log_info "镜像构建成功"
}

# 启动容器
start_container() {
    log_step "启动容器..."

    # 生成密码
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(generate_password 16)}"
    KIRO_CLIENT_TOKEN="${KIRO_CLIENT_TOKEN:-$(generate_password 32)}"

    # 创建数据目录（用于持久化配置）
    mkdir -p "$(pwd)/data"

    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "${PORT}:8080" \
        -e ADMIN_USERNAME="${ADMIN_USERNAME:-admin}" \
        -e ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        -e KIRO_CLIENT_TOKEN="$KIRO_CLIENT_TOKEN" \
        -e AUTH_CONFIG_FILE="/app/data/auth_config.json" \
        -e GIN_MODE=release \
        -v "$(pwd)/data:/app/data" \
        --restart unless-stopped \
        "$IMAGE_NAME"
    
    sleep 2
    
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "容器启动成功"
    else
        log_error "容器启动失败"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
}

# 显示结果
show_result() {
    local LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "<局域网IP>")
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   Docker 容器启动成功！                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 访问地址 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}本地访问:${NC}    http://localhost:${PORT}/"
    echo -e "  ${BLUE}局域网访问:${NC}  http://${LAN_IP}:${PORT}/"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 管理后台 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}用户名:${NC}      ${YELLOW}${ADMIN_USERNAME:-admin}${NC}"
    echo -e "  ${BLUE}密码:${NC}        ${YELLOW}${ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ API 配置 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}API Token:${NC}   ${YELLOW}${KIRO_CLIENT_TOKEN}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 常用命令 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}查看日志:${NC}    docker logs -f $CONTAINER_NAME"
    echo -e "  ${BLUE}停止服务:${NC}    docker stop $CONTAINER_NAME"
    echo -e "  ${BLUE}重启服务:${NC}    docker restart $CONTAINER_NAME"
    echo ""
}

# 主流程
main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║              Kiro2API Docker 一键启动                             ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_docker
    stop_existing
    build_image
    start_container
    show_result
}

main "$@"
