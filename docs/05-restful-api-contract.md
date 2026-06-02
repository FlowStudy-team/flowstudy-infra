# 05-restful-api-contract.md

# FlowStudy RESTful API 接口契约

## 1. 文档目标

本文档定义 FlowStudy 前端、Core Service、AI Service 之间的 RESTful API 契约。

FlowStudy 采用前后端分离架构。前端通过 HTTP API 调用 `flowstudy-core`，AI 侧边栏通过 SSE 与 `flowstudy-ai` 通信。为了保证前端、Java 后端、Python AI 服务可以并行开发，所有接口必须先在本文档中完成定义，再进入编码阶段。

---

## 2. API 基本规范

### 2.1 统一 API 前缀

所有业务接口统一使用：

```text
/api/v1
```

例如：

```http
GET /api/v1/articles
POST /api/v1/auth/login
POST /api/v1/problems/{problemId}/submissions
```

### 2.2 数据格式

普通 HTTP 接口使用 JSON：

```http
Content-Type: application/json
Accept: application/json
```

AI 流式接口使用 SSE：

```http
Content-Type: text/event-stream
```

### 2.3 认证方式

除注册、登录、公开文章查询等接口外，其余接口统一使用 Bearer Token：

```http
Authorization: Bearer <access_token>
```

### 2.4 时间格式

接口中的时间字段统一使用 ISO 8601 字符串：

```text
2026-05-27T10:30:00+08:00
```

返回体中的 `timestamp` 使用毫秒级 Unix 时间戳：

```json
1710000000000
```

### 2.5 分页参数

分页查询统一使用：

```text
page: 当前页，从 1 开始
size: 每页数量，默认 10，最大 100
```

示例：

```http
GET /api/v1/articles?page=1&size=10
```

---

## 3. 认证与用户模块

### 3.1 用户注册

```http
POST /api/v1/auth/register
```

请求体：

```json
{
  "username": "wdd",
  "email": "wdd@example.com",
  "password": "12345678",
  "nickname": "Flow Learner"
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| username | string | 是 | 用户名，唯一 |
| email | string | 否 | 邮箱，唯一 |
| password | string | 是 | 明文密码，后端加密存储 |
| nickname | string | 否 | 用户昵称 |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "userId": 10001
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 3.2 用户登录

```http
POST /api/v1/auth/login
```

请求体：

```json
{
  "account": "wdd",
  "password": "12345678"
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| account | string | 是 | 用户名或邮箱 |
| password | string | 是 | 密码 |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "accessToken": "jwt-token",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "user": {
      "id": 10001,
      "username": "wdd",
      "nickname": "Flow Learner",
      "role": "USER"
    }
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 3.3 获取当前用户信息

```http
GET /api/v1/users/me
```

请求头：

```http
Authorization: Bearer <access_token>
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 10001,
    "username": "wdd",
    "email": "wdd@example.com",
    "nickname": "Flow Learner",
    "avatarUrl": null,
    "role": "USER"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 4. 文章模块

### 4.1 获取文章列表

```http
GET /api/v1/articles?page=1&size=10&keyword=java
```

Query 参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| page | int | 否 | 当前页，默认 1 |
| size | int | 否 | 每页数量，默认 10 |
| keyword | string | 否 | 搜索关键词 |
| status | string | 否 | 文章状态，默认只返回已发布文章 |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [
      {
        "id": 1,
        "title": "Java 并发编程基础",
        "summary": "从线程、锁、线程池到并发容器",
        "coverUrl": "",
        "authorName": "admin",
        "chapterCount": 8,
        "problemCount": 12,
        "viewCount": 1024,
        "createdAt": "2026-05-27T10:30:00+08:00"
      }
    ],
    "total": 1,
    "page": 1,
    "size": 10
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 4.2 获取文章详情

```http
GET /api/v1/articles/{articleId}
```

Path 参数：

| 参数 | 类型 | 说明 |
|---|---|---|
| articleId | long | 文章 ID |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "title": "Java 并发编程基础",
    "summary": "从线程、锁、线程池到并发容器",
    "coverUrl": "",
    "author": {
      "id": 1,
      "nickname": "admin"
    },
    "chapterCount": 8,
    "problemCount": 12,
    "viewCount": 1024,
    "status": "PUBLISHED",
    "createdAt": "2026-05-27T10:30:00+08:00",
    "updatedAt": "2026-05-27T10:30:00+08:00"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 5. 章节模块

### 5.1 获取文章下的章节列表

```http
GET /api/v1/articles/{articleId}/chapters
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 10,
      "articleId": 1,
      "title": "线程池的基本原理",
      "sortOrder": 1,
      "estimatedMinutes": 15,
      "problemCount": 2
    }
  ],
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 5.2 获取章节详情

```http
GET /api/v1/chapters/{chapterId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 10,
    "articleId": 1,
    "title": "线程池的基本原理",
    "contentMd": "## 线程池\n这里是 Markdown 内容...",
    "sortOrder": 1,
    "estimatedMinutes": 15,
    "problems": [
      {
        "id": 100,
        "title": "实现一个简单线程池",
        "difficulty": "MEDIUM"
      }
    ],
    "prevChapterId": null,
    "nextChapterId": 11
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 6. 题目模块

### 6.1 获取题目列表

```http
GET /api/v1/problems?chapterId=10&page=1&size=10
```

Query 参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| chapterId | long | 否 | 所属章节 ID |
| difficulty | string | 否 | EASY/MEDIUM/HARD |
| keyword | string | 否 | 关键词 |
| page | int | 否 | 当前页 |
| size | int | 否 | 每页数量 |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [
      {
        "id": 100,
        "chapterId": 10,
        "title": "两数之和",
        "difficulty": "EASY",
        "acceptedCount": 100,
        "submitCount": 180
      }
    ],
    "total": 1,
    "page": 1,
    "size": 10
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 6.2 获取题目详情

```http
GET /api/v1/problems/{problemId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 100,
    "chapterId": 10,
    "title": "两数之和",
    "descriptionMd": "给定一个整数数组 nums...",
    "difficulty": "EASY",
    "inputDescription": "第一行输入 n...",
    "outputDescription": "输出结果...",
    "sampleCases": [
      {
        "input": "4\n2 7 11 15\n9",
        "output": "0 1"
      }
    ],
    "supportLanguages": ["java", "cpp", "go", "python"],
    "timeLimitMs": 1000,
    "memoryLimitMb": 256
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 6.3 获取题目代码模板

```http
GET /api/v1/problems/{problemId}/template?language=java
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "problemId": 100,
    "language": "java",
    "code": "public class Main {\n    public static void main(String[] args) {\n        \n    }\n}"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 7. 代码提交模块

### 7.1 提交代码

```http
POST /api/v1/problems/{problemId}/submissions
```

请求头：

```http
Authorization: Bearer <access_token>
```

请求体：

```json
{
  "language": "java",
  "code": "public class Main { public static void main(String[] args) { } }"
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| language | string | 是 | java/cpp/go/python |
| code | string | 是 | 用户提交代码 |

返回：

```json
{
  "code": 0,
  "message": "submit success",
  "data": {
    "submitId": 90001,
    "status": "PENDING"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

处理逻辑：

```text
1. Core Service 校验登录态
2. Core Service 校验题目是否存在
3. Core Service 校验语言是否支持
4. Core Service 使用 Redis + Lua 进行限流
5. Core Service 写入 fs_submission，状态为 PENDING
6. Core Service 投递 judge.submit.created 消息到 RabbitMQ
7. 前端获得 submitId 后轮询查询判题结果
```

---

### 7.2 查询提交结果

```http
GET /api/v1/submissions/{submitId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "submitId": 90001,
    "problemId": 100,
    "problemTitle": "两数之和",
    "language": "java",
    "status": "ACCEPTED",
    "timeUsedMs": 12,
    "memoryUsedKb": 20480,
    "score": 100,
    "compileMessage": null,
    "runtimeMessage": null,
    "createdAt": "2026-05-27T10:30:00+08:00",
    "caseResults": [
      {
        "caseIndex": 1,
        "status": "ACCEPTED",
        "timeUsedMs": 4,
        "memoryUsedKb": 10240
      }
    ]
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 7.3 查询我的提交记录

```http
GET /api/v1/submissions/my?problemId=100&page=1&size=10
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [
      {
        "submitId": 90001,
        "problemId": 100,
        "problemTitle": "两数之和",
        "language": "java",
        "status": "ACCEPTED",
        "timeUsedMs": 12,
        "memoryUsedKb": 20480,
        "score": 100,
        "createdAt": "2026-05-27T10:30:00+08:00"
      }
    ],
    "total": 1,
    "page": 1,
    "size": 10
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 8. 学习行为埋点模块

### 8.1 上报行为事件

```http
POST /api/v1/tracking/events
```

请求头：

```http
Authorization: Bearer <access_token>
```

请求体：

```json
{
  "events": [
    {
      "eventType": "CHAPTER_VIEW",
      "articleId": 1,
      "chapterId": 10,
      "problemId": null,
      "submissionId": null,
      "durationSeconds": 35,
      "extra": {
        "scrollPercent": 80
      },
      "occurredAt": "2026-05-27T10:30:00+08:00"
    }
  ]
}
```

事件类型：

| 事件类型 | 说明 |
|---|---|
| ARTICLE_VIEW | 查看文章 |
| CHAPTER_VIEW | 查看章节 |
| CHAPTER_LEAVE | 离开章节 |
| CODE_EDIT | 编辑代码 |
| CODE_SUBMIT | 提交代码 |
| JUDGE_ERROR_VIEW | 查看判题错误 |
| AI_QUESTION | 向 AI 提问 |
| AI_ANSWER_VIEW | 查看 AI 回答 |
| NOTE_GENERATE | 生成学习笔记 |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "accepted": 1
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 9. AI 侧边栏接口

AI 服务独立部署，但生产环境建议由 Nginx 或 API Gateway 统一转发。

### 9.1 AI 流式问答

```http
POST /api/v1/ai/chat/stream
```

请求头：

```http
Authorization: Bearer <access_token>
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
  "question": "为什么我这里会数组越界？"
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| conversationId | long | 否 | 会话 ID，首次对话可为空 |
| articleId | long | 否 | 当前文章 ID |
| chapterId | long | 否 | 当前章节 ID |
| problemId | long | 否 | 当前题目 ID |
| submitId | long | 否 | 当前提交 ID |
| question | string | 是 | 用户问题 |

SSE 返回示例：

```text
event: delta
data: {"content":"你这里的问题是..."}

event: delta
data: {"content":"数组下标从 0 开始..."}

event: done
data: {"conversationId":30001}
```

异常返回示例：

```text
event: error
data: {"code":54000,"message":"AI service unavailable"}
```

---

### 9.2 获取 AI 会话列表

```http
GET /api/v1/ai/conversations?page=1&size=10
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [
      {
        "conversationId": 30001,
        "title": "数组越界问题分析",
        "articleId": 1,
        "chapterId": 10,
        "problemId": 100,
        "createdAt": "2026-05-27T10:30:00+08:00"
      }
    ],
    "total": 1,
    "page": 1,
    "size": 10
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 9.3 获取 AI 会话消息

```http
GET /api/v1/ai/conversations/{conversationId}/messages
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 1,
      "role": "user",
      "content": "为什么我这里会数组越界？",
      "createdAt": "2026-05-27T10:30:00+08:00"
    },
    {
      "id": 2,
      "role": "assistant",
      "content": "你这里的问题是循环边界多写了一位...",
      "createdAt": "2026-05-27T10:30:05+08:00"
    }
  ],
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 10. 学习笔记接口

### 10.1 生成个性化学习笔记

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

---

### 10.2 获取我的学习笔记列表

```http
GET /api/v1/notes/my?page=1&size=10
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [
      {
        "id": 50001,
        "title": "线程池章节个人学习总结",
        "articleId": 1,
        "chapterId": 10,
        "source": "AI",
        "status": "GENERATED",
        "createdAt": "2026-05-27T10:30:00+08:00"
      }
    ],
    "total": 1,
    "page": 1,
    "size": 10
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 10.3 获取学习笔记详情

```http
GET /api/v1/notes/{noteId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 50001,
    "title": "线程池章节个人学习总结",
    "contentMd": "## 本章学习总结\n你在本章主要掌握了...",
    "articleId": 1,
    "chapterId": 10,
    "source": "AI",
    "status": "GENERATED",
    "createdAt": "2026-05-27T10:30:00+08:00"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 11. 内部服务接口

内部接口不对前端开放，只允许服务间调用。内部接口必须使用内部 Token。

请求头：

```http
X-Internal-Token: <internal_api_token>
```

### 11.1 AI 服务获取上下文

```http
GET /api/v1/internal/context?userId=10001&articleId=1&chapterId=10&problemId=100&submitId=90001
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "article": {
      "id": 1,
      "title": "Java 并发编程基础"
    },
    "chapter": {
      "id": 10,
      "title": "线程池的基本原理",
      "contentMd": "## 线程池\n..."
    },
    "problem": {
      "id": 100,
      "title": "两数之和",
      "descriptionMd": "给定一个整数数组..."
    },
    "submission": {
      "id": 90001,
      "language": "java",
      "code": "public class Main {}",
      "status": "RUNTIME_ERROR",
      "runtimeMessage": "ArrayIndexOutOfBoundsException"
    }
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 12. 管理端接口预留

以下接口属于管理后台接口，V1 可以暂不实现，但路径提前预留：

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

管理接口必须要求：

```text
role = ADMIN
```

---

## 13. 前端轮询建议

代码提交后，前端推荐轮询：

```http
GET /api/v1/submissions/{submitId}
```

轮询策略：

```text
首次提交后 500ms 查询一次
之后每 1000ms 查询一次
超过 30s 停止轮询并提示用户稍后刷新
当状态进入终态后停止轮询
```

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

---

## 14. 本文档维护规则

当接口路径、请求字段、响应字段、错误码、认证方式发生变化时，必须同步更新本文档和 Apifox / YApi / ApiPost 中的接口文档。

接口变更必须遵循：

```text
先更新契约
再修改后端
最后修改前端
```
