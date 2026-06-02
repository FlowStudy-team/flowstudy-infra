# 06-result-error-code-contract.md

# FlowStudy 统一返回格式与错误码规范

## 1. 文档目标

本文档定义 FlowStudy 项目的统一响应结构、分页结构、错误码、异常返回格式、TraceId 规范和判题状态枚举。

FlowStudy 包含前端、Java Core Service、Go Judge Service、Python AI Service 等多个服务。为了让前端能够稳定处理不同服务的响应结果，所有非流式 HTTP 接口必须遵守本文档定义的统一返回格式。

---

## 2. 统一响应结构 Result<T>

### 2.1 标准 JSON 结构

所有普通 HTTP API 返回统一结构：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| code | int | 是 | 业务状态码，0 表示成功 |
| message | string | 是 | 响应消息 |
| data | any | 否 | 业务数据，失败时通常为 null |
| traceId | string | 是 | 链路追踪 ID |
| timestamp | long | 是 | 响应时间戳，毫秒级 Unix 时间戳 |

---

## 3. 成功返回规范

### 3.1 普通对象返回

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 10001,
    "username": "wdd"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 3.2 空数据返回

当接口执行成功但无业务数据返回时，`data` 可以为 `null`：

```json
{
  "code": 0,
  "message": "success",
  "data": null,
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 3.3 创建资源成功返回

```json
{
  "code": 0,
  "message": "created",
  "data": {
    "id": 10001
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

### 3.4 异步任务提交成功返回

```json
{
  "code": 0,
  "message": "task submitted",
  "data": {
    "taskId": "note-task-001",
    "status": "PENDING"
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

## 4. 分页返回结构 PageResult<T>

分页接口统一返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "records": [],
    "total": 100,
    "page": 1,
    "size": 10
  },
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| records | array | 当前页数据 |
| total | long | 总记录数 |
| page | int | 当前页，从 1 开始 |
| size | int | 每页数量 |

Java DTO 建议：

```java
public class PageResult<T> {

    private List<T> records;

    private Long total;

    private Integer page;

    private Integer size;
}
```

---

## 5. Java Result<T> 建议实现

```java
public class Result<T> {

    private Integer code;

    private String message;

    private T data;

    private String traceId;

    private Long timestamp;

    public static <T> Result<T> success(T data) {
        Result<T> result = new Result<>();
        result.setCode(0);
        result.setMessage("success");
        result.setData(data);
        result.setTimestamp(System.currentTimeMillis());
        return result;
    }

    public static <T> Result<T> success(String message, T data) {
        Result<T> result = new Result<>();
        result.setCode(0);
        result.setMessage(message);
        result.setData(data);
        result.setTimestamp(System.currentTimeMillis());
        return result;
    }

    public static <T> Result<T> fail(Integer code, String message) {
        Result<T> result = new Result<>();
        result.setCode(code);
        result.setMessage(message);
        result.setData(null);
        result.setTimestamp(System.currentTimeMillis());
        return result;
    }
}
```

实际项目中建议通过拦截器或全局响应处理器自动设置 `traceId`，而不是在每个 Controller 中手动设置。

---

## 6. 错误返回规范

失败响应统一格式：

```json
{
  "code": 40000,
  "message": "invalid request parameter",
  "data": null,
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

错误响应原则：

```text
1. code 不得为 0
2. message 必须能让前端或用户理解基本原因
3. data 默认使用 null
4. traceId 必须返回，方便日志排查
5. 不允许把数据库密码、系统路径、LLM API Key 等敏感信息返回给前端
```

---

## 7. 全局错误码定义

### 7.1 通用错误码

| 错误码 | HTTP 状态码 | 含义 | 前端处理建议 |
|---:|---:|---|---|
| 0 | 200 | 成功 | 正常处理 |
| 40000 | 400 | 请求参数错误 | 提示用户检查输入 |
| 40001 | 400 | JSON 格式错误 | 提示请求格式错误 |
| 40002 | 400 | 缺少必要参数 | 提示补全参数 |
| 40003 | 400 | 参数类型错误 | 提示参数格式错误 |
| 40100 | 401 | 未登录或 Token 缺失 | 跳转登录页 |
| 40101 | 401 | Token 已过期 | 刷新 Token 或重新登录 |
| 40102 | 401 | Token 无效 | 清除登录态并重新登录 |
| 40300 | 403 | 无权限 | 提示无权限 |
| 40400 | 404 | 资源不存在 | 展示空状态或 404 页面 |
| 40500 | 405 | 请求方法不允许 | 检查接口调用方式 |
| 40900 | 409 | 数据冲突 | 提示冲突原因 |
| 42900 | 429 | 请求过于频繁 | 提示稍后再试 |
| 50000 | 500 | 系统内部错误 | 提示系统繁忙 |
| 50001 | 500 | 数据库异常 | 提示系统繁忙 |
| 50002 | 500 | Redis 异常 | 提示系统繁忙 |
| 50003 | 500 | RabbitMQ 异常 | 提示系统繁忙 |

---

### 7.2 用户与认证错误码

| 错误码 | 含义 |
|---:|---|
| 41000 | 用户不存在 |
| 41001 | 用户名或密码错误 |
| 41002 | 用户名已存在 |
| 41003 | 邮箱已存在 |
| 41004 | 用户已被禁用 |
| 41005 | 密码强度不足 |
| 41006 | 登录状态异常 |

示例：

```json
{
  "code": 41001,
  "message": "username or password is incorrect",
  "data": null,
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

---

### 7.3 内容与题目错误码

| 错误码 | 含义 |
|---:|---|
| 42000 | 文章不存在 |
| 42001 | 章节不存在 |
| 42002 | 题目不存在 |
| 42003 | 文章未发布 |
| 42004 | 章节未发布 |
| 42005 | 题目未发布 |
| 42006 | 不支持的编程语言 |
| 42007 | 测试用例不存在 |

---

### 7.4 提交与判题错误码

| 错误码 | 含义 |
|---:|---|
| 43000 | 提交记录不存在 |
| 43001 | 代码不能为空 |
| 43002 | 代码长度超过限制 |
| 43003 | 提交过于频繁 |
| 43004 | 判题任务投递失败 |
| 43005 | 判题结果不存在 |
| 53000 | 判题服务异常 |
| 53001 | 判题服务不可用 |
| 53002 | 沙箱运行异常 |
| 53003 | 编译器环境异常 |
| 53004 | 测试用例加载失败 |
| 53005 | 判题结果回传失败 |

---

### 7.5 AI 服务错误码

| 错误码 | 含义 |
|---:|---|
| 54000 | AI 服务异常 |
| 54001 | AI 服务不可用 |
| 54002 | LLM 调用失败 |
| 54003 | LLM API Key 未配置 |
| 54004 | 上下文获取失败 |
| 54005 | Prompt 构造失败 |
| 54006 | SSE 流式响应中断 |
| 54007 | 笔记生成任务失败 |
| 54008 | 用户画像更新失败 |
| 54009 | RAG 检索失败 |

---

### 7.6 内部服务错误码

| 错误码 | 含义 |
|---:|---|
| 55000 | 内部服务调用失败 |
| 55001 | 内部 Token 缺失 |
| 55002 | 内部 Token 无效 |
| 55003 | 服务间通信超时 |
| 55004 | 服务响应格式错误 |

---

## 8. 判题状态枚举

代码提交状态统一使用以下枚举：

| 状态 | 说明 | 是否终态 |
|---|---|---:|
| PENDING | 等待判题 | 否 |
| RUNNING | 正在判题 | 否 |
| ACCEPTED | 答案正确 | 是 |
| WRONG_ANSWER | 答案错误 | 是 |
| COMPILE_ERROR | 编译错误 | 是 |
| RUNTIME_ERROR | 运行时错误 | 是 |
| TIME_LIMIT_EXCEEDED | 超出时间限制 | 是 |
| MEMORY_LIMIT_EXCEEDED | 超出内存限制 | 是 |
| SYSTEM_ERROR | 系统错误 | 是 |

前端判断是否继续轮询时，只有 `PENDING` 和 `RUNNING` 需要继续轮询，其余状态均停止轮询。

---

## 9. 题目难度枚举

```text
EASY
MEDIUM
HARD
```

---

## 10. 用户角色枚举

```text
USER
ADMIN
```

---

## 11. 内容状态枚举

文章、章节、题目可以使用统一状态：

```text
DRAFT
PUBLISHED
OFFLINE
```

含义：

| 状态 | 说明 |
|---|---|
| DRAFT | 草稿，仅管理员可见 |
| PUBLISHED | 已发布，普通用户可见 |
| OFFLINE | 已下线，普通用户不可见 |

---

## 12. 行为事件枚举

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

---

## 13. AI 消息角色枚举

```text
system
user
assistant
```

---

## 14. TraceId 规范

### 14.1 TraceId 作用

`traceId` 用于串联一次请求在不同服务、数据库、Redis、RabbitMQ、AI 调用之间的完整链路。

FlowStudy 存在同步 HTTP 调用和异步 MQ 调用，如果没有 `traceId`，后期排查问题会非常困难。

### 14.2 TraceId 生成规则

当请求进入 Core Service 时：

```text
如果请求头中已有 X-Trace-Id，则继续使用该值
如果没有 X-Trace-Id，则由 Core Service 自动生成
```

推荐请求头：

```http
X-Trace-Id: 9f2c1a7e
```

TraceId 推荐格式：

```text
16 到 32 位字符串
可使用 UUID、雪花 ID、NanoID 或短 UUID
```

### 14.3 TraceId 传递规则

HTTP 调用时，通过 Header 传递：

```http
X-Trace-Id: 9f2c1a7e
```

MQ 消息中，通过消息外壳传递：

```json
{
  "traceId": "9f2c1a7e"
}
```

日志中必须打印：

```text
traceId=9f2c1a7e
```

---

## 15. SSE 接口错误格式

AI 流式接口不使用普通 `Result<T>` 包裹每个 token，而是使用 SSE 事件。

正常输出：

```text
event: delta
data: {"content":"你这里的问题是"}

event: delta
data: {"content":"循环边界写错了"}

event: done
data: {"conversationId":30001}
```

错误输出：

```text
event: error
data: {"code":54000,"message":"AI service unavailable","traceId":"9f2c1a7e"}
```

SSE 事件类型：

| event | 说明 |
|---|---|
| delta | 增量文本 |
| done | 输出完成 |
| error | 发生错误 |
| ping | 保活事件 |

---

## 16. 前端统一处理建议

前端请求封装时建议统一处理：

```text
1. 如果 code = 0，返回 data
2. 如果 code = 40100 / 40101 / 40102，清理登录态并跳转登录页
3. 如果 code = 40300，提示无权限
4. 如果 code = 42900，提示请求过于频繁
5. 如果 code >= 50000，提示系统繁忙
6. 其他错误直接展示 message
```

伪代码：

```ts
async function request<T>(config): Promise<T> {
  const res = await http.request<Result<T>>(config)

  if (res.code === 0) {
    return res.data
  }

  if ([40100, 40101, 40102].includes(res.code)) {
    logout()
    redirectToLogin()
    throw new Error(res.message)
  }

  showMessage(res.message)
  throw new Error(res.message)
}
```

---

## 17. 后端异常映射建议

Java Core Service 建议使用全局异常处理器：

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusinessException(BusinessException ex) {
        return Result.fail(ex.getCode(), ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidationException(MethodArgumentNotValidException ex) {
        return Result.fail(40000, "invalid request parameter");
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleException(Exception ex) {
        return Result.fail(50000, "internal server error");
    }
}
```

---

## 18. 敏感信息处理规范

错误返回中禁止包含：

```text
数据库连接地址和密码
Redis 密码
RabbitMQ 密码
JWT Secret
LLM API Key
服务器真实文件路径
用户完整代码运行目录
系统内部堆栈
容器内部路径
```

可以返回给用户的信息：

```text
参数错误原因
登录状态异常
资源不存在
代码编译错误
代码运行错误
判题超时
AI 服务暂时不可用
```

对于系统异常，前端只展示：

```text
系统繁忙，请稍后重试
```

详细错误信息只写入服务端日志，并通过 `traceId` 关联排查。

---

## 19. 本文档维护规则

当以下内容发生变化时，必须同步更新本文档：

```text
Result<T> 结构
PageResult<T> 结构
错误码
状态枚举
SSE 事件格式
TraceId 传递规则
前端错误处理逻辑
后端异常映射规则
```

错误码新增时，必须遵守以下原则：

```text
1. 不复用已有错误码
2. 同一业务域使用连续号段
3. message 简洁明确
4. 前端可根据 code 做稳定判断
```
