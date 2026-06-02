# 17. 测试计划文档

## 1. 文档目的

本文档定义 FlowStudy 项目的测试范围、测试类型、各服务测试重点、MVP 验收标准、联调流程和发布前检查清单。

FlowStudy 涉及前端、Core、Judge、AI、MySQL、Redis、RabbitMQ 多组件，因此测试不能只关注单个接口，还必须验证完整业务链路。

## 2. 测试目标

```text
1. 核心接口符合 API 契约
2. 用户注册登录流程正确
3. 文章、章节、题目能正常展示
4. 代码提交能入库并投递 RabbitMQ
5. Judge 能消费任务并回传结果
6. Core 能更新提交状态
7. 前端能展示判题结果
8. AI 能根据上下文回答问题
9. 行为埋点能入库并投递
10. 错误码、traceId、日志符合规范
```

## 3. 测试类型

| 类型 | 说明 |
|---|---|
| 单元测试 | 测试单个函数、Service、工具类 |
| Controller 测试 | 使用 MockMvc / WebTestClient 测试接口行为 |
| Mapper 测试 | 测试 MyBatis-Plus 查询和映射 |
| 集成测试 | 测试 Core + MySQL / Redis / RabbitMQ |
| MQ 测试 | 测试消息生产、消费、幂等 |
| 前端测试 | 测试页面交互、API 调用、表单校验 |
| E2E 测试 | 从登录到提交代码再到展示结果 |
| 安全测试 | 权限、限流、敏感数据 |
| 性能测试 | 提交接口、判题队列、AI 问答 |
| 回归测试 | 合并前确保旧功能不被破坏 |

## 4. Core 测试计划

### 4.1 公共基础测试

测试内容：

```text
Result<T>
PageResult<T>
ErrorCode
BusinessException
GlobalExceptionHandler
TraceIdFilter
```

验收：

```text
1. 成功响应 code = 0
2. 失败响应包含 code / message / traceId / timestamp
3. 参数错误返回 40000
4. 未登录返回 40100
5. 无权限返回 40300
6. 每个响应都有 traceId
```

### 4.2 Auth 测试

接口：

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/users/me
```

测试用例：

```text
1. 用户名、邮箱、密码合法时注册成功
2. 用户名重复时返回 40900
3. 邮箱重复时返回 40900
4. 密码为空或过短时返回 40000
5. 登录成功返回 accessToken
6. 密码错误返回业务错误
7. 不带 token 访问 /users/me 返回 40100
8. 带合法 token 访问 /users/me 成功
```

### 4.3 内容查询测试

接口：

```http
GET /api/v1/articles
GET /api/v1/articles/{articleId}
GET /api/v1/articles/{articleId}/chapters
GET /api/v1/chapters/{chapterId}
GET /api/v1/problems
GET /api/v1/problems/{problemId}
```

测试用例：

```text
1. 文章列表分页正常
2. 不存在的 articleId 返回 40400
3. 文章下章节按 sort_order 排序
4. 章节详情返回 Markdown 内容
5. 题目详情只返回样例测试点
6. 不返回隐藏测试用例
```

### 4.4 代码提交测试

接口：

```http
POST /api/v1/problems/{problemId}/submissions
GET  /api/v1/submissions/{submitId}
```

测试用例：

```text
1. 未登录提交返回 40100
2. problemId 不存在返回 40400
3. 不支持的 language 返回 40000
4. 空代码返回 40000
5. 提交成功创建 fs_submission
6. 初始状态为 PENDING
7. 成功投递 judge.submit.created 消息
8. 查询 submitId 返回提交详情
```

### 4.5 Judge 结果消费测试

消息：

```text
judge.result.finished
```

测试用例：

```text
1. 收到 ACCEPTED 结果后更新 fs_submission
2. 收到 COMPILE_ERROR 后写入 compile_message
3. 收到 RUNTIME_ERROR 后写入 runtime_message
4. 测试点结果写入 fs_judge_case_result
5. 重复消息不会重复插入脏数据
6. 不存在的 submitId 记录 WARN
```

### 4.6 行为埋点测试

接口：

```http
POST /api/v1/tracking/events
```

测试用例：

```text
1. 批量事件上报成功
2. 非法 eventType 返回 40000
3. 事件写入 fs_behavior_event
4. 成功投递 behavior.* 消息
5. 高频上报触发限流
```

## 5. Judge 测试计划

测试内容：

```text
1. RabbitMQ 连接
2. 消费 judge.submit.created
3. 创建临时目录
4. 编译 Java / C++ / Go / Python
5. 运行测试用例
6. 判断 Accepted
7. 判断 Wrong Answer
8. 判断 Compile Error
9. 判断 Runtime Error
10. 判断 Time Limit Exceeded
11. 判断 Memory Limit Exceeded
12. 回传 judge.result.finished
```

安全测试：

```text
1. 用户代码不能访问网络
2. 用户代码不能读取敏感文件
3. 死循环会超时
4. 大内存申请会被限制
5. 每次运行目录隔离
```

## 6. AI 测试计划

接口：

```http
POST /api/v1/ai/chat/stream
POST /api/v1/ai/notes/generate
```

测试用例：

```text
1. SSE 能正常返回 delta 事件
2. done 事件包含 conversationId
3. LLM 失败时返回 error event
4. AI 能调用 Core 获取上下文
5. 上下文包含章节、题目、代码和报错
6. 笔记生成任务能创建
7. 行为消息能被消费
8. 画像更新不阻塞用户问答
```

## 7. Frontend 测试计划

页面：

```text
/login
/register
/articles
/chapters/:chapterId
/problems/:problemId
/submissions/:submitId
```

测试用例：

```text
1. 登录表单校验
2. 注册表单校验
3. Token 存储和过期处理
4. 文章列表正常展示
5. Markdown 渲染正常
6. 题目详情正常展示
7. Monaco Editor 正常加载
8. 代码模板正常加载
9. 提交代码后进入 PENDING
10. 轮询到最终判题结果
11. AI 侧边栏能显示流式回答
12. 接口错误能展示 message 和 traceId
```

## 8. E2E 主链路测试

核心链路：

```text
用户注册
  ↓
用户登录
  ↓
浏览文章
  ↓
进入章节
  ↓
打开题目
  ↓
编辑代码
  ↓
提交代码
  ↓
Core 创建提交记录
  ↓
RabbitMQ 投递判题任务
  ↓
Judge 消费并运行
  ↓
Judge 回传结果
  ↓
Core 更新结果
  ↓
前端展示判题结果
```

MVP 必须通过这条链路。

## 9. 测试数据准备

建议初始化：

```text
1 个管理员用户
1 个普通用户
1 篇文章
2 个章节
2 道题目
每道题至少 2 个样例测试点
每道题至少 3 个隐藏测试点
```

默认用户密码应由后端 BCrypt 生成，不建议在 SQL 中写不可靠 hash。

## 10. 测试环境

本地依赖：

```text
MySQL 8.4
Redis 7.2
RabbitMQ 3.13
JDK 17
Node.js 20+
Go 1.22+
Python 3.11+
Docker
```

启动基础设施：

```bash
cd flowstudy-infra
docker compose up -d
```

## 11. 推荐测试命令

Core：

```bash
mvn test
```

Frontend：

```bash
npm run lint
npm run test
npm run build
```

Judge：

```bash
go test ./...
```

AI：

```bash
pytest
```

Docker Compose：

```bash
docker compose ps
docker compose logs -f
```

## 12. PR 前检查清单

```text
1. 是否执行了相关测试命令
2. 是否在 PR 中写明测试结果
3. 是否有截图或关键日志
4. 是否更新了 API / DB / MQ 文档
5. 是否没有提交敏感配置
6. 是否没有遗留调试代码
7. 是否没有破坏主链路
8. 是否有回滚方案
```

## 13. 发布前验收清单

```text
1. docker compose 能正常启动基础设施
2. Core 能正常启动
3. Frontend 能正常启动
4. Judge 能消费消息
5. AI 能提供 health 接口
6. 用户能注册登录
7. 文章章节能浏览
8. 题目能打开
9. 代码能提交
10. 判题结果能展示
11. traceId 能贯穿日志
12. RabbitMQ 无异常堆积
13. 无真实密钥泄露
```

## 14. 性能测试建议

MVP 阶段只做基础压测：

```text
1. 登录接口
2. 文章列表接口
3. 题目详情接口
4. 代码提交接口
5. 查询提交结果接口
```

关注指标：

```text
平均响应时间
P95 响应时间
错误率
RabbitMQ 队列堆积
数据库连接数
Redis 限流效果
```

工具可选：

```text
JMeter
k6
wrk
Postman Runner
```

## 15. 风险测试

重点风险：

```text
1. 用户重复提交导致 MQ 堆积
2. Judge 挂掉后提交一直 PENDING
3. AI 服务不可用影响前端
4. Redis 不可用导致限流失败
5. RabbitMQ 不可用导致提交失败
6. MySQL 初始化脚本不一致
```

降级策略：

```text
1. AI 不可用时提示 AI 暂不可用
2. Judge 不可用时提交返回系统繁忙
3. RabbitMQ 不可用时提交失败并返回明确错误
4. Redis 不可用时明确 fail-close 或 fail-open 策略
```

## 16. MVP 验收标准

FlowStudy V1 至少满足：

```text
1. 用户可以注册登录
2. 用户可以浏览文章和章节
3. 用户可以查看题目
4. 用户可以提交代码
5. Core 可以投递判题任务
6. Judge 可以返回判题结果
7. Core 可以更新提交状态
8. 前端可以展示判题结果
9. 接口统一返回 Result<T>
10. 错误响应包含 traceId
```
