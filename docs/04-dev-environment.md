# 04-dev-environment.md

# FlowStudy 本地开发环境规范

## 1. 文档目标

本文档用于统一 FlowStudy 项目的本地开发环境，避免团队成员出现“代码在我的电脑上可以运行，在别人电脑上不能运行”的问题。

FlowStudy 采用多仓库、多语言、多服务架构。前端、Java Core 服务、Go Judge 服务、Python AI 服务，以及 MySQL、Redis、RabbitMQ 等中间件需要在统一环境下协同工作。因此，所有开发者必须优先按照本文档配置开发环境，再开始业务编码。

---

## 2. 项目服务组成

FlowStudy 本地开发环境包含以下服务：

| 类型 | 服务名称 | 仓库 | 主要职责 |
|---|---|---|---|
| 前端 | flowstudy-frontend | flowstudy-frontend | 页面展示、文章阅读、代码编辑器、AI 侧边栏 |
| 后端主服务 | flowstudy-core | flowstudy-core | 用户、文章、题目、提交记录、限流、MQ 投递 |
| 判题服务 | flowstudy-judge | flowstudy-judge | 消费判题任务、运行代码、回传判题结果 |
| AI 服务 | flowstudy-ai | flowstudy-ai | AI 问答、上下文拼接、行为分析、笔记生成 |
| 基础设施 | flowstudy-infra | flowstudy-infra | Docker Compose、SQL、文档、部署脚本 |

本地开发阶段，建议先启动基础设施服务，再分别启动 Core、Judge、AI 和 Frontend。

---

## 3. 推荐操作系统

优先推荐以下环境：

| 环境 | 推荐程度 | 说明 |
|---|---:|---|
| Linux / Ubuntu | 高 | 最适合后端、Go、Python、Docker、沙箱开发 |
| Windows + WSL2 Ubuntu | 高 | Windows 用户推荐方案，兼顾开发体验和 Linux 环境 |
| macOS | 中 | 适合前端、后端开发，但沙箱相关能力需要额外适配 |
| Windows 原生环境 | 低 | 不推荐直接在 Windows 原生环境开发 Judge 沙箱模块 |

如果使用 Windows，推荐使用：

```bash
Windows 11 + WSL2 + Ubuntu 22.04/24.04 + Docker Desktop
```

---

## 4. 基础软件版本要求

### 4.1 必装软件

| 软件 | 推荐版本 | 用途 |
|---|---|---|
| Git | 2.40+ | 代码管理 |
| Docker | 24+ | 容器运行 |
| Docker Compose | v2+ | 本地中间件编排 |
| Node.js | 20 LTS+ | 前端开发 |
| pnpm | 9+ | 前端包管理 |
| JDK | 17+ | Spring Boot 3 开发 |
| Maven | 3.9+ | Java 项目构建 |
| Go | 1.22+ | 判题服务开发 |
| Python | 3.11+ | AI 服务开发 |
| uv / pip | 最新稳定版 | Python 依赖管理 |
| MySQL Client | 8+ | 数据库调试 |
| Redis CLI | 7+ | Redis 调试 |

### 4.2 中间件版本

| 中间件 | 推荐版本 | 本地启动方式 |
|---|---|---|
| MySQL | 8.4 | Docker Compose |
| Redis | 7.2 | Docker Compose |
| RabbitMQ | 3.13-management | Docker Compose |

---

## 5. 本地端口规范

| 服务 | 端口 | 访问地址 |
|---|---:|---|
| flowstudy-frontend | 5173 | http://localhost:5173 |
| flowstudy-core | 8080 | http://localhost:8080 |
| flowstudy-ai | 8000 | http://localhost:8000 |
| flowstudy-judge | 9000 | http://localhost:9000 |
| MySQL | 3306 | localhost:3306 |
| Redis | 6379 | localhost:6379 |
| RabbitMQ AMQP | 5672 | localhost:5672 |
| RabbitMQ Management | 15672 | http://localhost:15672 |

RabbitMQ 管理后台默认账号：

```text
username: flowstudy
password: flowstudy123
```

---

## 6. 推荐仓库目录布局

建议在本地使用同一个父目录管理所有 FlowStudy 仓库：

```text
workspace/
└── flowstudy/
    ├── flowstudy-frontend/
    ├── flowstudy-core/
    ├── flowstudy-judge/
    ├── flowstudy-ai/
    └── flowstudy-infra/
```

克隆示例：

```bash
mkdir -p ~/workspace/flowstudy
cd ~/workspace/flowstudy

git clone git@github.com:FlowStudy/flowstudy-frontend.git
git clone git@github.com:FlowStudy/flowstudy-core.git
git clone git@github.com:FlowStudy/flowstudy-judge.git
git clone git@github.com:FlowStudy/flowstudy-ai.git
git clone git@github.com:FlowStudy/flowstudy-infra.git
```

---

## 7. Docker Compose 基础设施启动

`docker-compose.yml` 放在：

```text
flowstudy-infra/docker-compose.yml
```

启动中间件：

```bash
cd flowstudy-infra
docker compose up -d
```

查看容器状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f mysql
docker compose logs -f redis
docker compose logs -f rabbitmq
```

停止服务：

```bash
docker compose down
```

清空所有数据并重新启动：

```bash
docker compose down -v
docker compose up -d
```

---

## 8. flowstudy-core 本地运行规范

### 8.1 技术栈

```text
Java 17
Spring Boot 3.x
Spring MVC
MyBatis-Plus
MySQL
Redis
RabbitMQ
JWT
```

### 8.2 环境变量

`flowstudy-core/.env.example`：

```env
APP_NAME=flowstudy-core
APP_PORT=8080

SPRING_PROFILES_ACTIVE=dev

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DATABASE=flowstudy
MYSQL_USERNAME=flowstudy
MYSQL_PASSWORD=flowstudy123

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=flowstudy
RABBITMQ_PASSWORD=flowstudy123
RABBITMQ_VHOST=/

JWT_SECRET=please-change-this-secret
JWT_EXPIRE_SECONDS=7200

AI_SERVICE_BASE_URL=http://localhost:8000
JUDGE_SUBMIT_EXCHANGE=fs.judge.exchange
JUDGE_SUBMIT_ROUTING_KEY=judge.submit.created

CORS_ALLOWED_ORIGINS=http://localhost:5173
SUBMIT_RATE_LIMIT_PER_MINUTE=20
```

### 8.3 启动命令

```bash
cd flowstudy-core
mvn clean package -DskipTests
mvn spring-boot:run
```

或者在 IDEA 中直接运行主启动类。

### 8.4 健康检查接口

```http
GET http://localhost:8080/api/v1/health
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "service": "flowstudy-core",
    "status": "UP"
  },
  "traceId": "local-dev",
  "timestamp": 1710000000000
}
```

---

## 9. flowstudy-judge 本地运行规范

### 9.1 技术栈

```text
Go 1.22+
RabbitMQ Client
Docker Sandbox / Linux Sandbox
C/C++ Runner
Java Runner
Python Runner
Go Runner
```

### 9.2 环境变量

`flowstudy-judge/.env.example`：

```env
APP_NAME=flowstudy-judge
APP_PORT=9000

RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=flowstudy
RABBITMQ_PASSWORD=flowstudy123
RABBITMQ_VHOST=/

JUDGE_SUBMIT_QUEUE=fs.judge.submit.queue
JUDGE_RESULT_EXCHANGE=fs.judge.result.exchange
JUDGE_RESULT_ROUTING_KEY=judge.result.finished

SANDBOX_WORK_DIR=/tmp/flowstudy-sandbox
SANDBOX_MAX_CONCURRENCY=4
SANDBOX_DEFAULT_TIME_LIMIT_MS=1000
SANDBOX_DEFAULT_MEMORY_LIMIT_MB=256

ENABLE_DOCKER_SANDBOX=true
DOCKER_JAVA_IMAGE=flowstudy/java-runner:17
DOCKER_CPP_IMAGE=flowstudy/cpp-runner:latest
DOCKER_GO_IMAGE=flowstudy/go-runner:1.22
DOCKER_PYTHON_IMAGE=flowstudy/python-runner:3.11
```

### 9.3 启动命令

```bash
cd flowstudy-judge
go mod tidy
go run ./cmd/server
```

### 9.4 健康检查接口

```http
GET http://localhost:9000/health
```

---

## 10. flowstudy-ai 本地运行规范

### 10.1 技术栈

```text
Python 3.11+
FastAPI
Uvicorn
LangGraph
RabbitMQ Client
LLM API
SSE
```

### 10.2 环境变量

`flowstudy-ai/.env.example`：

```env
APP_NAME=flowstudy-ai
APP_PORT=8000

CORE_SERVICE_BASE_URL=http://localhost:8080
INTERNAL_API_TOKEN=please-change-this-internal-token

RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=flowstudy
RABBITMQ_PASSWORD=flowstudy123
RABBITMQ_VHOST=/

AI_BEHAVIOR_QUEUE=fs.ai.behavior.queue
AI_NOTE_QUEUE=fs.ai.note.queue

LLM_PROVIDER=openai
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=your-api-key
LLM_CHAT_MODEL=gpt-4o-mini
LLM_EMBEDDING_MODEL=text-embedding-3-small

VECTOR_STORE_TYPE=local
VECTOR_STORE_DIR=./data/vector_store

CORS_ALLOWED_ORIGINS=http://localhost:5173
```

### 10.3 启动命令

使用 `uv`：

```bash
cd flowstudy-ai
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

使用 `pip`：

```bash
cd flowstudy-ai
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 10.4 健康检查接口

```http
GET http://localhost:8000/api/v1/health
```

---

## 11. flowstudy-frontend 本地运行规范

### 11.1 技术栈

```text
Vue 3
TypeScript
Vite
pnpm
Monaco Editor
Markdown Renderer
SSE Client
```

### 11.2 环境变量

`flowstudy-frontend/.env.example`：

```env
VITE_APP_NAME=FlowStudy
VITE_API_BASE_URL=http://localhost:8080/api/v1
VITE_AI_BASE_URL=http://localhost:8000/api/v1
VITE_ENABLE_AI_SIDEBAR=true
VITE_ENABLE_TRACKING=true
```

### 11.3 启动命令

```bash
cd flowstudy-frontend
pnpm install
pnpm dev
```

访问：

```text
http://localhost:5173
```

---

## 12. 推荐启动顺序

本地开发时推荐按以下顺序启动：

```text
1. flowstudy-infra：启动 MySQL、Redis、RabbitMQ
2. flowstudy-core：启动 Java 主业务服务
3. flowstudy-judge：启动 Go 判题服务
4. flowstudy-ai：启动 Python AI 服务
5. flowstudy-frontend：启动前端开发服务器
```

对应命令：

```bash
cd flowstudy-infra
docker compose up -d

cd ../flowstudy-core
mvn spring-boot:run

cd ../flowstudy-judge
go run ./cmd/server

cd ../flowstudy-ai
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

cd ../flowstudy-frontend
pnpm dev
```

---

## 13. 环境变量安全规范

所有仓库必须提交：

```text
.env.example
```

所有仓库禁止提交：

```text
.env
.env.local
.env.production
```

`.gitignore` 必须包含：

```gitignore
.env
.env.*
!.env.example
```

禁止将以下内容写死在代码中：

```text
数据库密码
Redis 密码
RabbitMQ 密码
JWT Secret
LLM API Key
内部服务 Token
服务器 IP 和生产环境域名
```

---

## 14. 常见问题

### 14.1 MySQL 端口被占用

如果本机已经安装 MySQL，可能会占用 `3306` 端口。可以修改 `docker-compose.yml`：

```yaml
ports:
  - "3307:3306"
```

同时修改 Core 服务环境变量：

```env
MYSQL_PORT=3307
```

### 14.2 RabbitMQ 管理后台打不开

先检查容器是否启动：

```bash
docker compose ps
```

再查看日志：

```bash
docker compose logs -f rabbitmq
```

确认访问地址：

```text
http://localhost:15672
```

### 14.3 前端跨域报错

确认 `flowstudy-core` 的 CORS 配置包含：

```env
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

AI 服务也需要允许前端来源：

```env
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

### 14.4 Judge 服务消费不到消息

检查以下内容：

```text
RabbitMQ 地址是否正确
队列名是否正确
Exchange 是否声明成功
RoutingKey 是否一致
Core 是否已经投递 judge.submit.created 消息
Judge 是否绑定 fs.judge.submit.queue
```

---

## 15. 本文档维护规则

当以下内容发生变化时，必须同步更新本文档：

```text
服务端口变化
环境变量变化
中间件版本变化
启动命令变化
本地开发依赖变化
Docker Compose 配置变化
```

所有开发者在修改本地环境规范时，必须通过 Pull Request 提交，并由至少一名相关模块负责人 Review。
