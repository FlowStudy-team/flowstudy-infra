# FlowStudy Agent Guide

## Project Identity

FlowStudy 是一个面向编程学习的多服务项目，当前核心能力围绕用户注册登录、教程/博客阅读、题目浏览、代码运行与提交、异步判题结果查询，以及前端 AI 侧边栏问答。当前状态以 [docs/00-current-status.md](docs/00-current-status.md) 为准，不得仅凭规划文档判断功能已完成或可上线。

## Repository Map

| 仓库 | 技术栈 | 核心职责 | 主要入口 | 主要依赖 |
|---|---|---|---|---|
| `flowstudy-frontend` | Vue 3、Vite、TypeScript、Pinia | Web 前端、路由、鉴权状态、教程/OJ/文档/AI UI | `flowstudy-web/src/main.ts` | Core HTTP API、AI SSE API、浏览器 localStorage |
| `flowstudy-core` | Spring Boot 3.4.1、Java 17、MyBatis、Spring Security、AMQP | 用户认证、内容/题目/文档 API、提交入库、判题任务投递、结果查询 | `src/main/java/com/flowstudy/core/FlowstudyCoreApplication.java` | MySQL、RabbitMQ、JWT |
| `flowstudy-judge` | C++17、CMake、rabbitmq-c、libmysqlclient、isolate | 消费判题任务、编译运行代码、写回判题结果 | `src/main.cpp` | RabbitMQ、MySQL、isolate、Linux/WSL 环境 |
| `flowstudy-ai` | Python、FastAPI、OpenAI SDK、DeepSeek 兼容 API | AI 聊天 SSE、Prompt 构造、模型流式调用 | `app/main.py` | `DEEPSEEK_API_KEY`、DeepSeek/OpenAI-compatible API |
| `flowstudy-infra` | Markdown、SQL、Nginx 配置 | 架构、契约、SQL、Nginx、环境模板和生产准备文档 | `README.md` | 各业务仓库实际代码 |

## Mandatory Reading Order

开始任何 FlowStudy 任务前，先阅读：

1. [docs/00-project-overview.md](docs/00-project-overview.md)
2. [docs/00-current-status.md](docs/00-current-status.md)
3. [docs/02-system-architecture.md](docs/02-system-architecture.md)
4. [docs/03-repository-structure.md](docs/03-repository-structure.md)
5. 对应业务仓库的 `AGENTS.md`

按任务类型追加阅读：

| 任务类型 | 追加文档 |
|---|---|
| API | [docs/05-restful-api-contract.md](docs/05-restful-api-contract.md)、[docs/api/FlowStudy_Apifox_OpenAPI.yaml](docs/api/FlowStudy_Apifox_OpenAPI.yaml)、[docs/06-result-error-code-contract.md](docs/06-result-error-code-contract.md) |
| 数据库 | [docs/07-database-design.md](docs/07-database-design.md)、`mysql/init/01-init.sql`、`mysql/migration/` |
| RabbitMQ | [docs/08-rabbitmq-message-contract.md](docs/08-rabbitmq-message-contract.md)、[docs/18-code-map.md](docs/18-code-map.md) |
| 鉴权安全 | [docs/13-auth-security-rate-limit.md](docs/13-auth-security-rate-limit.md)、[../flowstudy-core/AGENTS.md](../flowstudy-core/AGENTS.md)、[../flowstudy-frontend/AGENTS.md](../flowstudy-frontend/AGENTS.md) |
| 部署 | [docs/15-deployment-docker-compose.md](docs/15-deployment-docker-compose.md)、[docs/production/01-deployment-runbook.md](docs/production/01-deployment-runbook.md)、`nginx/nginx.conf` |
| 测试 | [docs/17-test-plan.md](docs/17-test-plan.md)、各仓库 `README.md` 或测试目录 |
| 上线准备 | [docs/production/00-production-readiness-checklist.md](docs/production/00-production-readiness-checklist.md)、[docs/production/06-known-risks.md](docs/production/06-known-risks.md) |

## Source of Truth

| 信息 | 权威来源 |
|---|---|
| 接口契约 | [docs/05-restful-api-contract.md](docs/05-restful-api-contract.md)、[docs/api/FlowStudy_Apifox_OpenAPI.yaml](docs/api/FlowStudy_Apifox_OpenAPI.yaml)，并与实际 Controller/API 调用核对 |
| RabbitMQ 消息 | [docs/08-rabbitmq-message-contract.md](docs/08-rabbitmq-message-contract.md)、Core `JudgeSubmitMessage`、Judge `SubmissionMessage` |
| 数据库 | `mysql/init/*.sql`、`mysql/migration/*.sql`、[docs/07-database-design.md](docs/07-database-design.md)、Core/Judge SQL 访问代码 |
| 当前实现 | 四个业务仓库实际代码 |
| 当前进展 | [docs/00-current-status.md](docs/00-current-status.md) |
| 部署配置 | `docker-compose.yml`、`nginx/nginx.conf`、`env/*.env.example`、[docs/15-deployment-docker-compose.md](docs/15-deployment-docker-compose.md) |

文档与代码冲突时，Agent 必须报告差异，列出文档路径和代码路径，不能静默选择一方。

## Development Rules

- 修改前判断受影响仓库和跨服务契约。
- 不允许单方面修改 REST API、RabbitMQ 消息或数据库结构。
- API 变化必须同步 REST 文档、OpenAPI、前端调用和后端 Controller。
- RabbitMQ 消息变化必须同步 Core 生产者、Judge 消费者和消息契约。
- 数据库变化必须提供 migration，并说明回滚策略。
- 不允许提交真实密钥、Token、密码或本地 `.env`。
- 不允许删除失败测试来规避问题。
- 不允许执行生产部署、生产数据变更或生产回滚。
- 修改后必须运行对应仓库验证命令；不能运行时说明原因。
- 完成后报告修改文件、验证命令、验证结果和未验证事项。

## Production Safety

以下操作必须人工确认：数据删除、数据库结构修改、密钥修改、公网暴露、Nginx 修改、RabbitMQ 队列或消息结构修改、Judge 沙箱权限修改、Docker 挂载和持久化修改、生产部署与回滚。

Agent 禁止直接执行生产操作；只能准备文档、脚本草案或本地验证命令。

## Task Completion Format

完成任务时输出：

- 任务理解
- 阅读过的文档
- 检查过的仓库
- 修改文件
- 契约影响
- 执行命令
- 测试结果
- 未验证内容
- 风险
- 后续建议
