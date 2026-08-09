# 性能测试计划

性能目标当前均为 `TBD`，需要项目负责人根据上线规模确认。

| 项目 | 场景 | 指标 | 目标值 | 工具建议 | 数据准备 | 验收条件 | 风险 |
|---|---|---|---|---|---|---|---|
| 登录 | 并发登录、错误密码 | P95、错误率 | TBD | k6/JMeter | 测试用户 | 错误率可控，无 DB 锁热点 | BCrypt 成本影响 CPU |
| 教程查询 | 列表、详情、搜索 | QPS、P95 | TBD | k6 | `fs_tutorial`、`fs_blog` 种子 | 分页正确 | 索引不足 |
| 题目查询 | 题目列表、详情、模板 | QPS、P95 | TBD | k6 | `fs_problem`、模板和测试用例 | 响应稳定 | 大字段 Markdown |
| 代码运行 | 自定义测试用例 | 创建耗时、完成耗时 | TBD | k6 + MQ 监控 | 登录用户和题目 | 任务可完成 | Judge 资源耗尽 |
| 代码提交 | 正常提交、错误代码 | 入队成功率、完成耗时 | TBD | k6 | 多语言代码 | 状态正确 | MQ 堆积 |
| 判题结果查询 | 前端轮询模式 | QPS、DB 负载 | TBD | k6 | 已提交记录 | 查询稳定 | 轮询放大 DB 压力 |
| AI 请求 | SSE 流式问答 | 首 token、完成耗时 | TBD | k6/自定义脚本 | 测试 API Key | 错误可降级 | 外部模型限流 |
| 并发提交 | 多用户同时提交 | 队列积压、完成率 | TBD | k6 + RabbitMQ 管理 API | 100+ 用户 | 无任务丢失 | Judge box 不足 |
| RabbitMQ 堆积 | Judge 降速或停止 | queue depth、恢复时间 | TBD | RabbitMQ Management | 批量提交 | 恢复后消费完成 | 缺 DLQ |
| Judge 并发 | 多 isolate box | CPU、内存、超时率 | TBD | 自定义发布器 | AC/WA/TLE/CE 混合 | 资源限制生效 | 沙箱权限 |
| 数据库连接池 | Core 高并发查询/写入 | active connections、P95 | TBD | k6 + DB 监控 | 真实量级数据 | 无连接耗尽 | 配置未调优 |
| Redis | 限流或缓存 | QPS、命中率 | TBD | redis-benchmark | 待确认 | 待确认 | 当前未实现 |
| Nginx | 静态资源和反向代理 | QPS、P95、错误率 | TBD | wrk/k6 | 前端 dist | 代理正确 | 当前配置为本机绝对路径 |
