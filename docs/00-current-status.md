# 00. FlowStudy 当前状态

本文记录 2026-08-03 基于实际代码、配置和现有文档检查得到的项目现状。它不是路线图；未运行验证的链路不标记为“已验证”。

## Status Summary

当前判断：MVP 开发中，部分前后端联调代码已存在，代码运行/提交的异步判题链路在代码层面存在，但本次未启动 MySQL、RabbitMQ、Judge 或前端进行端到端验证。项目未达到生产准备阶段。

关键依据：

- Core 已实现认证、教程、博客、题目、运行、提交、文档 API：`../flowstudy-core/src/main/java/com/flowstudy/core/module/`
- Frontend 已接入 Core `/api/v1` 与 AI `/ai/api/v1/ai/chat`：`../flowstudy-frontend/flowstudy-web/src/api/`
- Judge 消费 RabbitMQ 并直接写 MySQL：`../flowstudy-judge/src/worker/worker.cpp`
- AI 仅有 FastAPI SSE 聊天和健康检查：`../flowstudy-ai/app/router.py`
- infra `docker-compose.yml` 与 `env/*.env.example` 为空，生产部署能力未实现。

## Repository Status

### frontend

- 已实现：Vue/Vite 应用入口、路由、Pinia 鉴权状态、统一 Core API 请求、教程/博客/文档/OJ/AI UI。
- 部分实现：OJ 页面 `src/api/oj.ts` 调用 Core 运行/提交并轮询结果。
- 尚未实现：自动化测试目录未发现；生产构建部署配置未发现。
- 已有代码但尚未接入：`src/api/modules/problems.ts` 仍返回模拟题目和提交结果；`src/api/practice.ts` 也包含前端本地适配逻辑。
- 无法确认：浏览器端实际联调效果，本次未启动 Vite。
- 主要证据路径：`../flowstudy-frontend/flowstudy-web/package.json`、`../flowstudy-frontend/flowstudy-web/src/router/index.ts`、`../flowstudy-frontend/flowstudy-web/src/api/request.ts`、`../flowstudy-frontend/flowstudy-web/src/api/oj.ts`

### core

- 已实现：Spring Boot 3.4.1、Java 17、JWT 鉴权、MyBatis 数据访问、教程/博客/题目/运行/提交/文档接口、H2 集成测试。
- 部分实现：提交与运行任务入库后通过 `RabbitTemplate` 投递到队列。
- 尚未实现：Redis 限流代码未发现；RabbitMQ 判题结果消费者未发现；AI 内部上下文接口未发现；Dockerfile 未发现。
- 已有代码但尚未接入：文档模块和 run 相关代码在当前工作树中为未跟踪/未提交状态。
- 无法确认：真实 MySQL/RabbitMQ 环境联调，本次未启动服务。
- 主要证据路径：`../flowstudy-core/pom.xml`、`../flowstudy-core/src/main/resources/application.properties`、`../flowstudy-core/src/main/java/com/flowstudy/core/security/`、`../flowstudy-core/src/main/java/com/flowstudy/core/module/submission/`

### judge

- 已实现：C++17/CMake Worker、RabbitMQ 消费、isolate 编译运行、输出比对、超时/内存判断、MySQL 结果写回、基础测试代码。
- 部分实现：支持 C++、Java、Python、Go 的编译/运行分支；实际多语言端到端验证未确认。
- 尚未实现：Dockerfile、生产级沙箱部署、结果经 RabbitMQ 回传 Core。
- 已有代码但尚未接入：`scripts/setup_db.sql` 和旧文档仍描述 `submissions` 表，当前 Worker 实际写 `fs_submission`/`fs_code_run`。
- 无法确认：本机 isolate、RabbitMQ、MySQL 端到端，本次未启动。
- 主要证据路径：`../flowstudy-judge/src/main.cpp`、`../flowstudy-judge/src/worker/worker.cpp`、`../flowstudy-judge/src/judge/sandbox.cpp`、`../flowstudy-judge/src/db/mysql_client.cpp`

### ai

- 已实现：FastAPI 应用、`/health`、`/api/v1/ai/health`、`/api/v1/ai/chat` SSE、Prompt 构造、DeepSeek/OpenAI-compatible 流式调用。
- 部分实现：前端可通过 Vite `/ai` 代理调用 AI SSE。
- 尚未实现：数据库持久化、RabbitMQ 行为事件、Core 上下文客户端、重试策略、自动化测试、Dockerfile。
- 已有代码但尚未接入：无独立 Agent 工作流或画像生成实现。
- 无法确认：真实模型调用，本次未读取 `.env` 且未调用外部模型。
- 主要证据路径：`../flowstudy-ai/app/main.py`、`../flowstudy-ai/app/router.py`、`../flowstudy-ai/app/llm_client.py`

### infra

- 已实现：架构/契约文档、OpenAPI 文件、MySQL 初始化和迁移 SQL、Nginx 本机配置。
- 部分实现：部署文档存在，但部署配置未落地。
- 尚未实现：`docker-compose.yml` 为空；`env/*.env.example` 为空；`deploy/`、`diagrams/`、`rabbitmq/`、`scripts/` 为空。
- 无法确认：Docker Compose 本地启动。
- 主要证据路径：`docker-compose.yml`、`env/`、`mysql/init/01-init.sql`、`nginx/nginx.conf`

## End-to-End Flows

| 流程 | 状态 | 依据 |
|---|---|---|
| 注册和登录 | 代码上存在但未验证 | Core `AuthController`/`AuthService`，Frontend `useAuthForm.ts`/`auth.ts` |
| 教程学习 | 代码上存在但未验证 | Core `TutorialController`/`BlogController`，Frontend `LearningCenterView.vue` |
| 题目浏览 | 代码上存在但未验证 | Core `ProblemController`，Frontend `src/api/oj.ts` |
| 代码运行 | 代码上存在但未验证 | Core `CodeRunService` 投递 MQ，Judge `update_code_run` 写回 |
| 代码提交 | 代码上存在但未验证 | Core `SubmissionService` 投递 MQ，Judge `update_submission` 写回 |
| 异步判题 | 部分完成 | 当前代码是 Core 生产任务、Judge 消费并直写 DB；不是文档声明的结果 MQ 回传 |
| 判题结果查询 | 代码上存在但未验证 | Core `GET /runs/{runId}`、`GET /submissions/{submitId}`，Frontend 轮询 |
| AI 辅助学习 | 代码上存在但未验证 | Frontend `api/modules/ai.ts`，AI `router.py` |
| Docker Compose 本地启动 | 未完成 | `docker-compose.yml` 为空 |

## Known Gaps

- OpenAPI `docs/api/FlowStudy_Apifox_OpenAPI.yaml` 使用 `/api/...`、`/api/oj/...`，实际 Core 使用 `/api/v1/...`。
- 设计文档多处描述 Judge 通过 RabbitMQ 回传结果，实际 Judge 直接更新 MySQL，Core 未发现结果消费者。
- `flowstudy-infra/docker-compose.yml` 为空，但 README 和部署文档描述可 `docker compose up -d`。
- `flowstudy-infra/env/*.env.example` 为空，无法作为真实环境变量模板使用。
- Nginx 配置使用绝对 Windows 路径：`nginx/nginx.conf`。
- Core 配置包含本地默认密码和 JWT 默认 secret，仅适合开发环境。
- Redis 依赖在文档中多次出现，Core 实际未发现 Redis starter 或 Redis 限流实现。
- Frontend `AGENTS.md` 和 Judge `AGENTS.md` 原内容乱码，需重写。
- 自动化测试缺口：Frontend/AI 未发现测试；Judge 测试依赖 Linux/isolate；生产 E2E/压测未建立。
- 监控、指标、链路追踪、告警、备份、回滚未落地。

## Production Readiness Summary

| 领域 | 状态 | 依据 |
|---|---|---|
| 配置管理 | Partially Ready | Core/Judge/Frontend/AI 有示例或配置入口；infra env 模板为空 |
| 密钥管理 | Not Ready | 未发现 secret manager；本地默认值存在 |
| 数据库迁移 | Partially Ready | `mysql/migration/` 存在，但无迁移工具和回滚脚本 |
| 数据持久化 | Not Ready | Docker Compose volumes 未定义 |
| RabbitMQ 可靠性 | Partially Ready | 队列 durable，缺少完整 DLQ/重试策略落地 |
| Judge 安全隔离 | Partially Ready | isolate 存在，生产权限和 cgroup 策略未确认 |
| 鉴权和授权 | Partially Ready | JWT 鉴权存在，角色授权覆盖有限 |
| 接口安全 | Partially Ready | 基础鉴权存在，CORS/限流/输入安全需补齐 |
| 限流 | Not Ready | Redis 限流实现未发现 |
| 日志 | Partially Ready | Core/AI/Judge 有基础日志，缺集中化 |
| 指标 | Not Ready | 未发现 metrics 配置 |
| 链路追踪 | Partially Ready | Core 有 traceId filter，跨服务传递未完整验证 |
| 告警 | Not Ready | 未发现告警配置 |
| 备份恢复 | Not Ready | 未发现自动备份 |
| 回滚 | Not Ready | 未发现版本化部署和回滚流程落地 |
| 自动化测试 | Partially Ready | Core/Judge 有测试，Frontend/AI 缺失 |
| 压力测试 | Not Ready | 未发现压测脚本或目标 |

## Next Actions

### P0：上线阻塞

- 补齐 Docker Compose 或明确替代部署方案。
- 统一 OpenAPI、REST 文档、Core Controller 和 Frontend 调用路径。
- 明确 Judge 结果回传方式：直写 DB 或 RabbitMQ 回传 Core。
- 移除生产默认密钥，建立密钥注入和轮换机制。
- 明确 Judge 生产沙箱隔离、权限和资源限制方案。

### P1：上线前必须完成

- 补齐 env 示例、健康检查、持久化 volumes、Nginx 生产配置。
- 建立数据库迁移流程、备份和回滚原则。
- 为 Core/Judge/Frontend/AI 建立最小集成验证。
- 补齐限流、接口安全、错误监控和日志采集。

### P2：上线后短期优化

- 引入契约测试、E2E 测试、压测。
- 增加 RabbitMQ DLQ、消息幂等审计和堆积监控。
- 完善 AI 降级策略与超时控制。

### P3：长期优化

- 多语言判题矩阵、RAG/Agent 工作流、学习画像、灰度发布和自动化运维。
