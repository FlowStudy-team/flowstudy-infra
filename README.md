# FlowStudy Infra

`flowstudy-infra` 是 FlowStudy 的架构、契约、部署、环境和项目知识库。新的人工开发者和 AI Agent 都应先从本仓库理解项目现状，再进入业务仓库。

当前真实开发状态见 [docs/00-current-status.md](docs/00-current-status.md)。不要把规划文档中的未来能力视为已经实现。

## For Human Developers

- 项目概览：[docs/00-project-overview.md](docs/00-project-overview.md)
- 本地开发：[docs/04-dev-environment.md](docs/04-dev-environment.md)
- 系统架构：[docs/02-system-architecture.md](docs/02-system-architecture.md)
- API 契约：[docs/05-restful-api-contract.md](docs/05-restful-api-contract.md)、[docs/api/FlowStudy_Apifox_OpenAPI.yaml](docs/api/FlowStudy_Apifox_OpenAPI.yaml)
- 数据库：[docs/07-database-design.md](docs/07-database-design.md)、[mysql/init/01-init.sql](mysql/init/01-init.sql)、[mysql/migration/](mysql/migration/)
- RabbitMQ：[docs/08-rabbitmq-message-contract.md](docs/08-rabbitmq-message-contract.md)
- 测试：[docs/17-test-plan.md](docs/17-test-plan.md)
- 部署：[docs/15-deployment-docker-compose.md](docs/15-deployment-docker-compose.md)、[docs/production/01-deployment-runbook.md](docs/production/01-deployment-runbook.md)

## For AI Agents

1. 首先阅读 [AGENTS.md](AGENTS.md)
2. 阅读 [docs/00-current-status.md](docs/00-current-status.md)
3. 阅读 [docs/18-code-map.md](docs/18-code-map.md)
4. 阅读当前任务相关契约
5. 阅读对应业务仓库的 `AGENTS.md`

业务仓库入口：

- [../flowstudy-frontend/AGENTS.md](../flowstudy-frontend/AGENTS.md)
- [../flowstudy-core/AGENTS.md](../flowstudy-core/AGENTS.md)
- [../flowstudy-judge/AGENTS.md](../flowstudy-judge/AGENTS.md)
- [../flowstudy-ai/AGENTS.md](../flowstudy-ai/AGENTS.md)

## Production Readiness

- [docs/production/00-production-readiness-checklist.md](docs/production/00-production-readiness-checklist.md)
- [docs/production/01-deployment-runbook.md](docs/production/01-deployment-runbook.md)
- [docs/production/02-rollback-plan.md](docs/production/02-rollback-plan.md)
- [docs/production/03-backup-restore.md](docs/production/03-backup-restore.md)
- [docs/production/04-disaster-recovery.md](docs/production/04-disaster-recovery.md)
- [docs/production/05-performance-test-plan.md](docs/production/05-performance-test-plan.md)
- [docs/production/06-known-risks.md](docs/production/06-known-risks.md)

## Documentation Index

| 文档 | 说明 |
|---|---|
| [docs/00-project-overview.md](docs/00-project-overview.md) | 产品定位和总体背景 |
| [docs/00-current-status.md](docs/00-current-status.md) | 当前真实开发状态和缺口 |
| [docs/01-mvp-scope-roadmap.md](docs/01-mvp-scope-roadmap.md) | MVP 范围和版本规划 |
| [docs/02-system-architecture.md](docs/02-system-architecture.md) | 服务划分和系统架构 |
| [docs/03-repository-structure.md](docs/03-repository-structure.md) | 多仓库职责、入口和依赖 |
| [docs/04-dev-environment.md](docs/04-dev-environment.md) | 本地开发环境与启动命令 |
| [docs/05-restful-api-contract.md](docs/05-restful-api-contract.md) | REST API 契约 |
| [docs/06-result-error-code-contract.md](docs/06-result-error-code-contract.md) | 统一返回结构、错误码和枚举 |
| [docs/07-database-design.md](docs/07-database-design.md) | MySQL 表设计 |
| [docs/08-rabbitmq-message-contract.md](docs/08-rabbitmq-message-contract.md) | RabbitMQ 消息约定 |
| [docs/09-core-service-design.md](docs/09-core-service-design.md) | Core Service 设计 |
| [docs/10-judge-service-design.md](docs/10-judge-service-design.md) | Judge Service 设计 |
| [docs/11-ai-agent-service-design.md](docs/11-ai-agent-service-design.md) | AI Service 设计 |
| [docs/12-frontend-design.md](docs/12-frontend-design.md) | 前端设计 |
| [docs/13-auth-security-rate-limit.md](docs/13-auth-security-rate-limit.md) | 鉴权、安全和限流设计 |
| [docs/14-observability-logging-tracing.md](docs/14-observability-logging-tracing.md) | 日志、追踪和可观测性规划 |
| [docs/15-deployment-docker-compose.md](docs/15-deployment-docker-compose.md) | Docker Compose 部署文档和当前限制 |
| [docs/16-git-workflow-engineering-rules.md](docs/16-git-workflow-engineering-rules.md) | Git 流程、工程规则和多 Agent 协作 |
| [docs/17-test-plan.md](docs/17-test-plan.md) | 测试计划和当前测试状态 |
| [docs/18-code-map.md](docs/18-code-map.md) | 设计文档与真实代码映射 |
| [docs/FlowStudy开发指南.md](docs/FlowStudy开发指南.md) | 项目开发指南 |
| [docs/learning-content-seed-guide.md](docs/learning-content-seed-guide.md) | 学习内容种子数据指南 |

## Repository Scope

本仓库负责项目架构和工程文档、共享契约、MySQL 初始化与迁移脚本、Nginx 配置、环境变量示例入口，以及生产准备、回滚、备份和灾难恢复文档。

业务代码位于 `flowstudy-frontend`、`flowstudy-core`、`flowstudy-judge`、`flowstudy-ai`。

## Current Infrastructure Reality

- `docker-compose.yml` 当前为空，不能直接启动完整环境。
- `env/*.env.example` 当前为空，不能作为真实部署模板。
- `deploy/`、`diagrams/`、`rabbitmq/`、`scripts/` 当前为空目录。
- `nginx/nginx.conf` 是本机 Windows 路径配置，生产环境不可直接复用。

以上限制已记录在 [docs/00-current-status.md](docs/00-current-status.md) 和 [docs/production/06-known-risks.md](docs/production/06-known-risks.md)。
