# 14. 可观测性、日志与链路追踪设计文档

## 1. 文档目的

本文档定义 FlowStudy 在日志、traceId、错误排查、HTTP 链路、RabbitMQ 消息链路、服务健康检查和未来监控体系方面的统一规范。

FlowStudy 由 Frontend、Core、Judge、AI、MySQL、Redis、RabbitMQ 多组件组成，如果没有统一 traceId 和日志规范，后期排查问题会非常困难。

## 2. 可观测性目标

```text
1. 每一次用户请求都能通过 traceId 追踪
2. HTTP 请求、MQ 消息和后台任务都能串起来
3. 错误日志能定位用户、接口、提交 ID、消息 ID
4. 日志不泄露密码、token、API Key
5. 服务健康状态可检查
6. 后期可以平滑接入 Prometheus / Grafana
```

## 3. traceId 规范

`traceId` 是一次请求或一次异步任务的链路追踪 ID。

规则：

```text
1. 每个 HTTP 请求必须有 traceId
2. 如果请求头有 X-Trace-Id，则复用
3. 如果没有，则由服务生成
4. 响应体必须返回 traceId
5. 日志必须打印 traceId
6. RabbitMQ 消息必须携带 traceId
7. 下游服务继续沿用上游 traceId
```

请求头：

```http
X-Trace-Id: 9f2c1a7e
```

响应体：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

## 4. HTTP 链路传递

典型链路：

```text
Frontend
  ↓ X-Trace-Id
flowstudy-core
  ↓ X-Trace-Id
flowstudy-ai
```

Core 处理时：

```text
1. TraceIdFilter 读取或生成 traceId
2. 放入 MDC
3. 响应体返回 traceId
4. 调用 AI internal API 时继续携带 X-Trace-Id
```

## 5. MQ 链路传递

消息外壳必须包含：

```json
{
  "schemaVersion": "1.0",
  "messageId": "msg-20260527-000001",
  "traceId": "9f2c1a7e",
  "eventType": "judge.submit.created",
  "producer": "flowstudy-core",
  "occurredAt": "2026-05-27T10:30:00+08:00",
  "payload": {}
}
```

要求：

```text
1. Core 投递 Judge 任务时带 traceId
2. Judge 消费时将 traceId 放入日志上下文
3. Judge 回传结果时继续使用同一个 traceId
4. Core 消费结果时继续使用同一个 traceId
5. AI 消费行为事件时继续使用事件 traceId
```

## 6. 日志级别规范

| 级别 | 使用场景 |
|---|---|
| DEBUG | 本地调试、详细变量、SQL 调试 |
| INFO | 正常业务流程关键节点 |
| WARN | 可恢复异常、限流、重复消息、参数边界问题 |
| ERROR | 系统异常、数据库失败、MQ 失败、LLM 调用失败 |

## 7. 日志字段规范

建议结构化日志包含：

```text
timestamp
level
service
traceId
userId
messageId
method
path
status
durationMs
errorCode
exception
```

示例：

```text
2026-05-27 10:30:00 INFO service=flowstudy-core traceId=9f2c1a7e userId=10001 path=/api/v1/problems/100/submissions message="submission created" submitId=90001
```

## 8. Core 关键日志点

```text
1. 用户注册成功 / 失败
2. 用户登录成功 / 失败
3. 接口鉴权失败
4. 代码提交创建
5. Redis 限流触发
6. Judge 任务投递成功 / 失败
7. Judge 结果消费成功 / 失败
8. 行为事件入库和投递
9. internal API 调用
```

## 9. Judge 关键日志点

```text
1. 消费到判题任务
2. 创建工作目录
3. 编译开始 / 成功 / 失败
4. 测试点运行开始 / 结束
5. 超时 / 超内存
6. 结果比对
7. 结果消息回传
8. 沙箱异常
```

不要在日志中打印完整用户代码，必要时只打印代码长度或 hash。

## 10. AI 关键日志点

```text
1. 收到 AI 问答请求
2. 获取 Core 上下文成功 / 失败
3. Prompt 构建成功
4. LLM 调用开始 / 结束
5. SSE 输出异常
6. 行为消息消费
7. 用户画像更新
8. 笔记生成任务开始 / 完成 / 失败
```

不要打印完整 Prompt、完整用户隐私数据或 LLM API Key。

## 11. 健康检查

Core：

```http
GET /api/v1/health
```

AI：

```http
GET /api/v1/ai/health
```

Judge：

```http
GET /health
```

健康检查建议返回：

```json
{
  "service": "flowstudy-core",
  "status": "UP",
  "dependencies": {
    "mysql": "UP",
    "redis": "UP",
    "rabbitmq": "UP"
  }
}
```

## 12. 指标监控建议

后期可接入：

```text
Prometheus + Grafana
```

Core 指标：

```text
HTTP 请求数
HTTP 请求耗时
错误码数量
登录成功 / 失败次数
代码提交次数
限流次数
RabbitMQ 投递失败次数
```

Judge 指标：

```text
判题任务数
平均判题耗时
编译错误数量
TLE 数量
沙箱异常数量
队列消费延迟
```

AI 指标：

```text
AI 请求数
LLM 调用耗时
LLM 调用失败次数
Token 消耗估计
笔记生成耗时
画像更新任务数
```

## 13. RabbitMQ 观测

关注：

```text
队列堆积长度
消费者数量
消息消费速率
死信队列数量
消息重试次数
```

重点队列：

```text
fs.judge.submit.queue
fs.core.judge-result.queue
fs.ai.behavior.queue
fs.ai.note.queue
fs.dlq.queue
```

## 14. 异常处理与日志关系

业务异常：

```text
使用 BusinessException
映射 ErrorCode
记录 WARN 或 INFO
```

系统异常：

```text
记录 ERROR
返回 50000 / 53000 / 54000 等系统错误码
```

禁止：

```text
1. 捕获异常后什么都不做
2. 直接 e.printStackTrace()
3. 返回原始异常堆栈给前端
4. 将数据库错误原样返回给用户
```

## 15. 日志安全红线

禁止打印：

```text
明文密码
完整 JWT
LLM API Key
数据库密码
内部服务 token
完整用户代码
完整 Prompt
```

可以打印：

```text
userId
submitId
problemId
traceId
messageId
代码长度
代码 hash
错误码
接口耗时
```

## 16. MVP 实现顺序

```text
阶段 1：Core TraceIdFilter + MDC
阶段 2：统一 Result<T> 返回 traceId
阶段 3：MQ 消息外壳携带 traceId
阶段 4：Core 关键业务日志
阶段 5：Judge 消费日志
阶段 6：AI 请求与 SSE 日志
阶段 7：健康检查接口
阶段 8：RabbitMQ 队列观测
阶段 9：Prometheus / Grafana
```

## 17. 验收标准

```text
1. 每个 HTTP 响应都有 traceId
2. 后端日志能按 traceId 搜索完整链路
3. RabbitMQ 消息包含 traceId 和 messageId
4. Judge 回传结果沿用原 traceId
5. AI 请求失败时能看到 traceId
6. 日志不包含敏感信息
7. 服务健康检查可用
8. 关键异常有 ERROR 日志
```
