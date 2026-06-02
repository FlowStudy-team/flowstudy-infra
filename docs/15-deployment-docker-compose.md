# 15. 部署与 Docker Compose 文档

## 1. 文档目的

本文档定义 FlowStudy 本地开发环境、Docker Compose 编排方式、服务端口、环境变量、启动顺序、停止清理、生产部署建议与常见问题排查。

FlowStudy 采用多服务架构，至少包含：

```text
flowstudy-frontend
flowstudy-core
flowstudy-judge
flowstudy-ai
MySQL
Redis
RabbitMQ
```

MVP 阶段可以先使用 Docker Compose 在本机统一启动基础设施，再分别运行业务服务。

## 2. 推荐仓库位置

建议放在 `flowstudy-infra` 仓库：

```text
flowstudy-infra/
├── docker-compose.yml
├── mysql/
│   └── init/
│       └── 01-init.sql
├── nginx/
│   └── nginx.conf
├── env/
│   ├── core.env.example
│   ├── ai.env.example
│   ├── judge.env.example
│   └── frontend.env.example
├── scripts/
└── docs/
```

## 3. 本地端口规划

| 服务 | 端口 | 说明 |
|---|---:|---|
| `flowstudy-frontend` | `5173` | Vite 前端开发服务 |
| `flowstudy-core` | `8080` | Java Core Service |
| `flowstudy-ai` | `8000` | Python AI Service |
| `flowstudy-judge` | `9000` | Go Judge Service 健康检查端口 |
| MySQL | `3306` | 数据库 |
| Redis | `6379` | 缓存与限流 |
| RabbitMQ | `5672` | AMQP 通信 |
| RabbitMQ Management | `15672` | RabbitMQ 管理后台 |
| Nginx | `80 / 443` | 生产统一入口 |

## 4. MVP 基础设施 docker-compose

MVP 第一版可以先只启动中间件：

```yaml
version: "3.9"

services:
  mysql:
    image: mysql:8.4
    container_name: flowstudy-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root123456
      MYSQL_DATABASE: flowstudy
      MYSQL_USER: flowstudy
      MYSQL_PASSWORD: flowstudy123
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - flowstudy_mysql_data:/var/lib/mysql
      - ./mysql/init:/docker-entrypoint-initdb.d
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    networks:
      - flowstudy-net

  redis:
    image: redis:7.2-alpine
    container_name: flowstudy-redis
    restart: always
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - flowstudy_redis_data:/data
    networks:
      - flowstudy-net

  rabbitmq:
    image: rabbitmq:3.13-management
    container_name: flowstudy-rabbitmq
    restart: always
    environment:
      RABBITMQ_DEFAULT_USER: flowstudy
      RABBITMQ_DEFAULT_PASS: flowstudy123
      RABBITMQ_DEFAULT_VHOST: /
      TZ: Asia/Shanghai
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - flowstudy_rabbitmq_data:/var/lib/rabbitmq
    networks:
      - flowstudy-net

volumes:
  flowstudy_mysql_data:
  flowstudy_redis_data:
  flowstudy_rabbitmq_data:

networks:
  flowstudy-net:
    driver: bridge
```

## 5. 启动与停止命令

进入 `flowstudy-infra`：

```bash
cd flowstudy-infra
```

启动：

```bash
docker compose up -d
```

查看容器：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f mysql
docker compose logs -f redis
docker compose logs -f rabbitmq
```

停止：

```bash
docker compose down
```

停止并清空数据：

```bash
docker compose down -v
```

## 6. RabbitMQ 管理后台

地址：

```text
http://localhost:15672
```

账号：

```text
username: flowstudy
password: flowstudy123
```

需要确认：

```text
1. Exchange 是否创建
2. Queue 是否创建
3. Binding 是否正确
4. 消息是否堆积
5. DLQ 是否有异常消息
```

## 7. MySQL 初始化

初始化脚本位置：

```text
mysql/init/01-init.sql
```

`docker-compose.yml` 挂载：

```yaml
volumes:
  - ./mysql/init:/docker-entrypoint-initdb.d
```

注意：

```text
1. MySQL 只会在首次初始化数据目录时执行 init 脚本
2. 如果修改了 01-init.sql 后想重新执行，需要 docker compose down -v
3. 不要在 SQL 里写真实密码或生产密钥
```

## 8. 环境变量示例

### 8.1 Core

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
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

### 8.2 AI

```env
APP_NAME=flowstudy-ai
APP_PORT=8000
CORE_SERVICE_BASE_URL=http://localhost:8080
INTERNAL_API_TOKEN=please-change-this-internal-token
LLM_PROVIDER=openai
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=your-api-key
LLM_CHAT_MODEL=gpt-4o-mini
```

### 8.3 Judge

```env
APP_NAME=flowstudy-judge
APP_PORT=9000
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=flowstudy
RABBITMQ_PASSWORD=flowstudy123
SANDBOX_WORK_DIR=/tmp/flowstudy-sandbox
SANDBOX_MAX_CONCURRENCY=4
```

### 8.4 Frontend

```env
VITE_APP_NAME=FlowStudy
VITE_API_BASE_URL=http://localhost:8080/api/v1
VITE_AI_BASE_URL=http://localhost:8000/api/v1
VITE_ENABLE_AI_SIDEBAR=true
VITE_ENABLE_TRACKING=true
```

## 9. 本地开发启动顺序

```text
1. 启动 MySQL / Redis / RabbitMQ
2. 启动 flowstudy-core
3. 启动 flowstudy-judge
4. 启动 flowstudy-ai
5. 启动 flowstudy-frontend
```

命令示例：

```bash
cd flowstudy-infra
docker compose up -d

cd ../flowstudy-core
mvn spring-boot:run

cd ../flowstudy-ai
uvicorn app.main:app --reload --port 8000

cd ../flowstudy-frontend
npm install
npm run dev
```

## 10. 全服务 Compose 设计建议

后期可以扩展：

```yaml
services:
  flowstudy-core:
    build:
      context: ../flowstudy-core
    ports:
      - "8080:8080"
    depends_on:
      - mysql
      - redis
      - rabbitmq
    networks:
      - flowstudy-net

  flowstudy-ai:
    build:
      context: ../flowstudy-ai
    ports:
      - "8000:8000"
    depends_on:
      - flowstudy-core
      - rabbitmq
    networks:
      - flowstudy-net

  flowstudy-judge:
    build:
      context: ../flowstudy-judge
    ports:
      - "9000:9000"
    depends_on:
      - rabbitmq
    networks:
      - flowstudy-net

  flowstudy-frontend:
    build:
      context: ../flowstudy-frontend
    ports:
      - "5173:5173"
    depends_on:
      - flowstudy-core
      - flowstudy-ai
    networks:
      - flowstudy-net
```

## 11. 服务内网访问

在 Docker network 中，不要用 localhost 调用其他容器，应使用服务名：

```text
http://flowstudy-core:8080
http://flowstudy-ai:8000
amqp://flowstudy-rabbitmq:5672
jdbc:mysql://mysql:3306/flowstudy
```

本机开发时才使用 `localhost`。

## 12. Nginx 生产转发建议

生产统一入口：

```text
https://flowstudy.example.com
```

路由：

```text
/                       -> frontend
/api/v1/**              -> flowstudy-core
/api/v1/ai/**           -> flowstudy-ai
```

Judge 不对公网暴露。

SSE 接口需要关闭代理缓冲：

```nginx
proxy_buffering off;
```

## 13. 常见问题

### 13.1 修改 SQL 后没有生效

原因：MySQL 数据卷已初始化，init 脚本不会重复执行。

解决：

```bash
docker compose down -v
docker compose up -d
```

### 13.2 Core 连不上 MySQL

本机运行 Core：

```text
MYSQL_HOST=localhost
```

容器运行 Core：

```text
MYSQL_HOST=mysql
```

### 13.3 AI SSE 没有流式效果

检查：

```text
1. Nginx 是否 proxy_buffering off
2. 前端是否使用 EventSource / fetch stream
3. 接口 Content-Type 是否为 text/event-stream
```

## 14. MVP 验收标准

```text
1. docker compose up -d 后 MySQL / Redis / RabbitMQ 正常运行
2. MySQL 初始化脚本成功执行
3. Core 能连接 MySQL / Redis / RabbitMQ
4. RabbitMQ 管理后台能登录
5. 前端能访问 Core API
6. AI 服务能访问 Core internal API
7. Judge 能消费 RabbitMQ 消息
8. docker compose down -v 可以清空环境重来
```

## 15. 安全注意事项

```text
1. 不要提交真实 .env
2. 不要在 docker-compose 中写生产密码
3. 生产环境不要暴露 MySQL / Redis / RabbitMQ 公网端口
4. Judge 服务不要暴露公网
5. LLM API Key 必须通过环境变量注入
```
