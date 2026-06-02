# 11. AI Agent Service 设计文档

## 1. 文档目的

本文档定义 `flowstudy-ai` 的职责边界、接口形态、上下文获取、AI 记忆、Agent 工作流、RabbitMQ 消费与工程规范。

`flowstudy-ai` 是 FlowStudy 的 AI 分析与网关模块，负责侧边栏智能问答、上下文感知、用户行为分析、学习画像更新和个性化笔记生成。它不负责用户登录、文章题目管理、代码提交调度和判题执行，这些分别由 `flowstudy-core` 与 `flowstudy-judge` 负责。

## 2. 服务职责

`flowstudy-ai` 负责：

```text
1. 提供 AI 侧边栏 SSE 流式问答
2. 根据 articleId / chapterId / problemId / submitId 获取学习上下文
3. 将章节内容、题目描述、用户代码、判题错误拼接到 Prompt
4. 消费用户行为事件，提炼易错点和代码风格
5. 自动生成个性化 Markdown 学习笔记
6. 维护用户画像、学习记忆和 AI 会话记录
```

`flowstudy-ai` 不负责：

```text
1. 用户注册登录和主鉴权
2. 文章、章节、题目、测试用例 CRUD
3. 用户代码编译运行
4. 判题沙箱隔离
5. Core 主业务数据直接写入
```

## 3. 推荐技术栈

```text
语言：Python 3.11+
Web 框架：FastAPI
异步请求：httpx / aiohttp
LLM 编排：LangGraph / LangChain 可选
消息队列：RabbitMQ
向量检索：FAISS / Chroma / Milvus 可选
配置管理：pydantic-settings
测试：pytest
```

MVP 阶段建议先使用：

```text
FastAPI + httpx + LLM Client + Prompt Builder
```

不要一开始就引入过重的 Agent 框架。

## 4. 推荐目录结构

```text
flowstudy-ai/
├── app/
│   ├── main.py
│   ├── api/
│   │   ├── chat.py
│   │   ├── notes.py
│   │   └── health.py
│   ├── config/
│   │   └── settings.py
│   ├── core_client/
│   │   └── core_context_client.py
│   ├── context/
│   │   ├── context_builder.py
│   │   └── context_schema.py
│   ├── llm/
│   │   ├── llm_client.py
│   │   └── model_router.py
│   ├── memory/
│   │   ├── short_term_memory.py
│   │   ├── user_profile_memory.py
│   │   └── memory_updater.py
│   ├── retrieval/
│   │   ├── article_retriever.py
│   │   └── user_memory_retriever.py
│   ├── mq/
│   │   ├── consumer.py
│   │   ├── producer.py
│   │   └── messages.py
│   ├── prompts/
│   │   ├── chapter_qa.md
│   │   ├── error_explain.md
│   │   ├── note_generate.md
│   │   └── profile_update.md
│   ├── workflows/
│   │   ├── chat_workflow.py
│   │   ├── note_workflow.py
│   │   └── profile_workflow.py
│   └── schemas/
├── tests/
├── .env.example
├── pyproject.toml
└── README.md
```

## 5. 核心接口

### 5.1 健康检查

```http
GET /api/v1/ai/health
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "service": "flowstudy-ai",
    "status": "UP"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 5.2 AI 流式问答

```http
POST /api/v1/ai/chat/stream
Content-Type: application/json
Accept: text/event-stream
```

请求体：

```json
{
  "conversationId": null,
  "articleId": 1,
  "chapterId": 10,
  "problemId": 100,
  "submitId": 90001,
  "question": "为什么我的代码会数组越界？"
}
```

SSE 响应：

```text
event: delta
data: {"content":"你的代码出现数组越界，主要原因是..."}

event: done
data: {"conversationId":30001}
```

错误响应：

```text
event: error
data: {"code":54000,"message":"AI service unavailable","traceId":"9f2c1a7e"}
```

说明：SSE 接口不使用 `Result<T>` 包裹，但 error event 的 `code`、`message`、`traceId` 必须符合统一错误码规范。

### 5.3 提交笔记生成任务

```http
POST /api/v1/ai/notes/generate
```

请求体：

```json
{
  "articleId": 1,
  "chapterId": 10
}
```

返回：

```json
{
  "code": 0,
  "message": "note generation task submitted",
  "data": {
    "taskId": "note-task-001",
    "status": "PENDING"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

## 6. 上下文获取设计

AI 不直接访问 Core 数据库，而是调用 Core 的 internal API。

```http
GET /api/v1/internal/ai/context?userId=10001&chapterId=10&problemId=100&submitId=90001
X-Internal-Token: ${INTERNAL_API_TOKEN}
X-Trace-Id: 9f2c1a7e
```

上下文建议包含：

```text
1. 用户基础信息
2. 当前文章标题
3. 当前章节 Markdown
4. 当前题目描述
5. 用户最近提交代码
6. 判题状态与报错信息
7. 当前会话最近 N 轮消息
8. 用户画像摘要
```

## 7. AI 记忆分层

```text
L0 当前请求上下文：当前问题、章节、题目、代码、报错
L1 会话短期记忆：当前 conversation 最近 5~10 轮对话
L2 用户长期画像摘要：易错点、代码风格、学习偏好
L3 详细长期记忆：历史错误样例、历史问答摘要、笔记
L4 课程知识库：文章、题目、题解、契约文档
```

默认加载：

```text
L0 + L1 + L2 摘要
```

必要时检索：

```text
L3 + L4
```

不要把所有历史行为和对话一次性塞进 Prompt。

## 8. Prompt 设计原则

Prompt 应包含：

```text
1. AI 角色：FlowStudy 学习助手
2. 当前学习上下文
3. 用户当前问题
4. 用户代码与报错信息
5. 用户画像摘要
6. 回答格式要求
7. 安全边界
```

回答要求：

```text
1. 优先解释原因，再给修改建议
2. 不直接给完整答案，除非用户明确要求
3. 对 OJ 题目优先给提示、边界条件和思路
4. 对报错指出可能代码位置
5. 尽量结合当前章节内容
```

## 9. RabbitMQ 消费设计

### 9.1 行为事件

```text
Exchange: fs.behavior.exchange
Queue: fs.ai.behavior.queue
RoutingKey: behavior.#
```

用途：

```text
1. 读取章节停留时间
2. 读取代码提交频率
3. 读取 AI 提问内容
4. 读取错误查看行为
5. 异步更新学习画像
```

### 9.2 笔记生成任务

```text
Exchange: fs.ai.exchange
Queue: fs.ai.note.queue
RoutingKey: ai.note.generate
```

用途：

```text
1. 获取用户学习上下文
2. 调用 LLM 生成 Markdown 笔记
3. 回写结果或发送完成消息
```

## 10. 错误码建议

| 错误码 | 场景 |
|---:|---|
| `54000` | AI 服务内部异常 |
| `54001` | LLM 调用失败 |
| `54002` | 上下文获取失败 |
| `54003` | Prompt 构建失败 |
| `54004` | 笔记生成失败 |
| `54005` | 向量检索失败 |

新增错误码必须同步更新 `06-result-error-code-contract.md`。

## 11. MVP 实现顺序

```text
阶段 1：FastAPI 项目骨架、配置、健康检查
阶段 2：chat/stream SSE 接口，先接简单 LLM
阶段 3：调用 Core internal API 获取上下文
阶段 4：Prompt Builder + LLM Client
阶段 5：保存 AI 会话与消息
阶段 6：消费 behavior.* 消息，生成简单画像
阶段 7：实现 notes/generate 笔记生成
阶段 8：接入向量检索和 Agent Workflow
```

## 12. 验收标准

```text
1. AI 服务可以独立启动
2. /health 接口正常
3. 前端可通过 SSE 接收流式回答
4. AI 回答能结合章节、题目、代码和报错
5. 普通 HTTP 接口遵守 Result<T>
6. SSE 错误事件遵守统一错误码
7. 行为消息可以被消费
8. AI 不直接访问 Core 数据库
9. LLM API Key 只从环境变量读取
```
