# 生产准备检查清单

状态值：`Ready`、`Partially Ready`、`Not Ready`、`Unknown`。不要把未验证项勾选为完成。

| 检查项 | 状态 | 证据 | 负责人 | 验证方法 | 备注 |
|---|---|---|---|---|---|
| [ ] 环境和配置 | Partially Ready | Core `application.properties`、Frontend `.env.example`、Judge `config.example.json`、AI `.env.example`；infra `env/*.env.example` 为空 | TBD | 核对所有必需变量并启动服务 | 生产变量未定 |
| [ ] 密钥 | Not Ready | Core 有本地默认 JWT secret；AI 依赖 `DEEPSEEK_API_KEY` | TBD | 检查 secret 注入和轮换 | 不得提交真实密钥 |
| [ ] 数据库 | Partially Ready | `mysql/init/01-init.sql`、`mysql/migration/*.sql` | TBD | 空库初始化和迁移演练 | 无迁移工具 |
| [ ] 数据迁移 | Partially Ready | migration 文件存在 | TBD | 备份后迁移和回滚评审 | 缺自动化 |
| [ ] 备份恢复 | Not Ready | 未发现备份脚本 | TBD | 执行备份恢复演练 | 见 `03-backup-restore.md` |
| [ ] RabbitMQ | Partially Ready | Core 声明 durable queue；Judge 消费 queue | TBD | 发布/消费/失败重试测试 | DLQ 未落地 |
| [ ] Redis | Not Ready | 文档提及，Core 未发现 Redis 实现 | TBD | 确认是否仍需要 Redis | 待确认 |
| [ ] Judge 安全隔离 | Partially Ready | Judge 使用 isolate | TBD | Linux 环境沙箱权限和资源限制测试 | 生产 cgroup 待确认 |
| [ ] API 安全 | Partially Ready | Core JWT 和校验存在 | TBD | 鉴权、越权、输入校验测试 | CORS/限流需补 |
| [ ] 鉴权授权 | Partially Ready | `SecurityConfig.java`、`JwtAuthenticationFilter.java` | TBD | 登录、401、403、角色测试 | 管理权限不完整 |
| [ ] 限流 | Not Ready | 未发现 Redis 限流代码 | TBD | 压测提交和登录接口 | 上线前需设计 |
| [ ] 日志 | Partially Ready | Core/AI/Judge 基础日志 | TBD | 检查日志格式、脱敏和采集 | 未集中化 |
| [ ] 指标 | Not Ready | 未发现 metrics | TBD | 检查 Prometheus/Actuator 等 | TBD |
| [ ] 链路追踪 | Partially Ready | Core `TraceIdFilter` | TBD | 跨 Frontend/Core/Judge/AI trace 验证 | MQ/AI 未完整传递 |
| [ ] 告警 | Not Ready | 未发现告警配置 | TBD | 模拟服务异常 | TBD |
| [ ] Docker | Not Ready | `docker-compose.yml` 为空 | TBD | `docker compose config` | 需补齐 |
| [ ] Nginx | Partially Ready | `nginx/nginx.conf` 指向本机绝对路径 | TBD | 本地反向代理验证 | 生产路径需重写 |
| [ ] HTTPS | Not Ready | Nginx 未配置证书 | TBD | TLS 证书验证 | TBD |
| [ ] 网络和端口 | Partially Ready | 文档列出端口，compose 未定义 | TBD | 端口扫描和访问控制 | 不得公开 DB/MQ/Judge |
| [ ] 数据持久化 | Not Ready | compose volumes 未定义 | TBD | 重启容器后数据验证 | TBD |
| [ ] 健康检查 | Partially Ready | AI `/health`，Core 需核对，compose healthcheck 无 | TBD | HTTP 健康检查 | Judge 无 HTTP health |
| [ ] 自动化测试 | Partially Ready | Core/Judge 有测试 | TBD | 执行测试命令 | Frontend/AI 缺失 |
| [ ] 集成测试 | Partially Ready | Core H2 integration、Judge test_runner | TBD | 真实 MySQL/RabbitMQ 联调 | 未端到端验证 |
| [ ] 端到端测试 | Not Ready | 未发现 E2E 框架 | TBD | 浏览器流程测试 | TBD |
| [ ] 压力测试 | Not Ready | 未发现压测脚本 | TBD | 执行 `05-performance-test-plan.md` | 目标值 TBD |
| [ ] 部署 | Not Ready | compose 为空，无 CI/CD | TBD | 部署演练 | 当前仅文档 |
| [ ] 灰度 | Not Ready | 未发现灰度机制 | TBD | 灰度发布演练 | TBD |
| [ ] 回滚 | Not Ready | 无版本化部署记录 | TBD | 回滚演练 | 见 `02-rollback-plan.md` |
| [ ] 发布验证 | Not Ready | 无发布后检查脚本 | TBD | smoke test 清单 | TBD |
