#!/bin/bash
# ============================================================================
# Kiro2API 一键启动脚本
# ============================================================================
# 功能：自动检测系统、安装依赖、编译运行、显示访问信息
# 作者：Kiro2API Team
# ============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 配置文件
ENV_FILE=".env"
CONFIG_FILE=".kiro_config"

# ============================================================================
# 工具函数
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║   ██╗  ██╗██╗██████╗  ██████╗ ██████╗  █████╗ ██████╗ ██╗        ║"
    echo "║   ██║ ██╔╝██║██╔══██╗██╔═══██╗╚════██╗██╔══██╗██╔══██╗██║        ║"
    echo "║   █████╔╝ ██║██████╔╝██║   ██║ █████╔╝███████║██████╔╝██║        ║"
    echo "║   ██╔═██╗ ██║██╔══██╗██║   ██║██╔═══╝ ██╔══██║██╔═══╝ ██║        ║"
    echo "║   ██║  ██╗██║██║  ██║╚██████╔╝███████╗██║  ██║██║     ██║        ║"
    echo "║   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝        ║"
    echo "║                                                                   ║"
    echo "║                    AI API 代理服务 - 一键启动                     ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[步骤]${NC} $1"
}

# 生成随机密码
generate_password() {
    local length=${1:-16}
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$length"
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
    fi
}

# ============================================================================
# 系统检测
# ============================================================================

detect_os() {
    log_step "检测操作系统..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS_NAME="Red Hat"
        OS_ID="rhel"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="macOS"
        OS_ID="macos"
        OS_VERSION=$(sw_vers -productVersion)
    else
        OS_NAME="未知"
        OS_ID="unknown"
    fi

    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_NAME="amd64" ;;
        aarch64|arm64) ARCH_NAME="arm64" ;;
        armv7l) ARCH_NAME="armv7" ;;
        *) ARCH_NAME="$ARCH" ;;
    esac

    log_info "操作系统: ${OS_NAME} ${OS_VERSION:-}"
    log_info "系统架构: ${ARCH} (${ARCH_NAME})"
}

# ============================================================================
# 依赖安装
# ============================================================================

check_go() {
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        log_info "Go 已安装: v${GO_VERSION}"
        return 0
    fi
    return 1
}

install_go() {
    log_step "安装 Go 语言环境..."

    local GO_VERSION="1.24.0"
    local GO_TAR="go${GO_VERSION}.linux-${ARCH_NAME}.tar.gz"
    local GO_URL="https://go.dev/dl/${GO_TAR}"

    case $OS_ID in
        ubuntu|debian|linuxmint|pop)
            log_info "使用 apt 安装 Go..."
            sudo apt-get update -qq
            sudo apt-get install -y golang-go || {
                log_warn "apt 安装失败，尝试手动安装..."
                install_go_manual
            }
            ;;
        centos|rhel|fedora|rocky|almalinux)
            log_info "使用 dnf/yum 安装 Go..."
            if command -v dnf &> /dev/null; then
                sudo dnf install -y golang
            else
                sudo yum install -y golang
            fi
            ;;
        arch|manjaro)
            log_info "使用 pacman 安装 Go..."
            sudo pacman -Sy --noconfirm go
            ;;
        opensuse*)
            log_info "使用 zypper 安装 Go..."
            sudo zypper install -y go
            ;;
        macos)
            if command -v brew &> /dev/null; then
                log_info "使用 Homebrew 安装 Go..."
                brew install go
            else
                log_error "请先安装 Homebrew: https://brew.sh"
                exit 1
            fi
            ;;
        *)
            install_go_manual
            ;;
    esac
}

install_go_manual() {
    log_info "手动下载安装 Go..."

    local GO_VERSION="1.24.0"
    local GO_TAR="go${GO_VERSION}.linux-${ARCH_NAME}.tar.gz"
    local GO_URL="https://go.dev/dl/${GO_TAR}"

    cd /tmp
    curl -LO "$GO_URL" || wget "$GO_URL"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$GO_TAR"
    rm -f "$GO_TAR"

    # 添加到 PATH
    if ! grep -q '/usr/local/go/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    export PATH=$PATH:/usr/local/go/bin

    cd "$SCRIPT_DIR"
    log_info "Go 安装完成"
}

install_dependencies() {
    log_step "检查系统依赖..."

    # 检查 curl 或 wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log_warn "安装 curl..."
        case $OS_ID in
            ubuntu|debian) sudo apt-get install -y curl ;;
            centos|rhel|fedora) sudo dnf install -y curl || sudo yum install -y curl ;;
            arch|manjaro) sudo pacman -Sy --noconfirm curl ;;
        esac
    fi

    # 检查 Go
    if ! check_go; then
        install_go
        if ! check_go; then
            log_error "Go 安装失败，请手动安装后重试"
            log_error "访问 https://go.dev/dl/ 下载安装"
            exit 1
        fi
    fi
}

# ============================================================================
# 编译项目
# ============================================================================

build_project() {
    log_step "编译项目..."

    if [[ ! -f "go.mod" ]]; then
        log_error "未找到 go.mod 文件，请确保在项目目录中运行"
        exit 1
    fi

    # 下载依赖
    log_info "下载依赖包..."
    go mod tidy

    # 编译
    log_info "编译可执行文件..."
    CGO_ENABLED=0 go build -ldflags="-s -w" -o kiro2api main.go

    if [[ -f "kiro2api" ]]; then
        log_info "编译成功: $(ls -lh kiro2api | awk '{print $5}')"
    else
        log_error "编译失败"
        exit 1
    fi
}

# ============================================================================
# 配置管理
# ============================================================================

load_or_create_config() {
    log_step "加载配置..."

    # 默认值
    PORT="${PORT:-8080}"
    ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"

    # 从配置文件加载（如果存在）
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "已加载保存的配置"
    fi

    # 从 .env 文件加载
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
        log_info "已加载 .env 配置"
    fi

    # 生成密码（如果未设置）
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD=$(generate_password 16)
        log_warn "已生成随机管理员密码"
    fi

    if [[ -z "$KIRO_CLIENT_TOKEN" ]]; then
        KIRO_CLIENT_TOKEN=$(generate_password 32)
        log_warn "已生成随机 API Token"
    fi

    # 保存配置（不包含敏感信息）
    cat > "$CONFIG_FILE" << EOF
# Kiro2API 配置（自动生成，请勿手动修改）
PORT=$PORT
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD
KIRO_CLIENT_TOKEN=$KIRO_CLIENT_TOKEN
EOF
    chmod 600 "$CONFIG_FILE"
}

# ============================================================================
# 服务管理
# ============================================================================

stop_existing() {
    if pgrep -f "kiro2api" > /dev/null 2>&1; then
        log_warn "停止已运行的服务..."
        pkill -f "kiro2api" || true
        sleep 1
    fi
}

start_service() {
    log_step "启动服务..."

    stop_existing

    # 导出环境变量
    export PORT
    export ADMIN_USERNAME
    export ADMIN_PASSWORD
    export KIRO_CLIENT_TOKEN
    export GIN_MODE=release

    # 启动服务
    nohup ./kiro2api > kiro2api.log 2>&1 &
    local PID=$!

    # 等待启动
    sleep 2

    if kill -0 $PID 2>/dev/null; then
        echo $PID > kiro2api.pid
        log_info "服务启动成功 (PID: $PID)"
        return 0
    else
        log_error "服务启动失败，查看日志: tail -f kiro2api.log"
        return 1
    fi
}

# ============================================================================
# 获取访问地址
# ============================================================================

get_ip_addresses() {
    # 获取本机 IP
    LOCAL_IP="127.0.0.1"

    # 尝试获取局域网 IP
    LAN_IP=""
    if command -v hostname &> /dev/null; then
        LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [[ -z "$LAN_IP" ]] && command -v ip &> /dev/null; then
        LAN_IP=$(ip -4 addr show scope global 2>/dev/null | grep inet | head -1 | awk '{print $2}' | cut -d/ -f1)
    fi
    if [[ -z "$LAN_IP" ]] && command -v ifconfig &> /dev/null; then
        LAN_IP=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
    fi

    [[ -z "$LAN_IP" || "$LAN_IP" == "127.0.0.1" ]] && LAN_IP="<局域网IP>"
}

# ============================================================================
# 显示结果
# ============================================================================

show_result() {
    get_ip_addresses

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                      服务启动成功！                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 访问地址 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}本地访问:${NC}    http://localhost:${PORT}/"
    echo -e "  ${BLUE}局域网访问:${NC}  http://${LAN_IP}:${PORT}/"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 管理后台 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}登录地址:${NC}    http://localhost:${PORT}/static/login.html"
    echo -e "  ${BLUE}用户名:${NC}      ${YELLOW}${ADMIN_USERNAME}${NC}"
    echo -e "  ${BLUE}密码:${NC}        ${YELLOW}${ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ API 配置 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}API 端点:${NC}    http://localhost:${PORT}/v1/messages"
    echo -e "  ${BLUE}API Token:${NC}   ${YELLOW}${KIRO_CLIENT_TOKEN}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 使用示例 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  # Anthropic API 格式"
    echo -e "  curl -X POST http://localhost:${PORT}/v1/messages \\"
    echo -e "    -H 'Authorization: Bearer ${KIRO_CLIENT_TOKEN}' \\"
    echo -e "    -H 'Content-Type: application/json' \\"
    echo -e "    -d '{\"model\":\"claude-sonnet-4-20250514\",\"max_tokens\":100,\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}]}'"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━ 常用命令 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}查看日志:${NC}    tail -f kiro2api.log"
    echo -e "  ${BLUE}停止服务:${NC}    pkill -f kiro2api"
    echo -e "  ${BLUE}重启服务:${NC}    ./start.sh"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  提示: 请在管理后台添加 AWS Token 后才能正常调用 API              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    print_banner

    echo ""
    log_step "开始初始化..."
    echo ""

    # 1. 检测系统
    detect_os

    # 2. 安装依赖
    install_dependencies

    # 3. 编译项目（如果需要）
    if [[ ! -f "kiro2api" ]] || [[ "main.go" -nt "kiro2api" ]]; then
        build_project
    else
        log_info "可执行文件已是最新，跳过编译"
    fi

    # 4. 加载配置
    load_or_create_config

    # 5. 启动服务
    if start_service; then
        show_result
    else
        exit 1
    fi
}

# 运行
main "$@"
