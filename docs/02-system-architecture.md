# 02. FlowStudy 系统架构设计

## 1. 架构目标

FlowStudy 采用多服务协作架构，目标是在保证业务边界清晰的同时，让前端、Java Core Service、Go Judge Service 和 Python AI Agent Service 能够并行开发。系统通过 HTTP 完成前端与后端的同步交互，通过 RabbitMQ 完成判题、行为事件和 AI 异步任务的解耦，通过 MySQL 持久化核心数据，通过 Redis 完成限流和缓存。

该架构的核心思想是：用户直接交互的请求由 Core Service 统一承接；耗时且危险的代码运行任务交给 Judge Service；需要大模型能力的上下文问答和学习画像交给 AI Service；中间件统一由 Docker Compose 管理，避免每个开发者本地环境不一致。

## 2. 总体架构图

```text
                         ┌────────────────────────┐
                         │   flowstudy-frontend    │
                         │  文章阅读 / 代码编辑 / AI │
                         └───────────┬────────────┘
                                     │ HTTP / SSE
                                     ▼
                         ┌────────────────────────┐
                         │    flowstudy-core       │
                         │ Java Spring Boot 业务中心 │
                         └──────┬────────┬────────┘
                                │        │
                    MySQL / Redis        │ RabbitMQ
                                │        ▼
                    ┌───────────▼───────────────┐
                    │        Infrastructure       │
                    │ MySQL / Redis / RabbitMQ    │
                    └──────┬──────────────┬──────┘
                           │              │
                           ▼              ▼
              ┌────────────────────┐  ┌────────────────────┐
              │  flowstudy-judge    │  │   flowstudy-ai      │
              │ Go 判题与沙箱执行服务 │  │ Python AI Agent 服务 │
              └────────────────────┘  └────────────────────┘
```

## 3. 服务职责边界

### 3.1 Frontend

Frontend 只负责用户界面和交互逻辑，不直接连接数据库、Redis 或 RabbitMQ。它通过 HTTP 调用 Core Service 获取文章、章节、题目和提交结果，通过 SSE 调用 AI Chat 接口获得流式回答。前端需要负责代码编辑器、Markdown 渲染、判题状态展示和学习行为埋点上报。

### 3.2 Core Service

Core Service 是系统的业务中心和调度中心。它负责用户鉴权、内容分发、题目查询、提交记录、限流、MQ 投递、判题结果消费和行为事件接收。Core Service 不直接执行用户代码，也不直接完成复杂 AI 推理。

Core Service 与 MySQL、Redis、RabbitMQ 直接交互。它向 RabbitMQ 投递判题任务，消费 Judge Service 回传的判题结果，也可以投递用户行为事件给 AI Service 分析。

### 3.3 Judge Service

Judge Service 是后台 Worker，不直接暴露给公网前端。它从 RabbitMQ 消费判题任务，创建隔离运行环境，编译和运行用户代码，对比测试用例，然后将结果发送回 RabbitMQ。Core Service 消费判题结果后更新数据库。

Judge Service 需要重点保证安全隔离、资源限制、超时控制和结果可靠回传。MVP 阶段可以先使用 Docker 容器沙箱，后续再逐步增强隔离能力。

### 3.4 AI Agent Service

AI Agent Service 负责所有 AI 能力，包括侧边栏问答、上下文构造、SSE 流式输出、用户行为分析、用户画像更新和个性化笔记生成。它可以通过内部 HTTP API 从 Core Service 获取文章、章节、题目、提交记录等上下文，也可以通过 RabbitMQ 消费行为事件。

AI Service 不应该直接依赖前端传来的完整上下文，因为前端数据可能不完整或不可信。更合理的方式是前端传递 articleId、chapterId、problemId、submitId 等标识，由 AI Service 或 Core Service 组装上下文。

## 4. 同步调用链路

同步调用主要发生在前端与 Core Service、前端与 AI Service 之间。

用户浏览文章时，调用链路为：Frontend 请求文章列表接口，Core Service 查询 MySQL，返回统一 Result 数据结构。用户查看章节时，Frontend 请求章节详情接口，Core Service 查询章节内容和关联题目并返回。

用户提交代码时，Frontend 调用 Core Service 的提交接口。Core Service 校验登录态、校验题目存在、进行 Redis 限流、写入 fs_submission 表，然后投递判题任务到 RabbitMQ，并立即返回 submitId 和 PENDING 状态。前端可以通过轮询提交结果接口获取状态更新。

AI 问答时，Frontend 调用 AI Chat Stream 接口。AI Service 根据请求中的上下文 ID 获取业务上下文，调用大模型并通过 SSE 持续返回 token 片段。

## 5. 异步消息链路

FlowStudy 的异步链路主要包括三类：判题任务链路、判题结果链路、用户行为分析链路。

### 5.1 判题任务链路

```text
Frontend 提交代码
    ↓
Core Service 写入 fs_submission
    ↓
Core Service 发送 judge.submit.created 消息
    ↓
RabbitMQ: fs.judge.submit.queue
    ↓
Judge Service 消费任务并执行代码
```

### 5.2 判题结果链路

```text
Judge Service 生成判题结果
    ↓
Judge Service 发送 judge.result.finished 消息
    ↓
RabbitMQ: fs.core.judge-result.queue
    ↓
Core Service 消费结果
    ↓
更新 fs_submission 和 fs_judge_case_result
    ↓
Frontend 查询并展示结果
```

### 5.3 用户行为分析链路

```text
Frontend 上报学习行为
    ↓
Core Service 接收并落库
    ↓
Core Service 发送 behavior.* 消息
    ↓
AI Service 消费行为事件
    ↓
清洗数据并更新用户画像
```

## 6. 数据流设计

FlowStudy 的核心数据包括用户数据、文章数据、章节数据、题目数据、测试用例数据、代码提交数据、判题结果数据、行为事件数据、AI 对话数据、用户画像数据和学习笔记数据。

用户、文章、章节、题目、提交记录等强一致业务数据存储在 MySQL 中。Redis 主要用于接口限流、热点缓存和临时状态。RabbitMQ 用于跨服务异步通信。AI 相关向量数据后续可以接入本地向量库、pgvector、Milvus 或其他向量数据库，但 MVP 阶段可以先不引入复杂向量基础设施。

## 7. 部署架构

本地开发阶段建议使用 Docker Compose 启动 MySQL、Redis 和 RabbitMQ，四个业务服务可以分别在本机以开发模式运行。这样可以方便调试，也能保证中间件环境统一。

生产阶段建议使用 Nginx 作为统一入口。Frontend 由 Nginx 托管静态资源，`/api/v1/**` 转发到 Core Service，`/api/v1/ai/**` 转发到 AI Service。Judge Service 不暴露公网，只与 RabbitMQ 通信。

```text
https://flowstudy.com/              -> Frontend
https://flowstudy.com/api/v1/**     -> Core Service
https://flowstudy.com/api/v1/ai/**  -> AI Service
RabbitMQ                            -> Core / Judge / AI 内部通信
Judge Service                       -> 不暴露公网
```

## 8. 架构中的关键约束

第一，Judge Service 不允许直接暴露公网。用户代码运行是高风险操作，只能通过消息队列触发。第二，LLM API Key 不允许写死在代码中，必须通过环境变量读取。第三，前端不直接连接数据库或消息队列。第四，所有跨服务消息必须携带 messageId 和 traceId，方便幂等处理和链路排查。第五，所有普通 HTTP 接口应统一返回 Result<T>，AI SSE 接口除外。

## 9. MVP 架构裁剪

MVP 阶段可以适当简化架构。AI Service 可以先只保留健康检查接口和基础聊天接口，不做画像和笔记。Judge Service 可以先支持一种语言，例如 Java 或 Python，再扩展 C++、Go。测试用例可以先直接存储在 MySQL 中并随 MQ 消息发送，后续再改为对象存储或专门测试用例服务。

MVP 不建议过早引入 Kubernetes、服务注册中心、分布式配置中心、复杂监控系统和大型向量数据库。这些能力可以在主链路稳定后再逐步补充。

## 10. 架构演进方向

后续架构可以从几个方向演进：判题服务支持多 Worker 水平扩展；RabbitMQ 增加死信队列和重试机制；AI Service 增加 RAG 和 Agent 工作流；Core Service 增加后台管理系统；用户画像从 JSON 存储演进到更细粒度的标签表；部署方式从 Docker Compose 演进到 Kubernetes；日志和链路追踪接入 Prometheus、Grafana 和 OpenTelemetry。
