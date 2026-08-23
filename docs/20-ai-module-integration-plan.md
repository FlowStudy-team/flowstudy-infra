# 20. AI 模块接入计划

## 1. 背景与目标

FlowStudy 的 AI 模块目标不是做一个孤立聊天框，而是围绕用户当前学习场景提供上下文感知能力，包括文章/教程问答、题目错误解释、代码修改建议、学习行为分析和个性化笔记生成。

当前 `flowstudy-ai` 已有 FastAPI、健康检查、SSE 聊天接口、Prompt 构造和 DeepSeek/OpenAI-compatible 流式调用基础。后续接入应分阶段推进，先完成上下文问答闭环，再做 RAG、行为分析和 Agent 工作流。

参考同类 Agent 系统的实现经验，AI 模块应重点吸收以下设计：

```text
1. Agent Core 不依赖 Web UI
2. SSE 事件流用于展示长任务过程
3. Context Engine 负责构造有限、可解释、可预算的上下文
4. Tool System 使用结构化工具，不让模型自由拼接危险请求
5. Trace 记录模型调用、工具调用、上下文摘要和错误
6. Evaluation 用可重复任务衡量 AI 能力，而不是只看主观效果
7. 权限边界先于 Agent 能力，避免 AI 直接访问过多业务数据
```

## 2. 服务边界

推荐服务形态：

```text
flowstudy-core
  用户鉴权、业务数据、AI 上下文内部接口、行为事件入库和投递

flowstudy-ai
  AI SSE 问答、上下文构造、RAG 检索、学习画像分析、笔记生成

flowstudy-frontend
  AI 侧边栏、SSE 消息展示、上下文入口、笔记结果展示

RabbitMQ
  行为事件、笔记生成任务、画像更新任务
```

关键原则：

```text
1. AI 不直接连接 Core 的业务数据库，优先通过 Core internal API 获取可信上下文
2. AI 不负责用户登录注册和业务权限判断
3. Core 负责鉴权、用户身份、资源归属和上下文裁剪
4. AI 的失败不能阻塞文章阅读、题目提交和判题主链路
```

## 3. 阶段路线

### Phase 1：上下文感知 AI 侧边栏

目标：

```text
1. 前端在文章、博客、教程、题目页面打开 AI 侧边栏
2. AI 通过 SSE 流式返回回答
3. Core 提供 internal context API
4. AI 回答能感知当前教程/博客/题目/最近提交错误
5. AI 对话记录可落库
```

这是最先应该实现的 AI 能力，效果最直观，也最容易与现有业务对齐。

### Phase 2：RAG 检索增强

目标：

```text
1. 将博客、教程、题解、题目描述切分成知识片段
2. 建立 embedding 索引
3. AI 根据当前问题检索相关内容
4. Prompt 中只注入 topK 片段和引用来源
5. 前端展示“回答参考了哪些内容”
```

MVP 可以先用 MySQL 存储分块和关键词检索，后续再接向量数据库或向量扩展。

### Phase 3：学习行为分析

目标：

```text
1. Core 采集阅读、提交、运行、错误、AI 提问等行为事件
2. 事件写入 MySQL，并异步投递 RabbitMQ
3. AI 消费行为事件，提取学习偏好、薄弱点和错误模式
4. 更新用户学习画像摘要
```

行为事件必须异步化，不能影响用户主流程。

### Phase 4：个性化笔记生成

目标：

```text
1. 用户完成一个教程或阶段学习后触发笔记生成
2. AI 汇总阅读内容、错题、提交代码和问答记录
3. 生成 Markdown 学习笔记
4. Core 保存笔记并在前端展示
```

笔记生成属于后台长任务，应使用 RabbitMQ，不应阻塞 HTTP 请求。

### Phase 5：Agent 工作流

目标：

```text
1. 引入 LangGraph 或轻量自研 workflow
2. 将“理解问题 -> 获取上下文 -> 检索知识 -> 调用业务工具 -> 生成回答 -> 安全检查”拆成节点
3. 对每个节点记录 trace
4. 支持失败降级和局部重试
```

该阶段再参考成熟 Agent 系统的 Agent Loop、Tool System、Trace 和 Eval，不建议一开始就引入复杂多 Agent。

## 4. Core Internal API 设计

AI 获取上下文必须通过 Core 提供的内部接口。

### 4.1 获取学习上下文

```http
GET /api/v1/internal/ai/context?scene=PROBLEM&problemId=100&submissionId=90001
X-Internal-Token: ${INTERNAL_API_TOKEN}
X-Trace-Id: ${traceId}
```

返回建议：

```json
{
  "user": {
    "id": 10001,
    "nickname": "zhangsan"
  },
  "scene": "PROBLEM",
  "tutorial": {
    "id": 1,
    "title": "数组基础"
  },
  "blog": {
    "id": 10,
    "title": "两数之和",
    "markdown": "..."
  },
  "problem": {
    "id": 100,
    "title": "Two Sum",
    "description": "...",
    "difficulty": "EASY"
  },
  "latestSubmission": {
    "id": 90001,
    "language": "java",
    "code": "...",
    "status": "WRONG_ANSWER",
    "failedCaseInput": "4\n2 7 11 15\n9\n",
    "expectedOutput": "0 1\n",
    "actualOutput": "1 2\n",
    "runtimeMessage": null,
    "compileMessage": null
  },
  "profileSummary": {
    "weaknesses": ["数组边界", "哈希表使用"],
    "recentMistakes": ["返回值顺序错误"]
  }
}
```

Core 必须做：

```text
1. 验证 internal token
2. 验证 userId 与资源归属
3. 裁剪 Markdown 和代码长度
4. 过滤敏感字段
5. 传递 traceId
```

## 5. AI Chat API 设计

前端调用 AI 服务：

```http
POST /ai/api/v1/ai/chat
Accept: text/event-stream
Content-Type: application/json
Authorization: Bearer ${jwt}
```

请求体：

```json
{
  "conversationId": null,
  "scene": "PROBLEM",
  "message": "为什么我的代码没有通过？",
  "contextRef": {
    "tutorialId": 1,
    "blogId": 10,
    "problemId": 100,
    "submissionId": 90001
  },
  "history": [
    {
      "role": "user",
      "content": "这道题应该怎么想？"
    }
  ]
}
```

SSE 事件建议：

```text
event: meta
data: {"conversationId":30001,"traceId":"abc","model":"deepseek-chat"}

event: context
data: {"summary":"已读取题目、最近一次错误提交和教程片段"}

event: delta
data: {"content":"你的代码没有通过，主要原因是..."}

event: done
data: {"conversationId":30001}

event: error
data: {"code":"AI_SERVICE_UNAVAILABLE","message":"AI 服务暂时不可用","traceId":"abc"}
```

前端至少要处理：

```text
meta
context
delta
done
error
```

## 6. Context Engine 设计

参考成熟 Context Engine 的设计，FlowStudy AI 不应把所有内容无脑塞进 Prompt，而要构造可解释的上下文包。

上下文分层：

```text
L0 当前问题：用户本轮提问
L1 当前页面：教程/博客/题目/提交错误
L2 短期对话：当前 conversation 最近 5~10 轮
L3 用户画像摘要：最近薄弱点、错误模式、学习偏好
L4 知识检索：相关文章片段、题解片段、官方内容
```

默认注入：

```text
L0 + L1 + L2 摘要 + L3 摘要
```

按需检索：

```text
L4 topK
```

必须记录：

```text
1. context token 估算
2. 被截断的字段
3. 检索到的片段 ID
4. 本轮使用的模型
```

## 7. Tool System 设计

AI 需要调用业务数据时，不应让模型自由生成 HTTP 请求。应定义结构化工具，由 AI 服务内部执行。

第一批工具：

```text
get_current_learning_context
get_problem_detail
get_latest_submission
search_learning_content
create_learning_note_task
```

工具调用要求：

```text
1. 每个工具有明确入参 schema
2. 工具执行前检查权限和场景
3. 工具结果做长度裁剪
4. 工具调用写入 trace
5. 不允许工具返回密钥、密码、JWT、数据库连接串
```

## 8. RAG 数据设计

MVP 表结构建议：

```text
fs_ai_knowledge_chunk
  id
  source_type       BLOG / TUTORIAL / PROBLEM / SOLUTION
  source_id
  title
  chunk_index
  content
  token_count
  embedding         可选，MVP 可先不做
  created_at
  updated_at

fs_ai_conversation
  id
  user_id
  scene
  title
  created_at
  updated_at

fs_ai_message
  id
  conversation_id
  role              USER / ASSISTANT / SYSTEM / TOOL
  content
  trace_id
  created_at

fs_learning_behavior_event
  id
  user_id
  event_type
  resource_type
  resource_id
  payload_json
  trace_id
  created_at

fs_learning_note
  id
  user_id
  tutorial_id
  title
  markdown
  source_event_range
  status
  created_at
  updated_at
```

如果暂时不接向量库，可以先用：

```text
MySQL FULLTEXT / LIKE / 简单关键词匹配
```

后续再替换为：

```text
Milvus / Qdrant / Chroma / pgvector / Elasticsearch
```

## 9. RabbitMQ 事件设计

建议新增 AI 相关事件，不和判题队列混用。

```text
Exchange: fs.ai.exchange

Queue: fs.ai.behavior.queue
RoutingKey: ai.behavior.created

Queue: fs.ai.note.queue
RoutingKey: ai.note.generate.requested

Queue: fs.ai.profile.queue
RoutingKey: ai.profile.update.requested
```

通用消息字段：

```json
{
  "schemaVersion": "1.0",
  "messageId": "uuid",
  "traceId": "trace-id",
  "eventType": "ai.behavior.created",
  "occurredAt": "2026-08-09T12:00:00Z",
  "userId": 10001,
  "payload": {}
}
```

可靠性要求：

```text
1. messageId 保证幂等
2. 消费失败进入 DLQ 或记录失败任务表
3. AI 任务失败不影响 Core 主业务
4. 行为事件允许延迟处理，但不应无限堆积
```

## 10. Agent 工作流设计

参考成熟 Agent 系统，不建议一开始做复杂多 Agent。先做单 Agent workflow：

```text
Start
  -> classify_intent
  -> build_context
  -> retrieve_knowledge
  -> maybe_call_tool
  -> generate_answer
  -> safety_check
  -> stream_response
  -> persist_trace
End
```

意图分类：

```text
CONTENT_QA          文章/教程问答
PROBLEM_HINT        题目提示
ERROR_EXPLAIN       判题错误解释
CODE_REVIEW         用户代码点评
NOTE_GENERATION     笔记生成
GENERAL_CHAT        普通学习问答
```

安全策略：

```text
1. 不直接给出隐藏测试用例
2. 不泄露系统 Prompt、内部 token、数据库字段
3. 对作业/考试类问题优先给思路和引导
4. 模型异常时返回可读降级提示
```

## 11. Trace 与 Eval

参考成熟 Trace/Evaluation 思路，AI 模块从早期就要记录可复盘信息。

Trace 建议字段：

```text
traceId
conversationId
userId
scene
model
contextSummary
retrievedChunkIds
toolCalls
latencyMs
errorCode
createdAt
```

Eval 第一批任务：

```text
1. 给定题目和 WA 提交，AI 能指出错误原因
2. 给定文章片段，AI 能回答概念问题
3. 给定用户连续错误记录，AI 能生成学习建议
4. 模型不可用时，接口返回可控错误事件
```

验收指标：

```text
SSE 首 token 时间
回答完成耗时
上下文引用准确率
错误解释命中率
失败降级是否可读
```

## 12. 部署接入

`flowstudy-ai` 纳入生产 compose 时建议：

```text
container_name: flowstudy-ai
internal port: 8000
public exposure: none
nginx route: /ai/ -> http://ai:8000/
```

环境变量：

```text
AI_MODEL_PROVIDER=deepseek
DEEPSEEK_API_KEY=不提交Git
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat
CORE_INTERNAL_BASE_URL=http://server:8080
INTERNAL_API_TOKEN=不提交Git
RABBITMQ_HOST=rabbitmq
MYSQL_HOST=mysql
```

注意：

```text
1. AI API key 只能放 GitHub Secrets 或 ECS .env
2. AI 服务不可用时，Nginx/Core/Frontend 不应影响非 AI 功能
3. 生产部署前必须设置超时、重试和错误脱敏
```

## 13. 推荐实施顺序

```text
1. 整理 flowstudy-ai 现有 FastAPI SSE 接口，固定 SSE 事件格式
2. Core 新增 internal AI context API
3. Frontend AI 侧边栏接入真实 SSE 和上下文参数
4. AI 保存 conversation/message
5. Core 采集行为事件并投递 RabbitMQ
6. AI 消费行为事件并更新 profile summary
7. 接入 RAG chunk 表和检索
8. 引入 LangGraph 或自研 workflow
9. 增加 Trace 和 Eval
10. 纳入 Docker Compose 和 GitHub Actions 部署
```

## 14. 风险与边界

主要风险：

```text
1. 过早引入复杂 Agent，会拖慢主链路上线
2. AI 直接访问数据库会绕过 Core 权限边界
3. 无上下文预算会导致 Prompt 过长、成本不可控
4. 缺少 trace 后，AI 回答错误难以复盘
5. 外部模型不可用会影响用户体验
```

建议：

```text
1. V2 先做上下文问答，不做完整画像和自动笔记
2. 所有 AI 能力都要有降级提示
3. 先做确定性的 Context Engine 和 Tool System，再做复杂 Agent
4. 学习行为和笔记生成必须异步化
```
### AI 笔记任务执行器落地说明

AI 服务当前支持两种执行模式：`local` 用于本地联调，使用 SQLite 保存任务状态；`rabbitmq` 用于部署环境，使用 durable queue `fs.ai.note.queue`，routing key 为队列名，消息事件为 `ai.note.generate.requested`。消息包含 `schemaVersion`、`eventType`、`taskId`、`context` 和用户 Bearer Token。Token 仅用于 AI worker 将生成结果回写当前用户的 Core 学习笔记接口，不应输出到日志。

RabbitMQ 模式要求 `RABBITMQ_URL`、`AI_NOTE_QUEUE`、`AI_TASK_DB_PATH` 配置，并将 SQLite 文件放到持久化卷；消费者失败会重新入队，任务状态会记录为 `FAILED`，生产环境仍应配合 RabbitMQ DLQ 和监控。
