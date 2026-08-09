# 已知风险

| 风险编号 | 风险领域 | 风险描述 | 代码或配置证据 | 概率 | 影响 | 风险等级 | 是否阻塞上线 | 建议措施 | 当前状态 |
|---|---|---|---|---|---|---|---|---|---|
| R-001 | 部署 | `docker-compose.yml` 为空，无法按文档启动本地/生产依赖 | `docker-compose.yml` | 高 | 高 | 高 | 是 | 补齐 compose、healthcheck、volumes、网络和 env | 未处理 |
| R-002 | 配置 | infra `env/*.env.example` 为空，无法指导部署变量 | `env/core.env.example` 等 | 高 | 中 | 高 | 是 | 补齐示例但不含真实密钥 | 未处理 |
| R-003 | 契约 | OpenAPI 路径与实际 `/api/v1` Controller 不一致 | `docs/api/FlowStudy_Apifox_OpenAPI.yaml`、Core Controllers | 高 | 高 | 高 | 是 | 统一 REST 契约和前端调用 | 未处理 |
| R-004 | 判题链路 | 文档描述结果 MQ 回传，代码实际 Judge 直写 DB | `docs/08-rabbitmq-message-contract.md`、`flowstudy-judge/src/db/mysql_client.cpp` | 高 | 高 | 高 | 是 | 决策并更新契约；补偿幂等策略 | 待确认 |
| R-005 | 安全 | Core 有本地默认 DB 密码和 JWT secret fallback | `flowstudy-core/src/main/resources/application.properties` | 中 | 高 | 高 | 是 | 生产 profile 强制密钥注入，启动时校验 | 未处理 |
| R-006 | Judge 安全 | isolate 依赖宿主权限和 cgroup，生产隔离未验证 | `flowstudy-judge/src/judge/sandbox.cpp`、`documentation/TESTING.md` | 中 | 高 | 高 | 是 | 在目标 Linux 环境验证资源限制和权限 | 未验证 |
| R-007 | 数据一致性 | Core 入库和 MQ 投递在同一事务内调用外部 MQ，失败补偿未发现 | `SubmissionService.java`、`CodeRunService.java` | 中 | 高 | 高 | 是 | 引入 outbox 或明确重试补偿 | 未处理 |
| R-008 | Redis/限流 | 文档要求 Redis 限流，Core 未发现 Redis 实现 | `docs/13-auth-security-rate-limit.md`、`flowstudy-core/pom.xml` | 高 | 中 | 中 | 视流量而定 | 明确 MVP 是否需要限流；实现或下线文档声明 | 未处理 |
| R-009 | AI 可用性 | AI 无显式超时/重试，外部模型故障会导致 SSE 错误 | `flowstudy-ai/app/llm_client.py`、`app/router.py` | 中 | 中 | 中 | 否 | 增加超时、重试、错误脱敏和前端降级 | 未处理 |
| R-010 | 测试 | Frontend/AI 未发现测试，端到端测试缺失 | `flowstudy-frontend/flowstudy-web/package.json`、`flowstudy-ai/` | 高 | 中 | 中 | 上线前应阻塞 | 建立 smoke/E2E/AI API 测试 | 未处理 |
| R-011 | Nginx | Nginx 使用 Windows 绝对路径，不可直接生产复用 | `nginx/nginx.conf` | 高 | 中 | 中 | 是 | 生成环境无关配置模板 | 未处理 |
| R-012 | 旧代码/文档 | Judge 旧脚本仍使用 `submissions` 表，与当前 `fs_submission` 不一致 | `flowstudy-judge/scripts/setup_db.sql`、`src/db/mysql_client.cpp` | 中 | 中 | 中 | 否 | 标记旧脚本用途或迁移到当前 schema | 未处理 |
