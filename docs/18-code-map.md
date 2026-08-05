# 18. FlowStudy 代码映射

本文建立设计文档与实际代码之间的映射。路径均为相对父目录 `flowstudy` 的真实路径。

## Repository Overview

| 仓库 | 启动入口 | 构建文件 | 配置文件 | 测试目录 | Docker 文件 | 核心源码目录 |
|---|---|---|---|---|---|---|
| `flowstudy-core` | `flowstudy-core/src/main/java/com/flowstudy/core/FlowstudyCoreApplication.java` | `flowstudy-core/pom.xml` | `flowstudy-core/src/main/resources/application.properties`、`application-example.yml` | `flowstudy-core/src/test/java` | 未发现 | `flowstudy-core/src/main/java/com/flowstudy/core` |
| `flowstudy-judge` | `flowstudy-judge/src/main.cpp` | `flowstudy-judge/CMakeLists.txt`、`flowstudy-judge/src/CMakeLists.txt` | `flowstudy-judge/config.example.json`、`config.json` | `flowstudy-judge/test` | 未发现 | `flowstudy-judge/src` |
| `flowstudy-ai` | `flowstudy-ai/app/main.py` | `flowstudy-ai/requirements.txt` | `.env.example`、运行时 `.env` | 未发现 | 未发现 | `flowstudy-ai/app` |
| `flowstudy-frontend` | `flowstudy-frontend/flowstudy-web/src/main.ts` | `flowstudy-frontend/flowstudy-web/package.json`、`vite.config.ts` | `flowstudy-frontend/flowstudy-web/.env.example` | 未发现 | 未发现 | `flowstudy-frontend/flowstudy-web/src` |
| `flowstudy-infra` | `README.md` | 无 | `nginx/nginx.conf`、`env/*.env.example` | 无 | `docker-compose.yml` 为空 | `docs`、`mysql`、`nginx` |

## Core Service Code Map

| 能力 | 实际代码 |
|---|---|
| 用户与认证 | `flowstudy-core/src/main/java/com/flowstudy/core/module/auth/controller/AuthController.java`、`AuthService.java`、`security/JwtAuthenticationFilter.java`、`security/SecurityConfig.java` |
| 教程或文章内容 | `module/tutorial/controller/TutorialController.java`、`module/blog/controller/BlogController.java`、`module/tutorial/service/TutorialService.java`、`module/blog/service/BlogService.java` |
| 题目 | `module/problem/controller/ProblemController.java`、`module/problem/service/ProblemService.java`、`module/problem/mapper/ProblemMapper.java` |
| 提交记录 | `module/submission/controller/SubmissionController.java`、`SubmissionService.java`、`SubmissionMapper.java` |
| 代码运行 | `module/submission/service/CodeRunService.java`、`CodeRunMapper.java`、`CodeRunCaseResultMapper.java` |
| 判题任务 | `module/submission/judge/JudgeSubmitMessage.java`、`JudgeSubmitTestcase.java`、`SubmissionCodePackager.java` |
| RabbitMQ 生产者和消费者 | 生产者：`module/submission/judge/JudgeTaskPublisher.java`；队列声明：`JudgeRabbitConfig.java`；结果消费者未发现 |
| 数据访问 | 各模块 `mapper/*Mapper.java`，MyBatis 注解 SQL |
| 异常处理 | `common/exception/BusinessException.java`、`GlobalExceptionHandler.java` |
| 统一返回结构 | `common/result/Result.java`、`PageResponse.java` |
| 配置管理 | `src/main/resources/application.properties`、`.env.example` |

## Judge Service Code Map

| 能力 | 实际代码 |
|---|---|
| 消息接收 | `flowstudy-judge/src/mq/rabbitmq_client.cpp`、`src/worker/worker.cpp` |
| 请求解析 | `src/judge/judge_engine.cpp` 的 `JudgeEngine::parse_message` |
| 编译 | `src/judge/sandbox.cpp` 的 `Sandbox::compile` |
| 执行 | `src/judge/sandbox.cpp` 的 `Sandbox::run` |
| 超时控制 | `Sandbox::run` 构造 isolate `--time`/`--wall-time` 参数，`JudgeEngine::judge` 检查 `timed_out`/`TO` |
| 资源限制 | `Sandbox::run` 使用 `--mem`，`JudgeEngine::judge` 检查 `memory_used_kb` |
| 临时文件 | `Sandbox` 写入 isolate box 下的 `solution.*`、`input.txt`、`output.txt`、`error.txt`、meta 文件 |
| 结果构造 | `JudgeResultInternal`、`JudgeCaseResultInternal`，`worker.cpp` 转为 `JudgeResult` |
| 消息返回 | 未发现 RabbitMQ 结果发布；当前通过 `db/mysql_client.cpp` 写 MySQL |
| 并发控制 | `JudgeEngine::BoxPool` 使用 mutex、condition_variable 和 isolate box 池 |
| 错误处理 | 解析失败 ACK 丢弃，DB 更新失败 NACK requeue，判题异常映射为状态 |

## AI Service Code Map

| 能力 | 实际代码 |
|---|---|
| 服务入口 | `flowstudy-ai/app/main.py` |
| API | `flowstudy-ai/app/router.py` 的 `/api/v1/ai/chat`、`/api/v1/ai/health` |
| Agent 或工作流 | 未发现独立 Agent 工作流 |
| 模型调用 | `flowstudy-ai/app/llm_client.py` 的 `LLMClient.stream_chat` |
| Prompt | `flowstudy-ai/app/prompt.py` 的 `build_system_prompt` |
| 流式响应 | `router.py` 的 `StreamingResponse` 与 SSE `data:` 行 |
| 错误处理 | `router.py` 捕获异常并发送 `{"type":"error"}` |
| 超时和重试 | 未发现显式超时/重试 |
| 配置和密钥 | `DEEPSEEK_API_KEY`、`DEEPSEEK_BASE_URL`、`DEEPSEEK_MODEL` |

## Frontend Code Map

| 能力 | 实际代码 |
|---|---|
| 应用入口 | `flowstudy-frontend/flowstudy-web/src/main.ts`、`App.vue` |
| 路由 | `src/router/index.ts` |
| 状态管理 | `src/store/modules/auth.ts`、`src/store/modules/ai.ts` |
| 鉴权 | `src/api/request.ts` 注入 Bearer Token，路由守卫在 `router/index.ts` |
| API 请求封装 | `src/api/request.ts`、`src/api/modules/*`、`src/api/oj.ts` |
| 教程页面 | `src/views/learning/LearningCenterView.vue`、`src/views/articles/ArticleDetailView.vue`、`ChapterDetailView.vue` |
| 题目页面 | `src/views/oj/OjProblemDetailView.vue`、`src/views/practice/PracticePlanView.vue` |
| 编辑器 | `src/components/oj/OjCodeEditor.vue`、Monaco 依赖 |
| 提交和结果展示 | `src/api/oj.ts`、`src/components/oj/OjSubmitResultPanel.vue`、`OjTestCasePanel.vue` |
| 环境配置 | `flowstudy-web/.env.example` 的 `VITE_API_BASE_URL=/api/v1` |
| 构建配置 | `package.json`、`vite.config.ts`、`tsconfig*.json` |

## Cross-Repository Flows

### 登录链路

1. Frontend `src/composables/useAuthForm.ts` 调用 `src/api/modules/auth.ts` 的 `login`/`register`。
2. `src/api/request.ts` 请求 `${VITE_API_BASE_URL}/auth/login` 或 `/auth/register`。
3. Core `module/auth/controller/AuthController.java` 接收请求。
4. Core `AuthService.java` 使用 `UserMapper` 查询/写入 `sys_user`，`JwtTokenProvider` 生成 JWT。
5. Frontend `src/store/modules/auth.ts` 保存 token 和 user。

### 教程访问链路

1. Frontend `src/api/modules/articles.ts` 调用 `/tutorials`、`/tutorials/{id}`、`/blogs`、`/blogs/{id}`。
2. Core `TutorialController.java`、`BlogController.java` 处理请求。
3. Core `TutorialService.java`、`BlogService.java` 通过 `TutorialMapper.java`、`BlogMapper.java` 访问 `fs_tutorial`、`fs_blog`。

### 提交判题链路

1. Frontend `src/views/oj/OjProblemDetailView.vue` 调用 `src/api/oj.ts` 的 `runOjCode` 或 `submitOjCode`。
2. Core `SubmissionController.java` 接收 `/problems/{problemId}/runs` 或 `/problems/{problemId}/submissions`。
3. Core `CodeRunService.java` 或 `SubmissionService.java` 写入 `fs_code_run`/`fs_submission`，用 `JudgeTaskPublisher.java` 投递 `JudgeSubmitMessage` 到 `submission_queue`。
4. Judge `RabbitMQClient::consume` 接收消息，`JudgeEngine::parse_message` 解析。
5. Judge `Sandbox::compile`、`Sandbox::run` 编译运行，`JudgeEngine::compare_output` 比对结果。
6. Judge `MySQLClient::update_code_run` 或 `update_submission` 写回 `fs_code_run`/`fs_submission` 和 case result 表。
7. Frontend 轮询 Core `GET /runs/{runId}` 或 `GET /submissions/{submitId}` 展示结果。

### AI 调用链路

1. Frontend `src/components/ai/AiSidebar.vue`/`AiDrawer.vue` 使用 `src/store/modules/ai.ts`。
2. `src/api/modules/ai.ts` 直接 `fetch('/ai/api/v1/ai/chat')`。
3. Vite `vite.config.ts` 将 `/ai` 代理到 `http://localhost:8000` 并去掉 `/ai` 前缀。
4. AI `app/router.py` 的 `chat` 构造 SSE，调用 `LLMClient.stream_chat`。
5. `app/llm_client.py` 读取 `DEEPSEEK_API_KEY` 并调用 DeepSeek/OpenAI-compatible API。

## Documentation Mismatches

| 差异 | 文档位置 | 代码位置 |
|---|---|---|
| OpenAPI 使用 `/api/auth`、`/api/oj`，实际 Core/Frontend 使用 `/api/v1` | `flowstudy-infra/docs/api/FlowStudy_Apifox_OpenAPI.yaml` | `flowstudy-core/src/main/java/.../controller/*Controller.java`、`flowstudy-frontend/flowstudy-web/src/api/request.ts` |
| 文档描述 Judge 通过 RabbitMQ 回传结果，实际 Judge 直写 MySQL | `flowstudy-infra/docs/08-rabbitmq-message-contract.md`、`10-judge-service-design.md` | `flowstudy-judge/src/db/mysql_client.cpp`、`flowstudy-core` 未发现 `@RabbitListener` |
| Docker Compose 文档可启动服务，但 compose 文件为空 | `flowstudy-infra/docs/15-deployment-docker-compose.md`、`README.md` | `flowstudy-infra/docker-compose.yml` |
| infra 环境模板文档存在，但 env 示例为空 | `flowstudy-infra/README.md`、`docs/04-dev-environment.md` | `flowstudy-infra/env/*.env.example` |
| Redis 限流在规划文档中出现，Core 未发现 Redis 依赖或实现 | `docs/01-mvp-scope-roadmap.md`、`docs/13-auth-security-rate-limit.md` | `flowstudy-core/pom.xml`、`flowstudy-core/src/main/java` |
| Judge 旧文档/脚本仍使用 `submissions` 表，当前 Worker 写 `fs_submission` | `flowstudy-judge/scripts/setup_db.sql`、`flowstudy-judge/documentation/DATA_FORMATS.md` | `flowstudy-judge/src/db/mysql_client.cpp` |
