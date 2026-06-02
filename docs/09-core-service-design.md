# 09. Core Service 设计文档

## 1. 模块定位

`flowstudy-core` 是 FlowStudy 项目的核心业务服务，也是前端请求进入系统后的主要入口。它负责用户认证、内容分发、题目管理、代码提交、提交记录、限流、消息投递、判题结果消费、学习行为采集等主业务。

在系统角色上，Core Service 是 FlowStudy 的“前厅大管家”。它不直接运行用户代码，也不直接执行复杂 AI 推理，而是负责把用户请求转换成可靠的业务记录和异步任务，并协调 Judge Service 与 AI Agent Service 完成后续处理。

## 2. 职责边界

### 2.1 Core Service 负责什么

Core Service 负责以下内容：

1. 用户注册、登录、JWT 鉴权、用户信息管理。
2. 文章、章节、题目、测试用例的管理与查询。
3. 代码提交接口、提交记录入库、提交状态查询。
4. Redis + Lua 限流，防止高频提交代码和刷接口。
5. RabbitMQ 判题任务投递。
6. RabbitMQ 判题结果消费，并更新提交记录。
7. 用户学习行为埋点接收、入库和投递给 AI 服务。
8. 向前端提供统一 RESTful API。
9. 统一返回 `Result<T>`、统一错误码、统一异常处理。
10. 生成和传递 `traceId`，保证链路可追踪。

### 2.2 Core Service 不负责什么

Core Service 不负责以下内容：

1. 不直接编译和运行用户代码。
2. 不在 Java 服务内部实现判题沙箱。
3. 不直接调用大模型完成复杂 Agent 工作流。
4. 不保存真实的大模型 API Key 到代码仓库。
5. 不直接暴露 Judge Service 到公网。
6. 不在同步接口中执行耗时判题或长时间 AI 分析。

判题相关工作交给 `flowstudy-judge`，AI 问答、画像和笔记生成交给 `flowstudy-ai`。

## 3. 推荐技术栈

| 类别 | 技术 |
|---|---|
| 编程语言 | Java 17 |
| Web 框架 | Spring Boot 3.x + Spring MVC |
| ORM | MyBatis-Plus |
| 数据库 | MySQL 8.4 |
| 缓存 / 限流 | Redis 7.2 + Lua |
| 消息队列 | RabbitMQ 3.13 |
| 鉴权 | JWT |
| 参数校验 | Jakarta Validation |
| API 文档 | Apifox / OpenAPI |
| 日志 | Logback / SLF4J |
| 代码规范 | Spotless / Checkstyle 可选 |

## 4. 推荐包结构

建议 Core Service 使用清晰的分层结构：

```text
flowstudy-core/
└── src/main/java/com/flowstudy/core/
    ├── FlowStudyCoreApplication.java
    ├── common/
    │   ├── result/
    │   │   ├── Result.java
    │   │   ├── PageResult.java
    │   │   └── ErrorCode.java
    │   ├── exception/
    │   │   ├── BusinessException.java
    │   │   └── GlobalExceptionHandler.java
    │   ├── trace/
    │   │   └── TraceIdFilter.java
    │   └── util/
    ├── config/
    │   ├── SecurityConfig.java
    │   ├── RedisConfig.java
    │   ├── RabbitMqConfig.java
    │   └── CorsConfig.java
    ├── security/
    │   ├── JwtTokenProvider.java
    │   ├── JwtAuthenticationFilter.java
    │   └── LoginUser.java
    ├── module/
    │   ├── auth/
    │   ├── user/
    │   ├── article/
    │   ├── chapter/
    │   ├── problem/
    │   ├── submission/
    │   ├── tracking/
    │   └── ai/
    ├── mq/
    │   ├── producer/
    │   ├── consumer/
    │   ├── message/
    │   └── constants/
    └── infrastructure/
        ├── redis/
        └── mysql/
```

每个业务模块内部可以按照以下结构组织：

```text
module/problem/
├── controller/
├── service/
├── service/impl/
├── mapper/
├── entity/
├── dto/
├── vo/
└── convert/
```

其中：

| 层 | 作用 |
|---|---|
| `controller` | 接收 HTTP 请求，做参数校验，不写复杂业务 |
| `service` | 核心业务逻辑，处理事务和服务编排 |
| `mapper` | MyBatis-Plus 数据访问 |
| `entity` | 数据库实体 |
| `dto` | 请求参数对象 |
| `vo` | 响应对象 |
| `convert` | Entity、DTO、VO 转换 |

## 5. 核心业务模块设计

### 5.1 Auth 模块

负责用户注册、登录和 JWT 发放。

主要接口：

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/users/me
```

核心流程：

```text
用户提交账号密码
    ↓
校验参数
    ↓
查询用户
    ↓
校验密码哈希
    ↓
生成 JWT
    ↓
返回用户信息和 accessToken
```

密码必须使用哈希存储，禁止明文保存。

### 5.2 Content 模块

Content 模块包括文章、章节、题目三个部分。

主要职责：

1. 展示文章列表。
2. 展示文章详情。
3. 展示章节内容。
4. 展示题目描述、样例和限制条件。
5. 为前端 Markdown 阅读页和代码练习区提供数据。

主要接口：

```http
GET /api/v1/articles
GET /api/v1/articles/{articleId}
GET /api/v1/articles/{articleId}/chapters
GET /api/v1/chapters/{chapterId}
GET /api/v1/problems
GET /api/v1/problems/{problemId}
GET /api/v1/problems/{problemId}/template?language=java
```

### 5.3 Submission 模块

Submission 模块是 Core Service 的关键模块，负责代码提交和状态查询。

主要接口：

```http
POST /api/v1/problems/{problemId}/submissions
GET  /api/v1/submissions/{submitId}
GET  /api/v1/users/me/submissions
```

提交状态包括：

```text
PENDING
RUNNING
ACCEPTED
WRONG_ANSWER
COMPILE_ERROR
RUNTIME_ERROR
TIME_LIMIT_EXCEEDED
MEMORY_LIMIT_EXCEEDED
SYSTEM_ERROR
```

### 5.4 Tracking 模块

Tracking 模块负责接收前端学习行为埋点。

主要接口：

```http
POST /api/v1/tracking/events
```

典型事件包括：

```text
ARTICLE_VIEW
CHAPTER_VIEW
CHAPTER_LEAVE
CODE_EDIT
CODE_SUBMIT
JUDGE_ERROR_VIEW
AI_QUESTION
AI_ANSWER_VIEW
NOTE_GENERATE
```

Core 接收到事件后，建议执行两个动作：

1. 写入 `fs_behavior_event` 表。
2. 投递 `behavior.#` 消息给 AI 服务。

## 6. 代码提交主流程

代码提交是 V1 MVP 的核心链路。

### 6.1 业务流程

```text
前端提交代码
    ↓
Core 校验 JWT
    ↓
Core 进行 Redis 限流
    ↓
Core 校验 problemId 是否存在
    ↓
Core 查询题目限制和测试用例
    ↓
Core 写入 fs_submission，状态为 PENDING
    ↓
Core 投递 judge.submit.created 消息
    ↓
Core 返回 submitId 给前端
    ↓
前端轮询 GET /submissions/{submitId}
```

### 6.2 事务边界

推荐事务范围：

```text
写入 fs_submission
读取必要题目数据
构建 MQ 消息
```

MQ 投递与数据库事务需要特别注意。MVP 阶段可以采用以下简化方案：

1. 先写入 `fs_submission(PENDING)`。
2. 再投递 MQ。
3. 如果 MQ 投递失败，将提交状态更新为 `SYSTEM_ERROR`，或者保留为 `PENDING` 后由补偿任务重新投递。

后期可以引入本地消息表 Outbox Pattern，提高一致性。

### 6.3 伪代码

```java
@Transactional
public SubmitCodeVO submitCode(Long userId, Long problemId, SubmitCodeDTO dto) {
    rateLimit(userId, problemId);

    Problem problem = problemService.getPublishedProblem(problemId);
    List<Testcase> testCases = testcaseService.listByProblemId(problemId);

    Submission submission = submissionService.createPendingSubmission(userId, problemId, dto);

    JudgeSubmitMessage message = JudgeSubmitMessage.from(submission, problem, testCases);
    judgeProducer.publish(message);

    return new SubmitCodeVO(submission.getId(), "PENDING");
}
```

## 7. 判题结果消费流程

### 7.1 业务流程

```text
Judge 完成判题
    ↓
Judge 投递 judge.result.finished
    ↓
Core 消费 fs.core.judge-result.queue
    ↓
Core 根据 submitId 查询提交记录
    ↓
Core 更新 fs_submission 状态、耗时、内存、错误信息
    ↓
Core 写入 fs_judge_case_result
    ↓
前端查询时获得最终结果
```

### 7.2 幂等要求

Core 消费判题结果时必须具备幂等能力。

建议规则：

1. 如果 `submitId` 不存在，记录错误并拒绝更新。
2. 如果提交状态已经是终态，不重复写入测试点结果。
3. 如果重复收到相同 `messageId`，直接 ACK。
4. 判题结果更新和测试点结果写入应放在同一个事务中。

终态包括：

```text
ACCEPTED
WRONG_ANSWER
COMPILE_ERROR
RUNTIME_ERROR
TIME_LIMIT_EXCEEDED
MEMORY_LIMIT_EXCEEDED
SYSTEM_ERROR
```

## 8. Redis 设计

Core 使用 Redis 主要处理限流、缓存和短期状态。

### 8.1 提交限流

限流 Key 示例：

```text
fs:rate:submit:{userId}:{problemId}
fs:rate:submit:ip:{ip}
```

推荐策略：

| 场景 | 限制 |
|---|---:|
| 单用户单题提交 | 每分钟 20 次 |
| 单 IP 提交 | 每分钟 60 次 |
| AI 问答 | 每分钟 10 次 |
| 行为埋点 | 批量上报，每 5 到 10 秒一次 |

限流应使用 Redis + Lua 保证原子性。

### 8.2 缓存建议

可缓存内容：

```text
文章详情
章节内容
题目详情
代码模板
用户基本信息
```

缓存 Key 示例：

```text
fs:article:{articleId}
fs:chapter:{chapterId}
fs:problem:{problemId}
fs:user:{userId}
```

MVP 阶段可以先不做复杂缓存，只做提交限流。

## 9. RabbitMQ 设计

Core 同时是 MQ 生产者和消费者。

### 9.1 Core 作为生产者

| 场景 | Exchange | RoutingKey |
|---|---|---|
| 投递判题任务 | `fs.judge.exchange` | `judge.submit.created` |
| 投递用户行为 | `fs.behavior.exchange` | `behavior.#` |
| 投递笔记生成任务 | `fs.ai.exchange` | `ai.note.generate` |

### 9.2 Core 作为消费者

| 场景 | Queue | RoutingKey |
|---|---|---|
| 消费判题结果 | `fs.core.judge-result.queue` | `judge.result.finished` |

### 9.3 消息对象建议

```text
mq/message/
├── BaseMqMessage.java
├── JudgeSubmitPayload.java
├── JudgeResultPayload.java
├── BehaviorEventPayload.java
└── AiNoteGeneratePayload.java
```

所有消息对象都应符合 `08-rabbitmq-message-contract.md`。

## 10. 统一返回与异常处理

Core 必须严格遵守 `06-result-error-code-contract.md`。

普通成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

Core 中建议定义：

```text
Result<T>
PageResult<T>
ErrorCode
BusinessException
GlobalExceptionHandler
```

常见错误码：

| 错误码 | 场景 |
|---:|---|
| `40000` | 参数错误 |
| `40100` | 未登录或 Token 无效 |
| `40300` | 无权限 |
| `40400` | 资源不存在 |
| `40900` | 用户名重复、数据冲突 |
| `42900` | 请求过于频繁 |
| `50000` | Core 内部错误 |
| `53000` | 判题服务异常 |
| `54000` | AI 服务异常 |

## 11. traceId 设计

Core 是 traceId 的主要生成入口。

规则：

1. 如果请求头中存在 `X-Trace-Id`，则沿用该值。
2. 如果不存在，则 Core 自动生成新的 traceId。
3. 所有响应体必须包含 traceId。
4. 所有日志必须打印 traceId。
5. 所有 MQ 消息必须携带 traceId。
6. 调用 AI 内部接口时必须在 Header 中传递 traceId。

请求头示例：

```http
X-Trace-Id: 9f2c1a7e
```

## 12. 安全设计

### 12.1 JWT 鉴权

需要登录的接口必须携带：

```http
Authorization: Bearer <access_token>
```

公开接口包括：

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/articles
GET  /api/v1/articles/{articleId}
```

需要登录的接口包括：

```text
POST /api/v1/problems/{problemId}/submissions
GET  /api/v1/submissions/{submitId}
POST /api/v1/tracking/events
POST /api/v1/ai/**
```

管理接口需要 `ADMIN` 角色。

### 12.2 内部服务鉴权

如果 AI 服务需要调用 Core 内部接口获取上下文，建议使用内部 Token：

```http
X-Internal-Token: <internal-api-token>
```

内部 Token 必须从环境变量读取，禁止硬编码。

## 13. 与 AI Service 的关系

Core 与 AI 的关系包括两种：

1. 前端通过 Core 或网关访问 AI SSE 接口。
2. AI 服务通过 Core 内部接口获取文章、章节、题目、提交记录等上下文。

建议提供内部接口：

```http
GET /api/v1/internal/ai/context?userId=10001&chapterId=10&problemId=100&submitId=90001
```

该接口只允许 AI 服务访问，不对普通前端用户开放。

返回内容可以包括：

```text
用户基本信息
当前文章标题
当前章节 Markdown
题目描述
用户最近提交代码
判题错误信息
用户历史提问摘要
```

## 14. 数据库访问规范

1. 所有表统一使用逻辑删除字段 `deleted`。
2. 所有核心表必须包含 `created_at` 和 `updated_at`。
3. 查询默认过滤 `deleted = 0`。
4. 业务 ID 使用 `BIGINT`。
5. 枚举字段使用字符串存储，便于调试和跨语言通信。
6. 大文本字段使用 `MEDIUMTEXT`。
7. JSON 扩展字段使用 MySQL `JSON` 类型。

## 15. MVP 开发优先级

Core Service 的开发顺序建议如下：

```text
第一阶段：项目骨架
    Result<T>
    全局异常处理
    traceId
    MySQL / Redis / RabbitMQ 配置

第二阶段：用户与内容
    注册登录
    JWT 鉴权
    文章列表
    章节详情
    题目详情

第三阶段：代码提交主链路
    提交代码
    写入 fs_submission
    投递判题任务 MQ

第四阶段：判题结果回传
    消费 judge.result.finished
    更新提交状态
    查询提交结果

第五阶段：学习行为与 AI 入口
    tracking events
    AI context internal API
    AI chat / note 相关接口
```

MVP 验收标准：用户可以注册登录、浏览文章、进入章节、查看题目、提交代码，并异步获得判题结果。
