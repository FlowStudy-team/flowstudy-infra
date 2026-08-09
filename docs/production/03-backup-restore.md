# 备份与恢复

## MySQL 需要备份的数据

依据 `../07-database-design.md` 和 `../../mysql/init/01-init.sql`，至少包括：

- 用户：`sys_user`
- 内容：`fs_tutorial`、`fs_blog`、`fs_problem`、`fs_problem_testcase`、`fs_code_template`
- 判题：`fs_submission`、`fs_judge_case_result`、`fs_code_run`、`fs_code_run_case_result`
- AI/画像预留：`fs_ai_conversation`、`fs_ai_message`、`fs_user_profile`、`fs_learning_note`
- 文档中心：`fs_document_category`、`fs_document_folder`、`fs_document`
- MQ 审计：`fs_mq_message_log`

## 数据卷

当前 `../../docker-compose.yml` 为空，没有定义 MySQL、RabbitMQ、Redis 或上传文件 volumes。上线前必须明确数据卷位置、权限和备份方式。

## 用户上传数据

当前代码中未确认独立上传文件存储目录。文档中心内容主要在数据库表中；如后续引入文件上传，必须纳入备份。

## Redis 是否作为持久数据

当前 Core 未发现 Redis 实现。若 Redis 后续只用于缓存/限流，可不作为强一致持久数据；若用于 session、队列或学习状态，必须重新评估。

## RabbitMQ 是否需要持久化

Core 声明 durable queue，消息可靠性还取决于 producer delivery mode、RabbitMQ durable storage 和磁盘告警。当前未发现 infra RabbitMQ definitions。

## 备份频率建议

- MySQL：TBD，由业务 RPO 决定。
- RabbitMQ：TBD，若允许短暂丢失待判任务，可通过 Core DB 中 `PENDING`/`RUNNING` 状态补偿；该补偿当前未实现。
- 配置和 Nginx：每次发布前备份。

## 恢复步骤

1. 停止写入流量或进入维护模式。
2. 恢复 MySQL 到目标时间点。
3. 启动 Core 并验证读写。
4. 恢复或重建 RabbitMQ 队列。
5. 检查 `PENDING`/`RUNNING` 判题任务一致性。
6. 启动 Judge、AI、Frontend/Nginx。

## 恢复验证

- 用户登录成功。
- 内容、题目和文档数据可查询。
- 新提交可以进入队列并写回结果。
- 旧提交状态和 case result 一致。

## 恢复演练

上线前至少在非生产环境演练一次全量恢复和一次单表误删恢复。

## RPO/RTO 待确认项

- 允许丢失多少分钟数据：TBD。
- 允许服务中断多久：TBD。
- 判题队列积压恢复策略：TBD。
