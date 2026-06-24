# 05. FlowStudy RESTful API 接口契约

## 1. 文档目标

本文档定义 `flowstudy-frontend` 调用 `flowstudy-core` 的 HTTP API 契约。当前阶段暂不开发 AI 模块，因此本文档只覆盖 V1 主链路：

```text
注册登录
-> 浏览教程 / 博客
-> 查看题目
-> 运行代码
-> 提交代码
-> 查询运行 / 判题结果
```

接口变更原则：

```text
先更新契约
再修改后端
最后修改前端
```

## 2. API 基本规范

统一前缀：

```text
/api/v1
```

普通接口使用 JSON：

```http
Content-Type: application/json
Accept: application/json
```

除注册、登录、公开教程/博客/题目查询外，其余接口使用 Bearer Token：

```http
Authorization: Bearer <access_token>
```

分页参数统一为：

| 参数 | 类型 | 说明 |
|---|---|---|
| `page` | int | 当前页，从 1 开始，默认 1 |
| `size` | int | 每页数量，默认 10，最大 100 |

统一响应结构：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

## 3. 认证与用户

### 3.1 注册

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

### 3.2 登录

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

### 3.3 当前用户

```http
GET /api/v1/users/me
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

## 4. 教程与博客

当前内容模型已经从旧的 `article/chapter` 调整为 `tutorial/blog`：

```text
tutorial：教程，一组系统化学习内容的集合
blog：博客，具体内容单元；可以属于某个 tutorial，也可以独立存在
```

### 4.1 教程列表

```http
GET /api/v1/tutorials?page=1&size=10&keyword=java&source=official&sort=latest
```

Query 参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `page` | int | 否 | 当前页 |
| `size` | int | 否 | 每页数量 |
| `keyword` | string | 否 | 搜索关键词 |
| `source` | string | 否 | `official` / `user`，MVP 可选 |
| `sort` | string | 否 | `latest` / `hot` / `default` |

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [
      {
        "id": 1,
        "title": "Java 并发编程入门",
        "summary": "从线程、线程池到并发任务调度",
        "coverUrl": null,
        "author": {
          "id": 1,
          "nickname": "admin"
        },
        "blogCount": 8,
        "problemCount": 12,
        "viewCount": 1024,
        "likeCount": 32,
        "createdAt": "2026-06-23T10:30:00+08:00"
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

### 4.2 教程详情

```http
GET /api/v1/tutorials/{tutorialId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "title": "Java 并发编程入门",
    "summary": "从线程、线程池到并发任务调度",
    "coverUrl": null,
    "author": {
      "id": 1,
      "nickname": "admin"
    },
    "blogCount": 8,
    "problemCount": 12,
    "viewCount": 1024,
    "likeCount": 32,
    "createdAt": "2026-06-23T10:30:00+08:00",
    "updatedAt": "2026-06-23T10:30:00+08:00"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 4.3 教程下博客列表

```http
GET /api/v1/tutorials/{tutorialId}/blogs
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 10,
      "tutorialId": 1,
      "title": "线程池的基本原理",
      "summary": "理解线程复用和任务调度",
      "sortOrder": 1,
      "estimatedMinutes": 15,
      "problemCount": 2,
      "createdAt": "2026-06-23T10:30:00+08:00"
    }
  ],
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 4.4 博客列表

```http
GET /api/v1/blogs?page=1&size=10&tutorialId=1&keyword=thread&source=official&sort=latest
```

Query 参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `tutorialId` | long | 否 | 所属教程 ID；不传则查询全部已发布博客 |
| `keyword` | string | 否 | 搜索关键词 |
| `source` | string | 否 | `official` / `user`，MVP 可选 |
| `sort` | string | 否 | `latest` / `hot` / `default` |
| `page` | int | 否 | 当前页 |
| `size` | int | 否 | 每页数量 |

### 4.5 博客详情

```http
GET /api/v1/blogs/{blogId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 10,
    "tutorialId": 1,
    "title": "线程池的基本原理",
    "contentMd": "## 线程池\n\n这里是 Markdown 正文...",
    "summary": "理解线程复用和任务调度",
    "sortOrder": 1,
    "estimatedMinutes": 15,
    "problems": [
      {
        "id": 100,
        "title": "两数之和",
        "difficulty": "EASY"
      }
    ],
    "prevBlogId": null,
    "nextBlogId": 11,
    "createdAt": "2026-06-23T10:30:00+08:00",
    "updatedAt": "2026-06-23T10:30:00+08:00"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

## 5. 题目

### 5.1 题目列表

```http
GET /api/v1/problems?blogId=10&page=1&size=10&difficulty=EASY&keyword=two
```

Query 参数：

| 参数 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `blogId` | long | 否 | 所属博客 ID |
| `difficulty` | string | 否 | `EASY` / `MEDIUM` / `HARD` |
| `keyword` | string | 否 | 搜索关键词 |
| `page` | int | 否 | 当前页 |
| `size` | int | 否 | 每页数量 |

返回字段中的 `blogId` 是题目所属博客，不再使用旧 `chapterId`。

### 5.2 题目详情

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
    "blogId": 10,
    "title": "两数之和",
    "descriptionMd": "## 题目描述\n\n给定一个整数数组...",
    "difficulty": "EASY",
    "inputDescription": "第一行输入 n...",
    "outputDescription": "输出两个下标...",
    "sampleCases": [
      {
        "input": "4\n2 7 11 15\n9\n",
        "output": "0 1\n"
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

普通题目详情只返回样例测试点，不返回隐藏测试点。

### 5.3 代码模板

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
    "code": "public class Main {\n    public static void main(String[] args) {\n    }\n}"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

## 6. 运行代码

运行接口用于“运行按钮”，只执行前端传入的测试用例。测试用例可以来自题目默认样例，也可以由用户新增或修改。

### 6.1 创建运行任务

```http
POST /api/v1/problems/{problemId}/runs
```

请求体：

```json
{
  "language": "java",
  "code": "public class Main { public static void main(String[] args) { } }",
  "testCases": [
    {
      "input": "4\n2 7 11 15\n9\n",
      "expectedOutput": "0 1\n"
    }
  ]
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `language` | string | 是 | `java` / `cpp` / `go` / `python` |
| `code` | string | 是 | 用户代码 |
| `testCases` | array | 是 | 本次运行使用的测试用例，必须至少 1 个 |
| `input` | string | 是 | 标准输入 |
| `expectedOutput` | string | 否 | 期望输出；为空时只运行并展示实际输出 |

返回：

```json
{
  "code": 0,
  "message": "run success",
  "data": {
    "runId": 80001,
    "status": "PENDING"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 6.2 查询运行结果

```http
GET /api/v1/runs/{runId}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "runId": 80001,
    "problemId": 100,
    "problemTitle": "两数之和",
    "language": "java",
    "status": "ACCEPTED",
    "timeUsedMs": 12,
    "memoryUsedKb": 20480,
    "compileMessage": null,
    "runtimeMessage": null,
    "caseResults": [
      {
        "caseIndex": 1,
        "status": "ACCEPTED",
        "timeUsedMs": 4,
        "memoryUsedKb": 10240,
        "input": "4\n2 7 11 15\n9\n",
        "actualOutput": "0 1\n",
        "expectedOutput": "0 1\n",
        "errorMessage": null
      }
    ]
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

运行结果可以展示所有用户传入的测试用例输入，因为这些输入来自前端用户。

## 7. 提交判题

提交接口用于正式判题。Core 会使用数据库中的全部测试用例，包括隐藏测试点。

### 7.1 提交代码

```http
POST /api/v1/problems/{problemId}/submissions
```

请求体：

```json
{
  "language": "java",
  "code": "public class Main { public static void main(String[] args) { } }"
}
```

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
    "status": "WRONG_ANSWER",
    "timeUsedMs": 12,
    "memoryUsedKb": 20480,
    "score": 0,
    "compileMessage": null,
    "runtimeMessage": null,
    "createdAt": "2026-06-23T10:30:00+08:00",
    "caseResults": [
      {
        "caseIndex": 2,
        "status": "WRONG_ANSWER",
        "timeUsedMs": 4,
        "memoryUsedKb": 10240,
        "input": "3\n3 2 4\n6\n",
        "actualOutput": "0 1\n",
        "expectedOutput": "1 2\n",
        "errorMessage": null
      }
    ]
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

提交结果展示规则：

```text
ACCEPTED：可以只展示总体状态和耗时内存。
COMPILE_ERROR：展示 compileMessage。
RUNTIME_ERROR / WRONG_ANSWER / TIME_LIMIT_EXCEEDED / MEMORY_LIMIT_EXCEEDED：只展示第一个出错测试点详情。
隐藏测试点是否展示 input / expectedOutput 由产品策略控制；MVP 当前允许展示第一个失败点用于调试。
```

### 7.3 我的提交记录

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
        "createdAt": "2026-06-23T10:30:00+08:00"
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

## 8. 行为埋点预留

AI 暂不开发，但 V2/V3 需要依赖行为数据。V1 可以只保留表结构和契约，不强制接入页面。

```http
POST /api/v1/tracking/events
```

请求体：

```json
{
  "events": [
    {
      "eventType": "BLOG_VIEW",
      "tutorialId": 1,
      "blogId": 10,
      "problemId": null,
      "submissionId": null,
      "durationSeconds": 35,
      "extra": {
        "scrollPercent": 80
      },
      "occurredAt": "2026-06-23T10:30:00+08:00"
    }
  ]
}
```

## 9. 状态枚举

判题和运行状态统一使用：

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

语言枚举：

```text
java
cpp
go
python
```

提交模式：

```text
FULL_PROGRAM
TEMPLATE_WRAPPED
```

## 10. 轮询建议

运行和提交都采用轮询：

```text
首次创建任务后 500ms 查询一次
之后每 1000ms 查询一次
超过 30s 停止轮询并提示稍后刷新
状态进入终态后停止轮询
```

终态：

```text
ACCEPTED
WRONG_ANSWER
COMPILE_ERROR
RUNTIME_ERROR
TIME_LIMIT_EXCEEDED
MEMORY_LIMIT_EXCEEDED
SYSTEM_ERROR
```
