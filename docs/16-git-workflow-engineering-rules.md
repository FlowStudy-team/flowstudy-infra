# 16. Git 工作流与工程规范文档

## 1. 文档目的

本文档定义 FlowStudy 团队的 Git 分支管理、提交规范、PR 规范、Code Review 规则、代码格式化、文档同步和工程纪律。

FlowStudy 是多仓库项目，包含 `flowstudy-core`、`flowstudy-frontend`、`flowstudy-judge`、`flowstudy-ai`、`flowstudy-infra` 等仓库，因此必须使用统一工作流避免协作混乱。

## 2. 基本原则

```text
1. main 分支必须保持稳定
2. 禁止直接 push 到 main
3. 所有功能通过 feature 分支开发
4. 所有合并通过 Pull Request
5. Commit message 遵守约定式提交规范
6. 修改接口、数据库、MQ 时必须同步文档
7. PR 合并前必须自测
8. 不提交敏感配置和本地环境文件
```

## 3. 分支命名规范

格式：

```text
<type>/<scope>-<short-description>
```

### 3.1 type

| type | 说明 |
|---|---|
| `feat` | 新功能、新接口 |
| `fix` | Bug 修复 |
| `docs` | 文档修改 |
| `refactor` | 重构，不改变外部行为 |
| `test` | 测试相关 |
| `chore` | 构建、依赖、脚本等杂项 |
| `ci` | CI/CD 配置 |
| `style` | 代码格式，不影响逻辑 |

### 3.2 示例

```text
feat/core-init
feat/auth-register-login
feat/article-chapter-query
feat/problem-query-api
feat/submission-mq-publish
feat/judge-result-consumer
feat/redis-rate-limit
feat/tracking-events
feat/ai-context-api
feat/admin-content-manage

docs/update-api-contract
docs/add-database-design
docs/update-pr-template

fix/auth-token-validation
fix/submission-status-update

refactor/common-exception-handler
test/auth-controller
chore/update-dependencies
```

## 4. Core 阶段性分支建议

| 阶段 | 分支名 |
|---|---|
| 项目初始化 | `feat/core-init` |
| 统一返回和异常 | `feat/common-contract` |
| 数据库实体和 Mapper | `feat/database-base` |
| 用户注册登录 | `feat/auth-register-login` |
| 文章章节查询 | `feat/article-chapter-query` |
| 题目查询 | `feat/problem-query-api` |
| 代码提交和 MQ 投递 | `feat/submission-mq-publish` |
| Judge 结果消费 | `feat/judge-result-consumer` |
| Redis 限流 | `feat/redis-rate-limit` |
| 行为埋点 | `feat/tracking-events` |
| AI 上下文接口 | `feat/ai-context-api` |
| 管理后台 | `feat/admin-content-manage` |

## 5. 开发流程

标准流程：

```bash
git switch main
git pull origin main
git switch -c feat/auth-register-login
```

开发完成后：

```bash
git status
git add .
git commit -m "feat: add user authentication APIs"
git push -u origin feat/auth-register-login
```

然后在 GitHub 创建 PR。

注意：

```text
1. 一个分支只做一个明确功能
2. 不要在同一个分支同时做登录、文章、MQ、AI
3. 如果 main 更新，及时 rebase 或 merge main
4. 不要把临时代码提交进 PR
```

## 6. Commit Message 规范

采用 Conventional Commits / Angular 风格。

格式：

```text
<type>: <description>
```

示例：

```text
feat: add user authentication APIs
feat: add article and chapter query APIs
feat: add code submission and judge task publishing
fix: correct JWT token validation
docs: update RESTful API contract
refactor: improve global exception handling
test: add auth controller tests
chore: update Maven dependencies
```

可选格式：

```text
<type>(<scope>): <description>
```

示例：

```text
feat(auth): add login and register APIs
feat(submission): publish judge task to RabbitMQ
fix(security): handle expired JWT token
docs(api): update submission contract
```

## 7. PR 标题规范

PR 标题建议与主要 commit 保持一致：

```text
feat: add user authentication APIs
docs: add database design and init SQL
fix: correct submission status update
```

## 8. PR 模板要求

每个 PR 必须说明：

```text
1. 变更说明
2. 变更目的
3. 关联 Issue
4. 影响范围
5. 具体改动
6. 测试说明
7. 测试截图或日志
8. 风险与影响
9. 回滚方案
10. 自查清单
```

如果没有关联 Issue：

```text
Resolves N/A
```

## 9. Code Review 规则

Reviewer 需要重点检查：

```text
1. 是否符合当前阶段开发目标
2. 是否破坏统一接口契约
3. 是否返回 Result<T>
4. 是否直接返回 Entity
5. 是否遗漏错误码处理
6. 是否有敏感信息泄露
7. 是否更新 API / DB / MQ 文档
8. 是否存在不必要的大范围重构
9. 是否有明显性能问题
10. 是否有测试说明
```

## 10. 文档同步规则

| 变更 | 必须更新文档 |
|---|---|
| 新增 / 修改 REST API | `05-restful-api-contract.md` |
| 新增 / 修改错误码 | `06-result-error-code-contract.md` |
| 新增 / 修改数据库表字段 | `07-database-design.md` 和 SQL |
| 新增 / 修改 MQ 消息 | `08-rabbitmq-message-contract.md` |
| 新增环境变量 | `04-dev-environment.md` 或 `.env.example` |
| 修改部署方式 | `15-deployment-docker-compose.md` |
| 修改开发流程 | `16-git-workflow-engineering-rules.md` |

## 11. 代码风格规范

### 11.1 Java / Core

```text
JDK 17
Spring Boot 3
MyBatis-Plus
Controller 保持轻量
Service 放业务逻辑
Mapper 只做数据访问
DTO 接收请求
VO 返回响应
禁止 Controller 直接返回 Entity
```

### 11.2 Frontend

```text
ESLint
Prettier
TypeScript
组件按职责拆分
API 统一封装
不要在组件里硬编码接口地址
```

### 11.3 Go / Judge

```text
gofmt
go vet
错误必须显式处理
不要 panic 结束 Worker 主流程
```

### 11.4 Python / AI

```text
ruff / black
pytest
配置通过环境变量读取
不要硬编码 LLM API Key
```

## 12. 敏感文件规范

禁止提交：

```text
.env
.env.local
.env.production
真实数据库密码
真实 JWT_SECRET
真实 LLM_API_KEY
服务器私钥
本地 IDE 缓存
```

允许提交：

```text
.env.example
application-dev.yml 中的占位配置
docker-compose 本地默认开发密码
```

`.gitignore` 建议包含：

```gitignore
.env
.env.*
!.env.example
.idea/
.vscode/
target/
node_modules/
dist/
*.log
```

## 13. 多仓库协作规范

推荐本地目录：

```text
C:\dev\FlowStudy-team\
├── flowstudy-core
├── flowstudy-frontend
├── flowstudy-judge
├── flowstudy-ai
└── flowstudy-infra
```

规则：

```text
1. flowstudy-infra/docs 是统一文档源
2. 各业务仓库可以保留 docs/contracts 快照
3. 修改契约时先更新 infra，再同步到相关仓库
4. PR 中说明影响哪些仓库
```

## 14. Codex / AI Agent 使用规范

使用 Codex 或其他 AI 编码助手时：

```text
1. 先让 AI 读取相关 docs
2. 明确只修改当前任务相关文件
3. 不允许 AI 自动 commit / push，除非明确要求
4. 最后让 AI 输出建议 commit message
5. 开发者必须人工 review AI 生成代码
```

推荐提示：

```text
使用 flowstudy-core-feature，开发登录接口。
请先读取 docs/contracts 中的 API、错误码和数据库文档。
不要自动 commit 或 push。
完成后输出建议分支名和 commit message。
```

## 15. 合并策略

推荐：

```text
Squash and merge
```

优点：

```text
1. main 历史更干净
2. 一个 PR 对应一个提交
3. 方便回滚
```

## 16. 回滚策略

如果合并后出问题：

```bash
git revert <commit-hash>
```

如果是 PR：

```text
GitHub -> Pull Request -> Revert
```

数据库变更需要额外提供：

```text
回滚 SQL
数据修复说明
是否影响已有数据
```

## 17. 验收标准

```text
1. 所有开发都基于 feature 分支
2. main 没有直接 push
3. PR 标题符合规范
4. Commit message 符合规范
5. 影响 API / DB / MQ 的变更已同步文档
6. PR 中有测试说明
7. 没有提交敏感文件
8. Reviewer 可以根据 PR 描述理解改动内容
```
