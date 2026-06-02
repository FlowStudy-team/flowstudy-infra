# 13. 认证、安全与限流设计文档

## 1. 文档目的

本文档定义 FlowStudy 的用户认证、接口鉴权、权限控制、内部服务鉴权、Redis 限流、安全边界和敏感配置保护规则。

FlowStudy 涉及用户登录、代码提交、判题沙箱、AI 问答和行为数据采集，因此安全设计必须从项目早期就纳入统一规范。

## 2. 安全目标

```text
1. 用户身份可信
2. 用户密码不明文存储
3. 普通用户不能访问管理接口
4. 未登录用户不能提交代码
5. 高频请求会被限流
6. Judge 服务不暴露公网
7. AI / Core 内部接口需要鉴权
8. LLM API Key、JWT Secret 等敏感信息不提交仓库
9. 用户代码只能在 Judge 沙箱中运行
```

## 3. 用户认证方案

MVP 阶段采用：

```text
JWT Access Token
```

登录成功返回：

```json
{
  "accessToken": "jwt-token",
  "tokenType": "Bearer",
  "expiresIn": 7200,
  "user": {
    "id": 10001,
    "username": "wdd",
    "nickname": "Flow Learner",
    "role": "USER"
  }
}
```

前端请求头：

```http
Authorization: Bearer <access_token>
```

## 4. 密码安全

规则：

```text
1. 禁止明文存储密码
2. 使用 BCrypt 等安全哈希算法
3. 数据库只保存 password_hash
4. 登录时使用 passwordEncoder.matches(raw, hash)
5. 注册时校验密码强度
```

密码建议：

```text
长度至少 8 位
不能全为空白字符
后期可增加大小写、数字、特殊字符规则
```

用户表字段：

```sql
password_hash VARCHAR(255) NOT NULL
```

## 5. JWT 设计

JWT Payload 建议包含：

```json
{
  "sub": "10001",
  "username": "wdd",
  "role": "USER",
  "iat": 1710000000,
  "exp": 1710007200
}
```

配置项：

```env
JWT_SECRET=please-change-this-secret
JWT_EXPIRE_SECONDS=7200
```

注意事项：

```text
1. JWT_SECRET 必须从环境变量读取
2. 生产环境必须使用强随机密钥
3. Token 过期返回 40100
4. Token 解析失败返回 40100
5. 不要在日志中打印完整 token
```

## 6. 接口权限控制

### 6.1 公开接口

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/articles
GET  /api/v1/articles/{articleId}
GET  /api/v1/articles/{articleId}/chapters
GET  /api/v1/chapters/{chapterId}
GET  /api/v1/problems
GET  /api/v1/problems/{problemId}
GET  /api/v1/health
```

### 6.2 登录后接口

```http
GET  /api/v1/users/me
POST /api/v1/problems/{problemId}/submissions
GET  /api/v1/submissions/{submitId}
GET  /api/v1/submissions
POST /api/v1/tracking/events
POST /api/v1/ai/notes/generate
```

### 6.3 管理员接口

```http
/api/v1/admin/**
```

规则：

```text
USER 访问返回 40300
ADMIN 才能访问
```

### 6.4 内部服务接口

```http
/api/v1/internal/**
```

请求头：

```http
X-Internal-Token: ${INTERNAL_API_TOKEN}
```

普通用户不能访问。

## 7. 用户上下文设计

Core 服务中应维护 `UserContext`：

```text
userId
username
role
traceId
```

使用原则：

```text
1. Controller 不直接解析 JWT
2. 安全过滤器负责解析 JWT
3. Service 从 UserContext 获取当前用户
4. 异步线程使用用户上下文时要显式传递 userId
```

## 8. 错误码映射

| 场景 | 错误码 |
|---|---:|
| 参数错误 | `40000` |
| 未登录 | `40100` |
| Token 无效 | `40100` |
| Token 过期 | `40100` |
| 无权限 | `40300` |
| 用户不存在 | `40400` |
| 用户名重复 | `40900` |
| 请求过于频繁 | `42900` |
| 系统异常 | `50000` |

## 9. Redis 限流设计

限流目标：

```text
1. 防止登录暴力破解
2. 防止代码提交刷接口
3. 防止 AI 问答请求过多导致费用异常
4. 防止埋点接口被滥用
```

推荐技术：

```text
Redis + Lua 脚本
```

## 10. 限流规则建议

| 接口 | 维度 | 规则 |
|---|---|---|
| 登录 | IP | 每分钟最多 10 次 |
| 注册 | IP | 每小时最多 20 次 |
| 代码提交 | userId | 每分钟最多 20 次 |
| 代码提交 | IP | 每分钟最多 60 次 |
| AI 问答 | userId | 每分钟最多 10 次 |
| AI 问答 | userId | 每日最多 200 次 |
| 埋点上报 | userId | 每分钟最多 120 次 |
| 管理接口 | userId | 每分钟最多 60 次 |

触发限流返回：

```json
{
  "code": 42900,
  "message": "too many requests",
  "data": null,
  "traceId": "9f2c1a7e",
  "timestamp": 1710000000000
}
```

## 11. 限流 Key 设计

```text
rate:login:ip:{ip}
rate:register:ip:{ip}
rate:submit:user:{userId}
rate:submit:ip:{ip}
rate:ai:user:{userId}
rate:tracking:user:{userId}
```

## 12. 代码提交安全

规则：

```text
1. Core 禁止执行用户代码
2. 用户代码只进入 fs_submission 和 MQ 消息
3. Judge 服务负责沙箱运行
4. 测试用例不应在普通用户接口中暴露隐藏用例
5. 代码提交大小要有限制
```

建议限制：

```text
单次代码长度不超过 64KB
单个用户提交频率按限流规则控制
```

## 13. Judge 服务安全边界

Judge 服务：

```text
1. 不暴露公网
2. 只消费 RabbitMQ 任务
3. 用户代码必须在沙箱中运行
4. 禁止网络访问
5. 限制 CPU、内存、运行时间
6. 运行目录每次任务隔离
```

## 14. AI 服务安全边界

AI 服务：

```text
1. LLM_API_KEY 只能从环境变量读取
2. 不要将 token、密码、密钥传给 LLM
3. 对用户输入做长度限制
4. 对上下文内容做截断
5. AI 调 Core internal API 必须带内部 token
6. 用户隐私数据不要无差别进入 Prompt
```

## 15. CORS 配置

开发环境允许：

```env
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

生产环境只允许正式域名，不建议使用 `*`。

## 16. 敏感配置规范

禁止提交：

```text
.env
.env.local
.env.production
application-prod.yml 中的真实密码
真实 JWT_SECRET
真实 LLM_API_KEY
数据库真实密码
服务器私钥
```

`.gitignore` 应包含：

```gitignore
.env
.env.*
!.env.example
*.pem
*.key
```

## 17. 日志安全

禁止打印：

```text
完整 JWT token
用户明文密码
LLM API Key
数据库密码
内部服务 token
完整敏感请求头
```

可以打印：

```text
traceId
userId
接口路径
错误码
耗时
submitId
taskId
```

## 18. MVP 实现顺序

```text
阶段 1：密码 BCrypt 加密
阶段 2：JWT 登录和解析
阶段 3：UserContext
阶段 4：接口鉴权
阶段 5：admin 权限控制
阶段 6：Redis + Lua 限流
阶段 7：internal API Token
阶段 8：AI 请求限流
阶段 9：安全审计日志
```

## 19. 验收标准

```text
1. 用户密码不会明文入库
2. 登录成功能获取 JWT
3. 未登录访问受保护接口返回 40100
4. USER 访问 admin 接口返回 40300
5. 代码提交接口有限流
6. 高频请求返回 42900
7. internal API 需要 X-Internal-Token
8. 日志中不包含敏感密钥
9. .env 不会被提交到 Git
```
