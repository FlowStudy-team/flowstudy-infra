# FlowStudy Core Service 开发执行手册

> 文档版本：v2.0  
> 适用仓库：`flowstudy-core`  
> 当前日期：2026-05-27  
> 执行目标：让 Codex 或任意后端开发者可以按阶段连续实现 Core Service，不需要再临时决定技术路线、接口路径、包结构或验收方式。

---

## 1. 当前状态

当前仓库已经是 Spring Boot 3 工程，核心文件如下：

```text
pom.xml
src/main/java/com/flowstudy/core/FlowstudyCoreApplication.java
src/main/resources/application.yml
src/main/resources/application-local.yml
src/main/resources/application-example.yml
src/test/java/com/flowstudy/core/FlowstudyCoreApplicationTests.java
docs/
```

当前 `pom.xml` 已有：

```text
spring-boot-starter-web
mybatis-spring-boot-starter
mysql-connector-j
lombok
spring-boot-starter-test
mybatis-spring-boot-starter-test
```

后续实现路线锁定为 **MyBatis-Plus**，因此第 0 阶段必须把 MyBatis 原生 starter 替换为 MyBatis-Plus starter，并补齐 validation、security、amqp、redis、jwt 等依赖。

---

## 2. 执行原则

### 2.1 开发顺序

严格按阶段推进。除非前置阶段已经验收，否则不要提前开发后续阶段。

```text
Phase 0  工程与依赖基座
Phase 1  统一返回、异常、traceId
Phase 2  配置与基础设施连接
Phase 3  数据库 schema、实体、Mapper
Phase 4  认证与用户上下文
Phase 5  文章、章节、题目查询
Phase 6  提交代码与 MQ 投递
Phase 7  判题结果消费
Phase 8  Redis 限流
Phase 9  行为埋点
Phase 10 AI 内部上下文接口
Phase 11 管理后台接口
Phase 12 工程收尾与联调
```

MVP 主链路必须先完成：

```text
注册 / 登录
  -> 浏览文章
  -> 阅读章节
  -> 查看题目
  -> 提交代码
  -> Core 投递 judge.submit.created
  -> Core 消费 judge.result.finished
  -> 前端查询提交结果
```

### 2.2 服务边界

Core 负责：

```text
用户注册、登录、JWT 鉴权
文章、章节、题目、测试用例查询
代码提交入口与提交记录落库
RabbitMQ 判题任务投递
RabbitMQ 判题结果消费
学习行为埋点接收、落库、转发
Redis 限流
AI 内部上下文查询
管理端内容维护
```

Core 不负责：

```text
不运行用户代码
不实现 Docker / Linux 沙箱
不编译用户代码
不直接调用大模型完成 Agent 工作流
不渲染前端页面
不把 Judge 服务暴露给公网
```

### 2.3 契约来源

实现时优先遵守以下文档：

```text
docs/05-restful-api-contract.md
docs/06-result-error-code-contract.md
docs/08-rabbitmq-message-contract.md
docs/09-core-service-design.md
docs/04-dev-environment.md
```

当本文档和上述契约冲突时，以契约文档为准，并同步修正本文档。

---

## 3. 全局技术约定

### 3.1 技术栈

```text
Java 17
Spring Boot 3.4.1
Spring MVC
Spring Security
MyBatis-Plus
MySQL 8.x
Redis 7.x
RabbitMQ 3.x
JWT
Jakarta Validation
Lombok
JUnit 5
```

### 3.2 推荐包结构

```text
src/main/java/com/flowstudy/core/
├── FlowstudyCoreApplication.java
├── common/
│   ├── result/
│   ├── exception/
│   ├── error/
│   ├── page/
│   ├── trace/
│   └── util/
├── config/
├── security/
├── module/
│   ├── auth/
│   ├── user/
│   ├── article/
│   ├── chapter/
│   ├── problem/
│   ├── submission/
│   ├── tracking/
│   └── internal/
├── mq/
│   ├── config/
│   ├── constants/
│   ├── producer/
│   ├── consumer/
│   └── message/
└── admin/
```

每个业务模块内部按需使用：

```text
controller
service
service/impl
mapper
entity
dto
vo
enums
convert
```

### 3.3 编码约定

```text
Controller 只处理 HTTP、参数校验和响应封装
Service 负责业务流程、事务边界和跨模块编排
Mapper 只做数据访问
Entity 只映射数据库表
DTO 只承载请求参数
VO 只承载响应数据
MQ Message 不复用 HTTP DTO
枚举字段数据库保存枚举名字符串
所有时间返回 ISO-8601 字符串，Result.timestamp 使用毫秒时间戳
所有普通 HTTP API 返回 Result<T>
所有分页 API 返回 Result<PageResult<T>>
```

### 3.4 统一接口路径

```text
GET  /api/v1/health
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/users/me
GET  /api/v1/articles
GET  /api/v1/articles/{articleId}
GET  /api/v1/articles/{articleId}/chapters
GET  /api/v1/chapters/{chapterId}
GET  /api/v1/problems
GET  /api/v1/problems/{problemId}
GET  /api/v1/problems/{problemId}/template
POST /api/v1/problems/{problemId}/submissions
GET  /api/v1/submissions/{submitId}
GET  /api/v1/submissions/my
POST /api/v1/tracking/events
GET  /api/v1/internal/context
```

管理端统一使用：

```text
/api/v1/admin/**
```

### 3.5 RabbitMQ 命名

严格使用 `docs/08-rabbitmq-message-contract.md`：

```text
判题任务:
Exchange   fs.judge.exchange
Queue      fs.judge.submit.queue
RoutingKey judge.submit.created

判题结果:
Exchange   fs.judge.result.exchange
Queue      fs.core.judge-result.queue
RoutingKey judge.result.finished

行为事件:
Exchange   fs.behavior.exchange
Queue      fs.ai.behavior.queue
RoutingKey behavior.#
```

所有 MQ 消息必须使用统一外壳：

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

---

## 4. Phase 0：工程与依赖基座

### Goal

把当前工程整理为后续可持续开发的 Spring Boot Core 基座。

### Inputs

```text
pom.xml
application.yml
application-local.yml
application-example.yml
docs/04-dev-environment.md
```

### Implementation

```text
替换 mybatis-spring-boot-starter 为 mybatis-plus-spring-boot3-starter
保留 mysql-connector-j、lombok、spring-boot-starter-test
新增 spring-boot-starter-validation
新增 spring-boot-starter-security
新增 spring-boot-starter-amqp
新增 spring-boot-starter-data-redis
新增 JWT 依赖，优先使用 io.jsonwebtoken:jjwt-api / jjwt-impl / jjwt-jackson
建立 common、config、security、module、mq、admin 基础包
实现 HealthController
配置应用端口、profile、基础日志
完善 application-example.yml 中的环境变量说明
```

### APIs

```http
GET /api/v1/health
```

### Acceptance

```text
项目可以编译
应用可以启动
/api/v1/health 返回 Result
pom 中不再使用 MyBatis 原生 starter
README 或 application-example.yml 能说明必要环境变量
```

### Verify

```bash
./mvnw test
./mvnw spring-boot:run
```

手工请求：

```http
GET http://localhost:8080/api/v1/health
```

### Stop Conditions

```text
依赖版本冲突导致项目无法编译
本地没有 JDK 17
application-local.yml 与 application.yml 配置结构冲突
```

---

## 5. Phase 1：统一返回、异常、traceId

### Goal

建立所有 HTTP API 的统一响应、错误码、异常处理和 traceId 链路能力。

### Inputs

```text
docs/06-result-error-code-contract.md
docs/09-core-service-design.md
```

### Implementation

```text
实现 Result<T>
实现 PageResult<T>
实现 ErrorCode 枚举或常量类
实现 BusinessException
实现 GlobalExceptionHandler
实现 TraceIdContext
实现 TraceIdFilter
将 X-Trace-Id 写入 MDC
响应体自动携带 traceId
处理 MethodArgumentNotValidException
处理 MissingServletRequestParameterException
处理 HttpMessageNotReadableException
处理未捕获 Exception
配置 JSON 时间格式
```

### Error Codes

必须覆盖：

```text
0
40000 40001 40002 40003
40100 40101 40102
40300
40400
40500
40900
42900
50000 50001 50002 50003
41000-41006
42000-42007
43000-43005
53000-53005
54000-54009
55000-55004
```

### Acceptance

```text
成功响应结构与契约一致
异常响应结构与契约一致
每个响应都有 traceId
请求头传入 X-Trace-Id 时沿用该值
请求头未传入 X-Trace-Id 时自动生成
日志中包含 traceId
```

### Verify

```bash
./mvnw test
```

手工验证：

```http
GET /api/v1/health
GET /api/v1/not-exists
```

### Stop Conditions

```text
无法让 Result 在异常响应和普通响应中保持一致
Spring Security 默认错误响应绕过 GlobalExceptionHandler
```

---

## 6. Phase 2：配置与基础设施连接

### Goal

让 Core 能在本地连接 MySQL、Redis、RabbitMQ，并提供清晰的配置入口。

### Inputs

```text
docs/04-dev-environment.md
docs/08-rabbitmq-message-contract.md
application-example.yml
```

### Implementation

```text
配置 DataSource
配置 MyBatis-Plus
配置 RedisTemplate 或 StringRedisTemplate
配置 RabbitTemplate
配置 RabbitMQ exchange、queue、binding
配置 publisher confirm / returns
配置 consumer manual ack 的基础参数
配置 CORS allowed origins
配置 JWT secret 和 expire seconds
配置 internal api token
```

### Required Environment Variables

```text
APP_PORT
SPRING_PROFILES_ACTIVE
DB_URL
DB_USERNAME
DB_PASSWORD
REDIS_HOST
REDIS_PORT
REDIS_PASSWORD
RABBITMQ_HOST
RABBITMQ_PORT
RABBITMQ_USERNAME
RABBITMQ_PASSWORD
RABBITMQ_VHOST
JWT_SECRET
JWT_EXPIRE_SECONDS
INTERNAL_API_TOKEN
CORS_ALLOWED_ORIGINS
```

### Acceptance

```text
缺少必要配置时启动错误明确
MySQL 连接可用
Redis 连接可用
RabbitMQ exchange / queue / binding 声明成功
配置文件中不写死密码和 Token
```

### Verify

```bash
./mvnw test
./mvnw spring-boot:run
```

### Stop Conditions

```text
本地没有启动 MySQL / Redis / RabbitMQ
RabbitMQ 账号、vhost 或权限与开发环境文档不一致
```

---

## 7. Phase 3：数据库 schema、实体、Mapper

### Goal

建立 MVP 主链路所需数据库表、实体、枚举和 Mapper。

### Inputs

```text
docs/05-restful-api-contract.md
docs/06-result-error-code-contract.md
docs/09-core-service-design.md
```

### Tables

MVP 必须实现：

```text
sys_user
fs_article
fs_chapter
fs_problem
fs_problem_testcase
fs_submission
fs_judge_case_result
fs_behavior_event
```

后期预留，不在 MVP 第一轮实现：

```text
fs_ai_conversation
fs_ai_message
fs_user_profile
fs_learning_note
```

### Implementation

```text
编写初始化 SQL
实现 Entity
实现 Mapper
实现枚举：UserRole、UserStatus、ContentStatus、ProblemDifficulty、JudgeStatus、BehaviorEventType
配置 MyBatis-Plus 逻辑删除
配置 created_at / updated_at 自动填充
为常用查询建立索引
准备最小种子数据
```

### Schema Rules

```text
主键 BIGINT
逻辑删除字段 deleted
创建时间 created_at
更新时间 updated_at
枚举字段 VARCHAR
大文本 MEDIUMTEXT
扩展字段 JSON 或 TEXT
```

### Required Indexes

```text
sys_user.username unique
sys_user.email unique
fs_article.status
fs_chapter.article_id + sort_order
fs_problem.chapter_id
fs_submission.user_id + created_at
fs_submission.problem_id + created_at
fs_judge_case_result.submission_id + case_index unique
fs_behavior_event.user_id + occurred_at
```

### Acceptance

```text
初始化 SQL 可以在空库执行成功
实体字段与表字段一致
Mapper 可以查询核心表
逻辑删除生效
自动填充 created_at / updated_at 生效
种子数据能支持内容查询和提交链路
```

### Verify

```bash
./mvnw test
```

### Stop Conditions

```text
已有数据库表结构与计划冲突
MyBatis-Plus 自动填充或逻辑删除配置无法稳定生效
```

---

## 8. Phase 4：认证与用户上下文

### Goal

完成注册、登录、JWT 鉴权和当前登录用户上下文。

### APIs

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/users/me
```

### Implementation

```text
实现 RegisterRequest
实现 LoginRequest
实现 LoginResponse
实现 CurrentUserResponse
实现 AuthController
实现 UserController
实现 AuthService
实现 JwtTokenProvider
实现 JwtAuthenticationFilter
实现 LoginUser
实现 UserContext
配置 SecurityConfig
配置 BCryptPasswordEncoder
注册时校验 username / email 唯一
登录时支持 username 或 email
禁用用户不能登录
```

### Public APIs

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/health
GET  /api/v1/articles
GET  /api/v1/articles/{articleId}
GET  /api/v1/articles/{articleId}/chapters
GET  /api/v1/chapters/{chapterId}
GET  /api/v1/problems
GET  /api/v1/problems/{problemId}
GET  /api/v1/problems/{problemId}/template
```

其余默认需要认证。

### Acceptance

```text
用户可以注册
重复 username 返回 41002
重复 email 返回 41003
密码 BCrypt 存储
用户可以登录并获得 Bearer token
携带 token 可访问 /api/v1/users/me
无 token 访问受保护接口返回 40100
USER 访问 ADMIN 接口返回 40300
```

### Verify

```bash
./mvnw test
```

手工验证注册、登录、当前用户接口。

### Stop Conditions

```text
Spring Security 默认 401 / 403 响应无法接入 Result
JWT secret 未配置
```

---

## 9. Phase 5：文章、章节、题目查询

### Goal

完成前端学习页面所需的内容读取能力。

### APIs

```http
GET /api/v1/articles?page=1&size=10&keyword=java
GET /api/v1/articles/{articleId}
GET /api/v1/articles/{articleId}/chapters
GET /api/v1/chapters/{chapterId}
GET /api/v1/problems?chapterId=10&page=1&size=10
GET /api/v1/problems/{problemId}
GET /api/v1/problems/{problemId}/template?language=java
```

### Implementation

```text
实现 ArticleController / ArticleService
实现 ChapterController / ChapterService
实现 ProblemController / ProblemService
文章列表默认只返回 PUBLISHED
文章详情普通用户只能访问 PUBLISHED
章节列表按 sort_order 升序
章节详情包含关联题目摘要
题目列表支持 chapterId、difficulty、keyword、page、size
题目详情包含 sampleCases
题目详情不返回隐藏测试用例
代码模板按 language 返回
不支持语言返回 42006
```

### Acceptance

```text
可以查询文章列表
可以查询文章详情
可以查询章节列表
可以查询章节详情
可以查询题目列表
可以查询题目详情
普通接口不会返回隐藏测试用例
未发布内容普通用户不可见
不存在资源返回对应 42000 / 42001 / 42002
```

### Verify

```bash
./mvnw test
```

### Stop Conditions

```text
契约文档中的字段与当前数据库字段冲突
样例测试用例和隐藏测试用例无法区分
```

---

## 10. Phase 6：提交代码与 MQ 投递

### Goal

完成代码提交入口、提交记录落库、提交查询和判题任务投递。

### APIs

```http
POST /api/v1/problems/{problemId}/submissions
GET  /api/v1/submissions/{submitId}
GET  /api/v1/submissions/my?problemId=100&page=1&size=10
```

### Implementation

```text
实现 SubmitCodeRequest
实现 SubmitCodeResponse
实现 SubmissionDetailResponse
实现 SubmissionSummaryResponse
实现 SubmissionController
实现 SubmissionService
实现 JudgeSubmitProducer
实现 BaseMqMessage<T>
实现 JudgeSubmitPayload
提交时校验登录用户
校验题目存在且 PUBLISHED
校验 language 支持
校验 code 非空和最大长度
写入 fs_submission，状态 PENDING
查询题目全部测试用例
投递 judge.submit.created
投递失败时更新提交为 SYSTEM_ERROR 或抛出 43004
查询提交详情时只能查看本人提交，ADMIN 后续可扩展查看全部
```

### MQ

```text
Exchange   fs.judge.exchange
Queue      fs.judge.submit.queue
RoutingKey judge.submit.created
```

Payload 必须包含：

```text
submitId
userId
problemId
language
code
timeLimitMs
memoryLimitMb
testCases
```

### Acceptance

```text
登录用户可以提交代码
fs_submission 产生 PENDING 记录
RabbitMQ 收到 judge.submit.created
消息包含 schemaVersion、messageId、traceId、eventType、producer、occurredAt、payload
用户可以查询自己的提交详情
用户可以分页查询自己的提交列表
用户不能查询其他人的提交
```

### Verify

```bash
./mvnw test
```

手工检查 RabbitMQ Management 中的 exchange、queue、message。

### Stop Conditions

```text
RabbitMQ 不可用
生产者确认无法判断消息投递是否成功
测试用例数量过大导致消息体不可接受
```

---

## 11. Phase 7：判题结果消费

### Goal

消费 Judge 回传结果，更新提交状态和测试点结果。

### MQ

```text
Exchange   fs.judge.result.exchange
Queue      fs.core.judge-result.queue
RoutingKey judge.result.finished
```

### Implementation

```text
实现 JudgeResultConsumer
实现 JudgeResultPayload
实现 JudgeCaseResultPayload
消费使用手动 ACK
根据 submitId 查询提交记录
提交不存在时记录错误并 ACK 或进入死信，按实现稳定性选择
终态提交不重复写入测试点
更新 fs_submission 的 status、score、time_used_ms、memory_used_kb、compile_message、runtime_message
写入 fs_judge_case_result
submission_id + case_index 保证唯一
同一 submitId 的更新放入事务
```

### Terminal Statuses

```text
ACCEPTED
WRONG_ANSWER
COMPILE_ERROR
RUNTIME_ERROR
TIME_LIMIT_EXCEEDED
MEMORY_LIMIT_EXCEEDED
SYSTEM_ERROR
```

### Acceptance

```text
Core 可以消费 judge.result.finished
提交状态能更新为终态
测试点结果可以落库
重复消息不会生成重复测试点
查询提交详情能返回 caseResults
消费日志包含 traceId、messageId、submitId
```

### Verify

```bash
./mvnw test
```

手工向队列发送一条符合契约的 Mock 判题结果消息。

### Stop Conditions

```text
Judge 消息结构与契约不一致
重复消费导致状态覆盖风险无法处理
手动 ACK 配置不稳定
```

---

## 12. Phase 8：Redis 限流

### Goal

保护登录、提交和埋点等高频接口。

### Targets

```text
POST /api/v1/auth/login
POST /api/v1/problems/{problemId}/submissions
POST /api/v1/tracking/events
```

### Rules

```text
同一 IP 每分钟最多登录 10 次
同一用户每分钟最多提交代码 20 次
同一 IP 每分钟最多提交代码 60 次
同一用户每分钟最多上报埋点 120 次
```

### Implementation

```text
实现 RateLimitProperties
实现 RateLimitService
实现 Redis Lua 限流脚本
实现注解或拦截器方式限流
限流 key 包含 userId / IP / path
超限返回 42900
Redis 异常时记录日志，MVP 默认放行主流程
```

### Acceptance

```text
正常频率请求通过
超出限制返回 42900
限流响应包含 traceId
限流日志包含 userId、IP、path、traceId
规则可以通过配置调整
```

### Verify

```bash
./mvnw test
```

手工或脚本连续请求登录 / 提交接口。

### Stop Conditions

```text
Redis 不可用且降级策略不明确
无法可靠获取真实客户端 IP
```

---

## 13. Phase 9：行为埋点

### Goal

接收前端学习行为，落库并异步投递给 AI 服务。

### API

```http
POST /api/v1/tracking/events
```

### Event Types

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

### Implementation

```text
实现 TrackingController
实现 TrackingService
实现 TrackingEventBatchRequest
实现 BehaviorEventPayload
支持批量上报
限制单批最大数量，默认 50
校验 eventType
校验可选关联 ID 是否存在
写入 fs_behavior_event
投递 behavior.# 消息
返回 accepted 数量
```

### MQ

```text
Exchange   fs.behavior.exchange
Queue      fs.ai.behavior.queue
RoutingKey 根据事件映射为 behavior.article.view / behavior.chapter.view 等
```

### Acceptance

```text
登录用户可以上报行为事件
行为事件可以落库
行为事件可以投递 RabbitMQ
非法事件返回 40000
超出批量限制返回 40000
```

### Verify

```bash
./mvnw test
```

### Stop Conditions

```text
前端事件字段与契约不一致
extra 字段 JSON 存储方案与 MySQL 版本冲突
```

---

## 14. Phase 10：AI 内部上下文接口

### Goal

为 `flowstudy-ai` 提供可信上下文数据。

### API

```http
GET /api/v1/internal/context?userId=10001&articleId=1&chapterId=10&problemId=100&submitId=90001
```

### Auth

```http
X-Internal-Token: <internal-token>
```

### Implementation

```text
实现 InternalContextController
实现 InternalContextService
实现 InternalTokenFilter 或 HandlerInterceptor
按 userId、articleId、chapterId、problemId、submitId 聚合上下文
返回文章标题和摘要
返回章节 Markdown
返回题目描述、输入输出说明
返回最近提交代码和判题错误信息
返回测试点错误摘要
返回最近行为摘要
不返回内部 Token、数据库敏感信息
不在日志打印完整用户代码
```

### Acceptance

```text
携带正确 X-Internal-Token 可访问
缺少 token 返回 55001 或 40300
错误 token 返回 55002 或 40300
普通 JWT 不能替代 internal token
返回数据足够 AI 进行上下文问答
隐藏测试用例不被过度暴露
```

### Verify

```bash
./mvnw test
```

### Stop Conditions

```text
AI 服务需要的上下文字段超出当前数据库能力
是否返回隐藏测试用例 expectedOutput 存在安全争议
```

---

## 15. Phase 11：管理后台接口

### Goal

为 ADMIN 提供内容维护能力。该阶段晚于 MVP 主链路。

### APIs

```http
POST   /api/v1/admin/articles
PUT    /api/v1/admin/articles/{articleId}
DELETE /api/v1/admin/articles/{articleId}
POST   /api/v1/admin/chapters
PUT    /api/v1/admin/chapters/{chapterId}
DELETE /api/v1/admin/chapters/{chapterId}
POST   /api/v1/admin/problems
PUT    /api/v1/admin/problems/{problemId}
DELETE /api/v1/admin/problems/{problemId}
POST   /api/v1/admin/problems/{problemId}/testcases
PUT    /api/v1/admin/testcases/{testcaseId}
DELETE /api/v1/admin/testcases/{testcaseId}
```

### Implementation

```text
实现 AdminArticleController
实现 AdminChapterController
实现 AdminProblemController
实现 AdminTestcaseController
ADMIN 可新增、编辑、发布、下架文章
ADMIN 可新增、编辑、排序章节
ADMIN 可新增、编辑、发布、下架题目
ADMIN 可维护样例和隐藏测试用例
删除默认逻辑删除
```

### Acceptance

```text
ADMIN 可以访问 /api/v1/admin/**
USER 访问返回 40300
未登录访问返回 40100
内容发布后普通接口可见
内容下架后普通接口不可见
隐藏测试用例不会通过普通接口返回
```

### Verify

```bash
./mvnw test
```

### Stop Conditions

```text
管理端字段需求未在契约文档中明确
内容发布流程需要审核状态但当前枚举不支持
```

---

## 16. Phase 12：工程收尾与联调

### Goal

把 Core 从功能可用整理到可维护、可联调、可交付。

### Implementation

```text
补充 README 本地启动说明
同步 application-example.yml
同步接口契约差异
补充数据库初始化说明
补充 RabbitMQ 消息样例
补充常见错误排查
检查日志敏感信息
清理无用代码和未使用配置
```

### Required Tests

```text
Result / ErrorCode / GlobalExceptionHandler
TraceIdFilter
AuthService
JWT filter
Article / Chapter / Problem query
Submission submit and query
JudgeResultConsumer idempotency
RateLimitService
TrackingService
Internal token auth
Admin permission
```

### Acceptance

```text
./mvnw test 通过
README 能指导新成员启动项目
接口文档与实际路径一致
MQ 命名与契约一致
数据库初始化后能跑通 MVP 主链路
日志不泄露密码、Token、完整用户代码
```

### Verify

```bash
./mvnw test
./mvnw spring-boot:run
```

完整手工链路：

```text
注册
登录
查询文章
查询章节
查询题目
提交代码
检查 MQ 判题任务
发送 Mock 判题结果
查询提交结果
```

---

## 17. 第一轮执行清单

下一次开始写代码时，先执行以下任务，不要跳到业务模块：

```text
1. 修改 pom.xml，切换 MyBatis-Plus 并补齐依赖
2. 建立推荐包结构
3. 实现 Result、PageResult、ErrorCode
4. 实现 BusinessException、GlobalExceptionHandler
5. 实现 TraceIdContext、TraceIdFilter
6. 实现 HealthController
7. 完善 application-example.yml
8. 运行 ./mvnw test
9. 启动服务并请求 /api/v1/health
```

第一轮验收通过后，再进入 Phase 2。

---

## 18. 交接规则

每完成一个阶段，最终回复必须包含：

```text
完成的阶段
主要改动
涉及文件
验证命令和结果
未完成事项
下一阶段建议
```

如果阶段未完成，必须说明：

```text
卡住原因
已经验证过的事实
不应该继续猜测的风险
需要用户或外部服务提供的信息
```
