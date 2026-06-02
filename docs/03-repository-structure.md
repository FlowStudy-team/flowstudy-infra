# 03. FlowStudy 仓库结构说明

## 1. 仓库拆分原则

FlowStudy 采用多仓库结构，将前端、核心业务服务、判题服务、AI 服务和基础设施文档分别管理。这样做的原因是各模块技术栈差异明显，职责边界清晰，开发节奏也不同。前端使用 JavaScript/TypeScript 技术栈，Core Service 使用 Java，Judge Service 使用 Go，AI Service 使用 Python。如果全部放在一个仓库中，依赖管理、构建方式、代码规范和 CI/CD 会混在一起，不利于团队协作。

当前推荐保留四个业务仓库，再根据需要增加一个基础设施仓库。`.github` 是 GitHub 组织级配置仓库，不算业务服务仓库。

## 2. 推荐仓库列表

```text
FlowStudy Organization
├── .github
├── flowstudy-frontend
├── flowstudy-core
├── flowstudy-judge
├── flowstudy-ai
└── flowstudy-infra
```

其中 `flowstudy-infra` 如果暂时不想新增，也可以先把文档和 docker-compose 放在 `flowstudy-core/docs` 中。但从长期维护角度看，基础设施、契约文档和部署脚本不属于任何单一业务服务，独立成仓库更清晰。

## 3. `.github` 仓库

`.github` 是 GitHub 组织配置仓库，主要用于组织主页、Issue 模板、PR 模板、贡献指南、CODEOWNERS 和通用工作流说明。它不放业务代码，也不放数据库 SQL 或服务配置。

推荐结构：

```text
.github/
├── profile/
│   └── README.md
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   └── feature_request.md
├── workflows/
│   └── README.md
├── CODEOWNERS
├── CONTRIBUTING.md
└── pull_request_template.md
```

`profile/README.md` 用于展示 FlowStudy 组织主页，说明项目定位、仓库列表和快速导航。`ISSUE_TEMPLATE` 用于规范 Bug 和需求提交。`pull_request_template.md` 用于要求开发者说明改动内容、测试结果和关联 Issue。`CODEOWNERS` 用于指定不同模块的代码负责人。

## 4. `flowstudy-frontend` 仓库

`flowstudy-frontend` 是前端项目仓库，负责所有用户界面和交互体验。

推荐职责包括：登录注册页面、文章列表页、章节阅读页、题目详情页、Monaco Editor 代码编辑器、代码提交、判题结果展示、AI 侧边栏、SSE 流式输出接入、学习行为埋点、个人中心和学习笔记页面。

推荐目录结构：

```text
flowstudy-frontend/
├── public/
├── src/
│   ├── api/
│   ├── assets/
│   ├── components/
│   ├── layouts/
│   ├── pages/
│   ├── router/
│   ├── stores/
│   ├── styles/
│   ├── utils/
│   └── main.ts
├── .env.example
├── .gitignore
├── package.json
├── vite.config.ts
└── README.md
```

`api/` 目录封装所有 HTTP 请求；`pages/` 目录放页面级组件；`components/` 目录放通用组件；`stores/` 目录放用户信息、文章状态、AI 会话状态等全局状态；`utils/` 放 token 管理、SSE 处理、时间格式化等工具函数。

前端仓库不应该出现数据库账号、RabbitMQ 地址和 LLM API Key。它只需要知道 Core Service 和 AI Service 的 HTTP 入口。

## 5. `flowstudy-core` 仓库

`flowstudy-core` 是 Java 核心业务服务仓库，是 FlowStudy 的业务中心。

推荐职责包括：用户注册登录、JWT 鉴权、用户信息、文章管理、章节管理、题目管理、测试用例读取、代码提交、提交记录查询、Redis 限流、RabbitMQ 判题任务投递、判题结果消费、行为事件接收和转发、AI 上下文内部查询接口。

推荐目录结构：

```text
flowstudy-core/
├── src/
│   ├── main/
│   │   ├── java/com/flowstudy/core/
│   │   │   ├── common/
│   │   │   ├── config/
│   │   │   ├── security/
│   │   │   ├── module/
│   │   │   │   ├── auth/
│   │   │   │   ├── user/
│   │   │   │   ├── article/
│   │   │   │   ├── chapter/
│   │   │   │   ├── problem/
│   │   │   │   ├── submission/
│   │   │   │   ├── tracking/
│   │   │   │   └── ai/
│   │   │   ├── mq/
│   │   │   └── FlowStudyCoreApplication.java
│   │   └── resources/
│   │       ├── application.yml
│   │       ├── application-dev.yml
│   │       └── mapper/
│   └── test/
├── docs/
├── .env.example
├── pom.xml
└── README.md
```

`common/` 放统一返回体、错误码、异常处理、分页结构等公共代码。`security/` 放 JWT 过滤器、认证逻辑和权限控制。`module/` 按业务模块拆分。`mq/` 放 RabbitMQ 生产者、消费者和消息 DTO。

Core Service 不负责执行用户代码，也不直接实现大模型 Agent 工作流。它只负责业务数据和调度。

## 6. `flowstudy-judge` 仓库

`flowstudy-judge` 是判题服务仓库，推荐使用 Go 开发。它是后台 Worker，不直接服务前端。

推荐职责包括：连接 RabbitMQ、消费判题任务、创建临时工作目录、写入用户代码、编译代码、运行测试用例、限制时间和内存、比对输出、生成测试点结果、发送判题结果消息、清理临时文件。

推荐目录结构：

```text
flowstudy-judge/
├── cmd/
│   └── judge-worker/
│       └── main.go
├── internal/
│   ├── config/
│   ├── mq/
│   ├── runner/
│   ├── sandbox/
│   ├── comparator/
│   ├── model/
│   └── service/
├── scripts/
├── docker/
│   ├── java-runner/
│   ├── cpp-runner/
│   ├── go-runner/
│   └── python-runner/
├── .env.example
├── go.mod
└── README.md
```

`mq/` 负责 RabbitMQ 消费和发布；`runner/` 负责不同语言的编译运行命令；`sandbox/` 负责 Docker 或底层沙箱调用；`comparator/` 负责输出比对；`model/` 放 MQ 消息结构和判题结果结构。

Judge Service 不应该直接操作用户表、文章表或 AI 对话表。MVP 阶段它甚至可以不直接连接 MySQL，只通过 MQ 接收任务和返回结果。

## 7. `flowstudy-ai` 仓库

`flowstudy-ai` 是 Python AI Agent 服务仓库，负责大模型相关能力。

推荐职责包括：FastAPI 接口、AI 侧边栏问答、SSE 流式输出、上下文构造、Prompt 模板管理、调用 LLM API、保存或回传 AI 对话、消费行为事件、分析用户错误、更新用户画像、生成 Markdown 学习笔记、后续接入 RAG 和 Agent 工作流。

推荐目录结构：

```text
flowstudy-ai/
├── app/
│   ├── api/
│   ├── core/
│   ├── clients/
│   ├── schemas/
│   ├── services/
│   │   ├── chat/
│   │   ├── context/
│   │   ├── profile/
│   │   ├── note/
│   │   └── rag/
│   ├── prompts/
│   ├── mq/
│   └── main.py
├── data/
├── tests/
├── .env.example
├── pyproject.toml
└── README.md
```

`api/` 放 FastAPI 路由；`clients/` 放 Core Service 客户端和 LLM 客户端；`services/context/` 放上下文构造逻辑；`services/chat/` 放问答逻辑；`services/profile/` 放用户画像分析；`services/note/` 放笔记生成；`prompts/` 放 Prompt 模板。

AI Service 不应该要求前端传入完整文章内容和用户代码全文作为唯一依据。更好的方式是通过 ID 向 Core Service 查询可信上下文。

## 8. `flowstudy-infra` 仓库

`flowstudy-infra` 是基础设施和文档仓库，推荐用于存放 docker-compose、数据库初始化 SQL、RabbitMQ 定义、Nginx 配置、项目契约文档和部署脚本。

推荐目录结构：

```text
flowstudy-infra/
├── docs/
│   ├── 00-project-overview.md
│   ├── 01-mvp-scope-roadmap.md
│   ├── 02-system-architecture.md
│   ├── 03-repository-structure.md
│   ├── 04-dev-environment.md
│   ├── 05-restful-api-contract.md
│   ├── 06-result-error-code-contract.md
│   ├── 07-database-design.md
│   ├── 08-rabbitmq-message-contract.md
│   └── ...
├── mysql/
│   └── init/
│       └── 001_init_schema.sql
├── rabbitmq/
│   └── definitions.json
├── nginx/
│   └── flowstudy.conf
├── scripts/
│   ├── start-dev.sh
│   └── stop-dev.sh
├── docker-compose.yml
└── README.md
```

这个仓库的价值是统一团队开发环境和项目契约。所有服务仓库的 README 都可以链接到这里的文档。

## 9. 仓库之间的依赖关系

`flowstudy-frontend` 依赖 Core Service 和 AI Service 的 HTTP API 契约。`flowstudy-core` 依赖 MySQL、Redis、RabbitMQ 和消息契约。`flowstudy-judge` 依赖 RabbitMQ 消息契约和沙箱运行环境。`flowstudy-ai` 依赖 Core Service 的内部上下文接口、RabbitMQ 行为事件契约和 LLM API 环境变量。`flowstudy-infra` 不依赖业务服务，但为所有服务提供统一基础设施。

## 10. 不推荐的放置方式

不要把前端代码放到 Core Service 仓库里，这会导致前后端构建混乱。不要把 Judge Service 放到 Core Service 里直接调用，这会削弱沙箱隔离和异步削峰能力。不要把 AI Prompt、Agent 工作流和大模型调用逻辑写在 Java Core Service 中，这会让 Core Service 变得臃肿。不要把 docker-compose 分散到每个仓库里，否则团队成员会出现不同的 MySQL、Redis 和 RabbitMQ 配置。

## 11. README 约定

每个仓库都必须有 README。README 至少包含项目职责、技术栈、本地启动方式、环境变量说明、依赖服务、常用命令和相关文档链接。业务细节不必全部写在 README 中，复杂设计应链接到 `flowstudy-infra/docs`。

## 12. 当前建议

当前你已经拆分出 `flowstudy-core`、`flowstudy-judge`、`flowstudy-ai` 和 `flowstudy-frontend`，这个方向是正确的。接下来建议新增 `flowstudy-infra` 仓库，用于放置本文档、后续的 API 契约、MQ 契约、数据库设计、docker-compose 和部署脚本。这样四个业务仓库可以保持干净，团队成员也能从一个统一入口找到所有工程规范。
