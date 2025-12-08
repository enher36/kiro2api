# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Instruction for CodeX MCP

在任何时刻，你必须思考当前过程可以如何与codex进行协作，如何调用Codex 为你提供的MCP工具作为你客观全面分析的保障。
其中你**务必执行**以下几个步骤：
**1** 在你对用户需求形成初步分析后，将用户需求、初始思路告知codex，并要求其完善需求分析和实施计划。
**2** 在实施具体编码任务前，**必须向codex索要代码实现原型（要求codex仅给出unified diff patch，严禁对代码做任何真实修改）**。在获取代码原型后，你**只能以此为逻辑参考，再次对代码修改进行重写**，形成企业生产级别、可读性极高、可维护性极高的代码后，才能实施具体编程修改任务。
**3** 无论何时，只要完成切实编码行为后，**必须立即使用codex review代码改动和对应需求完成程度**。
**4** codex只能给出参考，你**必须有自己的思考，甚至需要对codex的回答提出置疑**。尽信书则不如无书，你与codex的最终使命都是达成统一、全面、精准的意见，所以你们必须不断争辩已找到通向真理的唯一途径。


## Codex Tool Invocation Specification

 1. 工具概述

  codex MCP 提供了一个工具 `codex`，用于执行 AI 辅助的编码任务。该工具**通过 MCP 协议调用**，无需使用命令行。

  2. 工具参数

  **必选**参数：
  - PROMPT (string): 发送给 codex 的任务指令
  - cd (Path): codex 执行任务的工作目录根路径

  可选参数：
  - sandbox (string): 沙箱策略，可选值：
    - "read-only" (默认): 只读模式，最安全
    - "workspace-write": 允许在工作区写入
    - "danger-full-access": 完全访问权限
  - SESSION_ID (UUID | null): 用于继续之前的会话以与codex进行多轮交互，默认为 None（开启新会话）
  - skip_git_repo_check (boolean): 是否允许在非 Git 仓库中运行，默认 False
  - return_all_messages (boolean): 是否返回所有消息（包括推理、工具调用等），默认 False

  返回值：
  {
    "success": true,
    "SESSION_ID": "uuid-string",
    "agent_messages": "agent回复的文本内容",
    "all_messages": []  // 仅当 return_all_messages=True 时包含
  }
  或失败时：
  {
    "success": false,
    "error": "错误信息"
  }

  3. 使用方式

  开启新对话：
  - 不传 SESSION_ID 参数（或传 None）
  - 工具会返回新的 SESSION_ID 用于后续对话

  继续之前的对话：
  - 将之前返回的 SESSION_ID 作为参数传入
  - 同一会话的上下文会被保留

  4. 调用规范

  **必须遵守**：
  - 每次调用 codex 工具时，必须保存返回的 SESSION_ID，以便后续继续对话
  - cd 参数必须指向存在的目录，否则工具会静默失败
  - 严禁codex对代码进行实际修改，使用 sandbox="read-only" 以避免意外，并要求codex仅给出unified diff patch即可

  推荐用法：
  - 如需详细追踪 codex 的推理过程和工具调用，设置 return_all_messages=True
  - 对于精准定位、debug、代码原型快速编写等任务，优先使用 codex 工具

  5. 注意事项

  - 会话管理：始终追踪 SESSION_ID，避免会话混乱
  - 工作目录：确保 cd 参数指向正确且存在的目录
  - 错误处理：检查返回值的 success 字段，处理可能的错误

## 项目概述

高性能 AI API 代理服务器，桥接 Anthropic/OpenAI API 与 AWS CodeWhisperer。支持流式响应、工具调用、多账号池管理、Web 界面账号管理。

## 开发命令

```bash
# 编译和运行
go build -o kiro2api main.go
./kiro2api

# 测试
go test ./...                          # 运行所有测试
go test ./parser -v                    # 单包测试(详细输出)
go test ./... -bench=. -benchmem       # 基准测试

# 代码质量
go vet ./...                           # 静态检查
go fmt ./...                           # 格式化
golangci-lint run                      # Linter

# 运行模式
GIN_MODE=debug LOG_LEVEL=debug ./kiro2api  # 开发模式
GIN_MODE=release ./kiro2api                # 生产模式

# 生产构建
go build -ldflags="-s -w" -o kiro2api main.go
```

## 技术栈

- **Go**: 1.23+
- **Web**: gin-gonic/gin v1.11.0
- **JSON**: encoding/json（标准库）

## 核心架构

**请求流程**：认证 → 请求分析 → 格式转换 → 流处理 → 响应转换

**包职责**：
- `server/` - HTTP 服务器、路由、处理器、中间件、Token 管理 API
- `converter/` - API 格式转换（Anthropic ↔ OpenAI ↔ CodeWhisperer）
- `parser/` - EventStream 解析、工具调用处理、会话管理
- `auth/` - Token 管理（顺序选择策略、并发控制、动态增删、使用限制监控）
- `utils/` - 请求分析、Token 估算、HTTP 工具
- `types/` - 数据结构定义
- `logger/` - 结构化日志
- `config/` - 配置常量和模型映射
- `static/` - Web Dashboard（HTML/CSS/JS）

**关键实现**：
- Token 管理：顺序选择策略，支持 Social/IdC 双认证，运行时动态增删
- 流式优化：零延迟传输，直接内存分配（已移除对象池）
- 智能超时：根据 MaxTokens、内容长度、工具使用动态调整
- EventStream 解析：`CompliantEventStreamParser`（BigEndian 格式）
- Web Dashboard：实时监控 Token 状态，支持添加/删除账号

## 开发原则

**内存管理**：
- 已移除 `sync.Pool` 对象池（KISS + YAGNI）
- 直接使用 `bytes.NewBuffer(nil)`、`strings.Builder`、`make([]byte, size)`
- 信任 Go GC 和逃逸分析
- 仅在 QPS > 1000 且对象 > 10KB 时考虑对象池

**代码质量**：
- 遵循 KISS、YAGNI、DRY、SOLID 原则
- 避免过度抽象和预先优化
- 定期清理死代码和未使用功能
- 所有包测试通过率 100%

**最近重构**（2025-10）：
- 删除 1101 行死代码（6.8%）
- 简化配置管理（`config/constants.go`、`config/tuning.go`）
- 修复并发测试问题

详见 memory: `refactoring_dead_code_removal_2025_10_08`

## 环境配置

详见 `.env.example` 和 `auth_config.json.example`。

**Token 配置方式**：
- JSON 字符串：`KIRO_AUTH_TOKEN='[{"auth":"Social","refreshToken":"xxx"}]'`
- 文件路径：`KIRO_AUTH_TOKEN=/path/to/auth_config.json`（推荐）

**配置字段**：`auth`（Social/IdC）、`refreshToken`、`clientId`、`clientSecret`、`disabled`

**关键环境变量**：
- `KIRO_CLIENT_TOKEN` - API 认证密钥（可选，默认 123456）
- `KIRO_AUTH_TOKEN` - Token 配置（可选，可通过 Web 界面添加）
- `PORT` - 服务端口（默认 8080）
- `LOG_LEVEL` - 日志级别（debug/info/warn/error）
- `LOG_FORMAT` - 日志格式（text/json）

## API 端点

**代理 API**（需认证）：
- `GET /v1/models` - 获取模型列表
- `POST /v1/messages` - Anthropic API 代理
- `POST /v1/messages/count_tokens` - Token 计数
- `POST /v1/chat/completions` - OpenAI API 代理

**管理 API**（无需认证）：
- `GET /api/tokens` - 获取 Token 池状态
- `POST /api/tokens` - 添加新账号
- `DELETE /api/tokens/:index` - 删除账号

**静态资源**：
- `GET /` - Token Dashboard 首页
- `GET /static/*` - 静态资源

## 快速测试

```bash
# 启动服务（可无需配置直接启动）
./kiro2api

# 访问 Web Dashboard
# http://localhost:8080/

# 测试 Token 池状态
curl http://localhost:8080/api/tokens

# 添加账号
curl -X POST http://localhost:8080/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"auth":"Social","refreshToken":"your_refresh_token"}'

# 测试 API
curl -X POST http://localhost:8080/v1/messages \
  -H "Authorization: Bearer 123456" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":100,"messages":[{"role":"user","content":"测试"}]}'
```
