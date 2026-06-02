# 08. RabbitMQ 消息契约文档

## 1. 文档目的

本文档用于统一 FlowStudy 项目中各后端服务之间的异步通信规范。FlowStudy 采用多服务架构，`flowstudy-core`、`flowstudy-judge` 和 `flowstudy-ai` 之间并不应该全部通过同步 HTTP 直接耦合。对于判题任务、判题结果、学习行为埋点、AI 分析任务等耗时或可异步处理的业务，应统一通过 RabbitMQ 进行削峰、解耦和异步流转。

本契约一旦确定，Java、Go、Python 三端都必须遵守。尤其是消息字段、Exchange 名称、Queue 名称、RoutingKey 名称、消息版本号、traceId、messageId 等字段，不允许各服务自行定义。

## 2. 适用范围

本规范适用于以下服务之间的异步通信：

| 生产者 | 消费者 | 场景 |
|---|---|---|
| `flowstudy-core` | `flowstudy-judge` | 代码提交后投递判题任务 |
| `flowstudy-judge` | `flowstudy-core` | 判题完成后回传判题结果 |
| `flowstudy-core` | `flowstudy-ai` | 用户行为、代码错误、AI 提问等学习数据分析 |
| `flowstudy-core` | `flowstudy-ai` | 个性化学习笔记生成任务 |
| 任意服务 | 死信队列 | 消息消费失败后的兜底处理 |

RabbitMQ 不用于前端与后端的直接通信。前端仍然通过 HTTP / SSE 与后端通信。

## 3. 基本原则

FlowStudy 的 MQ 设计遵循以下原则：

1. **消息结构统一**：所有消息都必须使用统一消息外壳，业务数据放入 `payload`。
2. **事件语义清晰**：RoutingKey 应表达“领域 + 动作 + 状态”，不能使用模糊名称。
3. **消费者幂等**：消费者必须根据 `messageId` 或业务 ID 处理重复消息。
4. **链路可追踪**：所有消息必须携带 `traceId`，便于 HTTP 请求、日志和 MQ 消息串联排查。
5. **失败可恢复**：消息失败后进入重试队列或死信队列，不允许无声丢失。
6. **版本可演进**：消息必须包含 `schemaVersion`，后续字段变化需要兼容旧版本。

## 4. 命名规范

### 4.1 Exchange 命名规范

格式：

```text
fs.{domain}.exchange
```

示例：

```text
fs.judge.exchange
fs.judge.result.exchange
fs.behavior.exchange
fs.ai.exchange
fs.dlx.exchange
```

其中：

| domain | 含义 |
|---|---|
| `judge` | 判题任务领域 |
| `judge.result` | 判题结果领域 |
| `behavior` | 用户行为埋点领域 |
| `ai` | AI 分析和笔记任务领域 |
| `dlx` | 死信领域 |

### 4.2 Queue 命名规范

格式：

```text
fs.{consumer}.{purpose}.queue
```

示例：

```text
fs.judge.submit.queue
fs.core.judge-result.queue
fs.ai.behavior.queue
fs.ai.note.queue
fs.dlq.queue
```

### 4.3 RoutingKey 命名规范

格式：

```text
{domain}.{action}.{status}
```

示例：

```text
judge.submit.created
judge.result.finished
behavior.chapter.view
behavior.code.submit
behavior.ai.question
ai.note.generate
```

RoutingKey 使用小写字母和点号，不使用下划线和驼峰。

## 5. Exchange 与 Queue 拓扑

### 5.1 Exchange 定义

| Exchange | 类型 | 生产者 | 说明 |
|---|---|---|---|
| `fs.judge.exchange` | `topic` | `flowstudy-core` | 投递代码判题任务 |
| `fs.judge.result.exchange` | `topic` | `flowstudy-judge` | 回传判题结果 |
| `fs.behavior.exchange` | `topic` | `flowstudy-core` | 投递用户学习行为事件 |
| `fs.ai.exchange` | `topic` | `flowstudy-core` | 投递 AI 分析、笔记生成任务 |
| `fs.dlx.exchange` | `topic` | 所有服务 | 死信交换机 |

### 5.2 Queue 绑定关系

| Queue | 绑定 Exchange | RoutingKey | 消费者 | 说明 |
|---|---|---|---|---|
| `fs.judge.submit.queue` | `fs.judge.exchange` | `judge.submit.created` | `flowstudy-judge` | 等待判题的代码任务 |
| `fs.core.judge-result.queue` | `fs.judge.result.exchange` | `judge.result.finished` | `flowstudy-core` | 判题完成结果 |
| `fs.ai.behavior.queue` | `fs.behavior.exchange` | `behavior.#` | `flowstudy-ai` | 用户行为事件 |
| `fs.ai.note.queue` | `fs.ai.exchange` | `ai.note.generate` | `flowstudy-ai` | 个性化笔记生成任务 |
| `fs.dlq.queue` | `fs.dlx.exchange` | `dlq.#` | 人工排查 / 后台补偿 | 死信消息 |

## 6. 通用消息外壳

所有 RabbitMQ 消息必须使用以下统一结构：

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

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `schemaVersion` | string | 是 | 消息结构版本，当前固定为 `1.0` |
| `messageId` | string | 是 | 消息唯一 ID，用于幂等处理 |
| `traceId` | string | 是 | 链路追踪 ID，必须从 HTTP 请求继续传递 |
| `eventType` | string | 是 | 事件类型，通常与 RoutingKey 保持一致 |
| `producer` | string | 是 | 消息生产服务名称 |
| `occurredAt` | string | 是 | 事件发生时间，ISO-8601 格式 |
| `payload` | object | 是 | 业务数据载荷 |

时间统一使用 ISO-8601 格式，例如：

```text
2026-05-27T10:30:00+08:00
```

ID 字段统一使用整数或字符串，但同一个字段在所有服务中类型必须一致。比如 `submitId` 在 Core、Judge、AI 中都应为数字类型，不允许 Core 传数字、Judge 当字符串处理。

## 7. 判题任务消息

### 7.1 业务说明

用户提交代码后，`flowstudy-core` 负责完成以下工作：

1. 校验用户身份和题目状态。
2. 对提交接口进行限流。
3. 将提交记录写入 `fs_submission` 表，状态为 `PENDING`。
4. 查询题目的时间限制、内存限制和测试用例。
5. 向 RabbitMQ 投递判题任务消息。

`flowstudy-judge` 消费该消息后执行编译、运行、比对，并回传判题结果。

### 7.2 Exchange、Queue、RoutingKey

```text
Exchange:   fs.judge.exchange
Queue:      fs.judge.submit.queue
RoutingKey: judge.submit.created
Consumer:   flowstudy-judge
```

### 7.3 消息示例

```json
{
  "schemaVersion": "1.0",
  "messageId": "msg-judge-000001",
  "traceId": "9f2c1a7e",
  "eventType": "judge.submit.created",
  "producer": "flowstudy-core",
  "occurredAt": "2026-05-27T10:30:00+08:00",
  "payload": {
    "submitId": 90001,
    "userId": 10001,
    "problemId": 100,
    "language": "java",
    "code": "public class Main { public static void main(String[] args) { } }",
    "timeLimitMs": 1000,
    "memoryLimitMb": 256,
    "testCases": [
      {
        "caseId": 1,
        "caseIndex": 1,
        "input": "4\n2 7 11 15\n9",
        "expectedOutput": "0 1",
        "isSample": true
      }
    ]
  }
}
```

### 7.4 字段说明

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `submitId` | number | 是 | 提交记录 ID |
| `userId` | number | 是 | 用户 ID |
| `problemId` | number | 是 | 题目 ID |
| `language` | string | 是 | 编程语言，如 `java`、`cpp`、`go`、`python` |
| `code` | string | 是 | 用户提交代码 |
| `timeLimitMs` | number | 是 | 时间限制，毫秒 |
| `memoryLimitMb` | number | 是 | 内存限制，MB |
| `testCases` | array | 是 | 测试用例列表 |
| `caseId` | number | 是 | 测试用例 ID |
| `caseIndex` | number | 是 | 测试点序号 |
| `input` | string | 是 | 标准输入 |
| `expectedOutput` | string | 是 | 期望输出 |
| `isSample` | boolean | 是 | 是否样例测试点 |

MVP 阶段可以直接把测试用例放入 MQ 消息中。后期如果测试用例数量较大，应改为传递 `testCaseSetId`，让 Judge 从数据库、对象存储或内部接口读取测试用例。

## 8. 判题结果消息

### 8.1 业务说明

`flowstudy-judge` 判题完成后，将结果发送给 `flowstudy-core`。Core 消费后更新 `fs_submission` 和 `fs_judge_case_result` 表，前端通过查询提交结果接口获取最终状态。

### 8.2 Exchange、Queue、RoutingKey

```text
Exchange:   fs.judge.result.exchange
Queue:      fs.core.judge-result.queue
RoutingKey: judge.result.finished
Consumer:   flowstudy-core
```

### 8.3 消息示例

```json
{
  "schemaVersion": "1.0",
  "messageId": "msg-result-000001",
  "traceId": "9f2c1a7e",
  "eventType": "judge.result.finished",
  "producer": "flowstudy-judge",
  "occurredAt": "2026-05-27T10:30:05+08:00",
  "payload": {
    "submitId": 90001,
    "status": "ACCEPTED",
    "score": 100,
    "timeUsedMs": 12,
    "memoryUsedKb": 20480,
    "compileMessage": null,
    "runtimeMessage": null,
    "caseResults": [
      {
        "caseId": 1,
        "caseIndex": 1,
        "status": "ACCEPTED",
        "timeUsedMs": 4,
        "memoryUsedKb": 10240,
        "actualOutput": "0 1",
        "expectedOutput": "0 1"
      }
    ]
  }
}
```

### 8.4 判题状态枚举

| 状态 | 含义 | 是否系统异常 |
|---|---|---:|
| `PENDING` | 等待判题 | 否 |
| `RUNNING` | 正在判题 | 否 |
| `ACCEPTED` | 通过 | 否 |
| `WRONG_ANSWER` | 答案错误 | 否 |
| `COMPILE_ERROR` | 编译错误 | 否 |
| `RUNTIME_ERROR` | 运行错误 | 否 |
| `TIME_LIMIT_EXCEEDED` | 超时 | 否 |
| `MEMORY_LIMIT_EXCEEDED` | 超内存 | 否 |
| `SYSTEM_ERROR` | 判题系统错误 | 是 |

注意：`COMPILE_ERROR`、`WRONG_ANSWER`、`RUNTIME_ERROR` 通常属于用户代码问题，不应当映射为 HTTP 500。只有沙箱异常、判题服务崩溃、消息无法处理等系统级问题才属于 `SYSTEM_ERROR`。

## 9. 用户行为消息

### 9.1 业务说明

用户在 FlowStudy 中阅读文章、停留章节、编辑代码、提交代码、查看错误、询问 AI 等行为，都会被前端或 Core 记录。Core 接收行为埋点后，可以写入数据库，同时异步发送给 AI 服务进行画像分析。

### 9.2 Exchange、Queue、RoutingKey

```text
Exchange:   fs.behavior.exchange
Queue:      fs.ai.behavior.queue
RoutingKey: behavior.#
Consumer:   flowstudy-ai
```

常用 RoutingKey：

```text
behavior.article.view
behavior.chapter.view
behavior.chapter.leave
behavior.code.edit
behavior.code.submit
behavior.judge.error
behavior.ai.question
behavior.ai.answer.view
```

### 9.3 消息示例

```json
{
  "schemaVersion": "1.0",
  "messageId": "msg-behavior-000001",
  "traceId": "9f2c1a7e",
  "eventType": "behavior.chapter.view",
  "producer": "flowstudy-core",
  "occurredAt": "2026-05-27T10:30:00+08:00",
  "payload": {
    "userId": 10001,
    "articleId": 1,
    "chapterId": 10,
    "problemId": null,
    "submissionId": null,
    "eventType": "CHAPTER_VIEW",
    "durationSeconds": 35,
    "extra": {
      "scrollPercent": 80,
      "client": "web"
    }
  }
}
```

### 9.4 行为事件类型

| eventType | 含义 |
|---|---|
| `ARTICLE_VIEW` | 打开文章 |
| `CHAPTER_VIEW` | 打开章节 |
| `CHAPTER_LEAVE` | 离开章节 |
| `CODE_EDIT` | 编辑代码 |
| `CODE_SUBMIT` | 提交代码 |
| `JUDGE_ERROR_VIEW` | 查看判题错误 |
| `AI_QUESTION` | 向 AI 提问 |
| `AI_ANSWER_VIEW` | 查看 AI 回答 |
| `NOTE_GENERATE` | 触发学习笔记生成 |

## 10. AI 笔记生成任务消息

### 10.1 业务说明

当用户完成一个章节，或者用户主动点击“生成学习笔记”时，Core 可以向 AI 服务投递笔记生成任务。AI 服务消费后，根据用户当前章节、提交记录、错误记录、提问历史和用户画像生成个性化 Markdown 笔记。

### 10.2 Exchange、Queue、RoutingKey

```text
Exchange:   fs.ai.exchange
Queue:      fs.ai.note.queue
RoutingKey: ai.note.generate
Consumer:   flowstudy-ai
```

### 10.3 消息示例

```json
{
  "schemaVersion": "1.0",
  "messageId": "msg-note-000001",
  "traceId": "9f2c1a7e",
  "eventType": "ai.note.generate",
  "producer": "flowstudy-core",
  "occurredAt": "2026-05-27T10:30:00+08:00",
  "payload": {
    "userId": 10001,
    "articleId": 1,
    "chapterId": 10,
    "noteTaskId": "note-task-001"
  }
}
```

AI 服务生成完成后，MVP 阶段可以直接调用 Core 内部接口保存笔记；后期也可以新增 `ai.note.generated` 消息，由 Core 消费后写入数据库。

## 11. 死信队列与重试策略

### 11.1 死信配置原则

所有业务队列都应绑定死信交换机：

```text
Dead Letter Exchange: fs.dlx.exchange
Dead Letter RoutingKey: dlq.{original.routing.key}
```

示例：

```text
judge.submit.created  -> dlq.judge.submit.created
judge.result.finished -> dlq.judge.result.finished
behavior.chapter.view -> dlq.behavior.chapter.view
```

### 11.2 重试建议

MVP 阶段可采用简单策略：

| 场景 | 重试次数 | 失败后处理 |
|---|---:|---|
| Judge 消费判题任务失败 | 3 次 | 进入死信队列，并将提交状态标记为 `SYSTEM_ERROR` |
| Core 消费判题结果失败 | 3 次 | 进入死信队列，等待人工补偿 |
| AI 消费行为事件失败 | 3 次 | 进入死信队列，但不影响用户主流程 |
| AI 笔记任务失败 | 3 次 | 标记任务失败，用户可重新触发 |

### 11.3 幂等处理

每个消费者都必须具备幂等能力。

推荐方式：

1. 使用 `messageId` 记录消息消费日志。
2. 对判题任务使用 `submitId` 判断是否已经处理完成。
3. 对判题结果使用 `submitId + status + updatedAt` 避免重复更新。
4. 对 AI 笔记任务使用 `noteTaskId` 避免重复生成。

MVP 阶段可以先使用业务 ID 做幂等，后续再补充 `fs_message_consume_log` 表。

## 12. 消费确认规范

消费者必须使用手动 ACK。

处理成功：

```text
basicAck
```

可重试异常：

```text
basicNack / reject，进入重试流程
```

不可恢复异常：

```text
记录错误日志，投递死信队列，避免无限重试
```

禁止在业务未完成时提前 ACK，否则可能导致消息丢失。

## 13. 生产者确认规范

Core 投递关键消息时必须确认消息是否成功到达 Broker。

对于代码提交这种核心链路，推荐流程是：

```text
写入 fs_submission(PENDING)
    ↓
投递 judge.submit.created
    ↓
确认投递成功
    ↓
返回 submitId 给前端
```

如果投递失败，应将提交状态更新为 `SYSTEM_ERROR` 或保留为 `PENDING` 并由补偿任务重新投递。

## 14. 日志与 traceId 规范

所有生产者和消费者日志都必须打印以下字段：

```text
traceId
messageId
eventType
routingKey
businessId，例如 submitId / userId / noteTaskId
```

示例：

```text
[flowstudy-core] traceId=9f2c1a7e messageId=msg-judge-000001 eventType=judge.submit.created submitId=90001 publish success
[flowstudy-judge] traceId=9f2c1a7e messageId=msg-judge-000001 submitId=90001 judge start
[flowstudy-judge] traceId=9f2c1a7e messageId=msg-result-000001 submitId=90001 judge finished status=ACCEPTED
```

## 15. 版本演进规则

消息结构变化时必须遵守以下规则：

1. 新增字段应保持向后兼容。
2. 不允许直接删除旧字段。
3. 不允许改变已有字段类型。
4. 重大不兼容变更必须升级 `schemaVersion`，例如从 `1.0` 升级到 `2.0`。
5. 消费者应忽略无法识别的额外字段。

## 16. MVP 阶段落地优先级

MVP 阶段必须先实现以下消息链路：

```text
flowstudy-core -> fs.judge.exchange -> flowstudy-judge
flowstudy-judge -> fs.judge.result.exchange -> flowstudy-core
```

也就是先打通“代码提交 -> 异步判题 -> 结果回传”主链路。

用户行为消息和 AI 笔记消息可以先定义契约，后续在 V2 / V3 阶段逐步启用。
