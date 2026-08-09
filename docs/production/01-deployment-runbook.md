# 部署 Runbook

当前仅覆盖 Docker Compose 部署准备说明。由于 `../../docker-compose.yml` 为空，本仓库当前不能直接通过 Docker Compose 启动完整环境；以下流程是基于现有代码与文档的部署检查顺序，不代表生产方案已确定。

## 前置条件

- 明确部署目标环境、域名、HTTPS 证书和端口暴露策略。
- 准备 MySQL、RabbitMQ，以及如仍需要则准备 Redis。
- 准备 Java 17、Node.js/npm、Python、C++/CMake/isolate 运行环境，或补齐镜像构建文件。

## 依赖软件

- Core：Java 17、Maven Wrapper，见 `../../../flowstudy-core/pom.xml`
- Frontend：Node.js/npm，见 `../../../flowstudy-frontend/flowstudy-web/package.json`
- Judge：Linux/WSL、CMake、g++、rabbitmq-c、mysqlclient、spdlog、nlohmann-json、isolate，见 `../../../flowstudy-judge/CMakeLists.txt`
- AI：Python、requirements，见 `../../../flowstudy-ai/requirements.txt`

## 环境变量准备

- Core：参考 `../../../flowstudy-core/.env.example` 和 `../../../flowstudy-core/src/main/resources/application.properties`
- Frontend：参考 `../../../flowstudy-frontend/flowstudy-web/.env.example`
- AI：参考 `../../../flowstudy-ai/.env.example`
- Judge：参考 `../../../flowstudy-judge/config.example.json`
- infra `../../env/*.env.example` 当前为空，需要补齐后才能作为部署模板。

## 密钥准备

- `JWT_SECRET` 必须使用生产随机值。
- `DEEPSEEK_API_KEY` 由密钥管理系统注入。
- MySQL/RabbitMQ 密码不得写入 Git。

## 数据库初始化

新环境初始化参考：

```bash
mysql -uroot -p < mysql/init/01-init.sql
mysql -uroot -p flowstudy < mysql/init/02-seed-algorithm-leetcode-style.sql
```

执行前必须确认目标库，生产环境必须先备份。

## 数据库迁移

迁移脚本位于 `../../mysql/migration/`。当前没有迁移工具，执行顺序和回滚需人工确认。

## RabbitMQ 初始化

Core `JudgeRabbitConfig.java` 会声明 durable queue，队列名来自 `flowstudy.judge.rabbitmq.queue-name`。当前未发现 exchange、binding、DLQ 的 infra 定义文件。

## 服务启动顺序

1. MySQL
2. RabbitMQ
3. Core
4. Judge
5. AI
6. Frontend/Nginx

## Docker Compose 启动

当前 `../../docker-compose.yml` 为空，不能执行真实完整启动。补齐后至少应验证：

```bash
docker compose config
docker compose up -d
docker compose ps
```

## 健康检查

- AI：`GET /health`、`GET /api/v1/ai/health`
- Core：需核对是否存在健康端点；文档提到 `/api/v1/health`，实际 Controller 本次未发现。
- Judge：当前无 HTTP health，需通过进程、日志、RabbitMQ 消费和 DB 写回验证。

## 基础功能验证

- 注册、登录、`/api/v1/users/me`
- 教程列表、博客详情、题目详情、代码模板
- 代码运行、提交、结果轮询
- AI SSE 聊天

## 日志检查

- Core Spring Boot 日志
- Judge spdlog 输出
- AI uvicorn/FastAPI 日志
- Nginx error/access 日志

## 常见错误

- `docker-compose.yml` 为空导致无法启动。
- Nginx 配置使用 Windows 绝对路径，生产环境不可直接复用。
- Judge isolate 权限、box 所属用户、cgroup 支持不一致。
- Core/Judge RabbitMQ 用户、vhost、queue 配置不一致。
- OpenAPI 路径与实际 `/api/v1` 路径不一致导致联调失败。

## 发布后验证

执行 smoke test、检查错误日志、确认 RabbitMQ 无异常堆积、确认 MySQL 写入和查询一致、确认 AI 失败不会影响非 AI 主流程。
