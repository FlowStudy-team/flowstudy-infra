# FlowStudy 前后端对接文档

## 1. 系统设计概览

FlowStudy 前端位于 `flowstudy-web`，技术栈为 Vue 3 + Vite + TypeScript + Pinia + Vue Router。当前接口大多为前端 mock，后端对接时需要将 `src/api` 下的 mock 函数替换为真实 HTTP 请求。

### 1.1 前端架构

- `main.ts`：创建 Vue 应用，注册 Pinia 和 Router。
- `App.vue`：全局根组件，挂载统一顶部导航 `SiteHeader`，再渲染路由页面。
- `router/index.ts`：维护所有页面路由和登录拦截。
- `store/modules/auth.ts`：登录态和 token 管理。
- `store/modules/ai.ts`：AI 面板开关、消息状态。
- `src/api`：接口封装层，后端对接的主要修改位置。
- `src/types`：前后端字段约定的 TypeScript 类型来源。
- `src/views`：路由页面。
- `src/components`：复用 UI 组件。
- `src/composables`：可复用业务逻辑，例如文档保存、列表查询、自动草稿。
- `src/utils`：本地存储、Markdown WYSIWYG 转换、代码草稿等工具。

### 1.2 当前主要业务模块

- 用户认证：登录、注册、顶部头像菜单、路由权限。
- 文章阅读：后端开发/一周热点入口，目前 `/articles` 指向阅读页。
- 算法练习与 OJ：练习列表、题目详情、代码编辑、运行、提交、结果展示。
- 文档中心：Finder 风格文件夹管理、多级文件夹、文档编辑、发布。
- 个人中心：学习概览、进度分析、提交记录。
- AI 助手：全局抽屉和页面右侧 AI 辅助栏。

## 2. 目录与文件作用

### 2.1 项目根目录

| 路径 | 作用 |
| --- | --- |
| `package.json` | 依赖和脚本配置：`dev`、`type-check`、`lint`、`build` |
| `index.html` | Vite HTML 入口 |
| `vite.config.ts` | Vite 配置 |
| `tsconfig*.json` | TypeScript 配置 |
| `public/` | 静态资源，构建时原样复制 |
| `dist/` | 构建产物 |
| `src/` | 前端源码 |

### 2.2 `src` 核心目录

| 路径 | 作用 |
| --- | --- |
| `src/api` | 接口封装层；当前含 mock，后端对接时替换为 HTTP 请求 |
| `src/assets` | 图片与静态资源，当前 `hero.png` 为 FlowStudy 标识 |
| `src/components/ai` | AI 抽屉和右侧 AI 栏 |
| `src/components/common` | 通用组件，如顶部导航、头像菜单、loading/empty/error、分页 |
| `src/components/document` | 文档中心和文档编辑相关组件 |
| `src/components/markdown` | Markdown 编辑/渲染组件 |
| `src/components/oj` | OJ 题面、代码编辑器、工具栏、测试结果组件 |
| `src/composables` | 组合式业务逻辑 |
| `src/layouts` | 页面布局容器 |
| `src/router` | 路由定义和登录拦截 |
| `src/store` | Pinia 状态 |
| `src/types` | 类型定义，建议作为前后端字段对齐基准 |
| `src/utils` | 存储、草稿、Markdown 转换工具 |
| `src/views` | 路由页面 |

### 2.3 重点页面

| 路由 | 页面组件 | 说明 |
| --- | --- | --- |
| `/` | `views/home/HomeView.vue` | 首页 |
| `/login` | `views/auth/LoginView.vue` | 登录 |
| `/register` | `views/auth/RegisterView.vue` | 注册 |
| `/articles` | `views/articles/ArticleDetailView.vue` | 文章阅读首页/后端开发入口 |
| `/articles/chapters/:chapterId` | `views/articles/ChapterDetailView.vue` | 章节详情 |
| `/practice` | `views/practice/PracticePlanView.vue` | 算法练习计划 |
| `/problems/:problemId` | `views/oj/OjProblemDetailView.vue` | OJ 题目详情、运行、提交 |
| `/document` | `views/document/DocumentListView.vue` | 文档中心，文件夹视图 |
| `/document/workspace` | `views/document/DocumentWorkspaceView.vue` | 新建文档/旧专业工作台入口 |
| `/document/:id` | `views/document/DocumentReadView.vue` | 文档内容编辑页 |
| `/document/:id/edit` | `views/document/DocumentWorkspaceView.vue` | 旧编辑入口 |
| `/me` | `views/profile/ProfileHomeView.vue` | 个人主页 |
| `/me/submissions` | `views/profile/SubmissionListView.vue` | 我的提交 |
| `/progress` | `views/profile/ProgressAnalysisView.vue` | 学习进度分析 |

## 3. 通用对接约定

### 3.1 推荐统一响应格式

前端已有 `src/types/common.ts` 中的 `ApiResponse<T>`：

```ts
interface ApiResponse<T> {
  code: number
  message: string
  data: T
}
```

建议真实后端统一返回：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

分页结果建议使用：

```ts
interface PageResult<T> {
  list: T[]
  total: number
  page: number
  pageSize: number
}
```

### 3.2 认证约定

- 登录成功后返回 `token`。
- 前端保存 token 到 Pinia/localStorage。
- 请求头建议统一使用：

```http
Authorization: Bearer <token>
```

### 3.3 错误处理约定

建议后端错误仍保持统一结构：

```json
{
  "code": 40001,
  "message": "参数错误",
  "data": null
}
```

前端页面需要展示 loading、empty、error 状态。

## 4. API 对接清单

以下为当前前端已使用或预期使用的接口。URL 是建议设计，后端可按实际网关前缀调整。

### 4.1 认证模块

当前文件：`src/api/modules/auth.ts`

#### 登录

```http
POST /api/auth/login
```

请求：

```ts
interface AuthRequest {
  email: string
  password: string
}
```

响应：

```ts
interface AuthResponse {
  token?: string
  message?: string
}
```

#### 注册

```http
POST /api/auth/register
```

请求：

```ts
interface AuthRequest {
  email: string
  password: string
  confirmPassword?: string
}
```

响应同登录。

### 4.2 文章/一周热点模块

当前文件：`src/api/modules/articles.ts`

#### 文章列表

```http
GET /api/articles?page=1&pageSize=10&keyword=java
```

请求：

```ts
interface PageQuery {
  page: number
  pageSize: number
  keyword?: string
}
```

响应：

```ts
interface Article {
  id: string
  title: string
  tags: string[]
  difficulty: 'Beginner' | 'Intermediate' | 'Advanced'
  updatedAt: string
}
```

返回 `PageResult<Article>`。

#### 文章详情

```http
GET /api/articles/{articleId}
```

响应：

```ts
interface ArticleDetail {
  id: string
  title: string
  markdown: string
  chapters: Chapter[]
}

interface Chapter {
  id: string
  title: string
  problemIds: string[]
}
```

#### 章节详情

```http
GET /api/articles/{articleId}/chapters/{chapterId}
```

响应：

```ts
interface ChapterDetail {
  id: string
  articleId: string
  title: string
  markdown: string
  problemIds: string[]
}
```

### 4.3 OJ 题目模块

当前新版页面使用：`src/api/oj.ts`

#### 获取题目详情

```http
GET /api/oj/problems/{problemId}
```

响应：

```ts
interface OJProblem {
  id: string
  title: string
  difficulty: '简单' | '中等' | '困难'
  description: string
  inputDesc: string
  outputDesc: string
  samples: Array<{ input: string; output: string; explanation?: string }>
  constraints: string[]
  tags: string[]
}
```

#### 获取语言选项

```http
GET /api/oj/languages
```

响应：

```ts
interface OJLanguageOption {
  value: 'java' | 'cpp' | 'python' | 'javascript'
  label: string
  template: string
  monacoLanguage: 'java' | 'cpp' | 'python' | 'javascript'
}
```

#### 运行代码

```http
POST /api/oj/problems/{problemId}/run
```

请求建议：

```ts
interface RunCodeRequest {
  language: string
  code: string
}
```

响应：

```ts
interface OJJudgeResult {
  status: 'PENDING' | 'COMPILING_ERROR' | 'RUNTIME_ERROR' | 'WRONG_ANSWER' | 'ACCEPTED'
  message: string
  runtimeMs?: number
  memoryKb?: number
  compileError?: string
  runtimeError?: string
  testCases: OJTestCaseResult[]
}

interface OJTestCaseResult {
  index: number
  input: string
  expected: string
  output: string
  status: OJJudgeResult['status']
  message?: string
}
```

#### 提交代码

```http
POST /api/oj/problems/{problemId}/submit
```

请求同运行代码，响应同 `OJJudgeResult`。

### 4.4 旧题目/提交模块

当前文件：`src/api/modules/problems.ts`、`src/api/modules/submissions.ts`

这部分被旧页面和个人提交记录使用，建议后端仍提供或后续统一迁移到 OJ 模块。

#### 获取题目详情

```http
GET /api/problems/{problemId}
```

响应：

```ts
interface ProblemDetail {
  id: string
  title: string
  description: string
  inputDesc: string
  outputDesc: string
  samples: Array<{ input: string; output: string }>
  constraints: string[]
  languages: string[]
  starterCode: Record<string, string>
}
```

#### 提交题解

```http
POST /api/problems/{problemId}/submissions
```

请求：

```ts
interface SubmitSolutionRequest {
  problemId: string
  language: string
  code: string
}
```

响应：

```ts
interface SubmissionDetail {
  id: string
  problemId: string
  status: 'PENDING' | 'RUNNING' | 'AC' | 'WA' | 'TLE' | 'RE' | 'CE'
  runtimeMs: number
  memoryKb: number
  language: string
  createdAt: string
  testCases: TestCaseResult[]
}
```

#### 我的提交列表

```http
GET /api/me/submissions?page=1&pageSize=10&keyword=p1001
```

返回 `PageResult<SubmissionDetail>`。

### 4.5 文档中心模块

当前文件：`src/api/document.ts`

#### 获取文档分类

```http
GET /api/document/categories
```

响应：

```ts
interface DocumentCategory {
  id: number
  name: string
  parentId?: number
  children?: DocumentCategory[]
}
```

#### 获取文件夹树

```http
GET /api/document/folders
```

响应：

```ts
interface DocumentFolder {
  id: number
  name: string
  parentId?: number
  createdAt: string
  updatedAt: string
  children?: DocumentFolder[]
}
```

#### 新建文件夹

```http
POST /api/document/folders
```

请求：

```ts
interface CreateDocumentFolderPayload {
  name: string
  parentId?: number
}
```

响应：`DocumentFolder`。

#### 获取文档列表

```http
GET /api/documents?keyword=&folderId=1&categoryId=1&tag=Vue3&status=draft&page=1&pageSize=24
```

请求：

```ts
interface DocumentQuery {
  keyword?: string
  folderId?: number
  categoryId?: number
  tag?: string
  status?: 'draft' | 'private' | 'published' | 'archived'
  page?: number
  pageSize?: number
}
```

响应：

```ts
interface DocumentListResult {
  list: DocumentItem[]
  total: number
}

interface DocumentItem {
  id: number
  title: string
  summary?: string
  folderId?: number
  folderName?: string
  categoryId?: number
  categoryName?: string
  tags: string[]
  status: 'draft' | 'private' | 'published' | 'archived'
  updatedAt: string
  createdAt: string
  publishedAt?: string
}
```

#### 获取文档详情

```http
GET /api/documents/{id}
```

响应：

```ts
interface DocumentDetail extends DocumentItem {
  content: string
}
```

#### 新建文档

```http
POST /api/documents
```

请求：

```ts
interface CreateDocumentPayload {
  title: string
  content?: string
  folderId?: number
  categoryId?: number
  tags?: string[]
}
```

响应：`DocumentDetail`。

#### 更新文档

```http
PATCH /api/documents/{id}
```

请求：

```ts
interface UpdateDocumentPayload {
  title?: string
  content?: string
  summary?: string
  folderId?: number
  categoryId?: number
  tags?: string[]
  status?: 'draft' | 'private' | 'published' | 'archived'
}
```

响应：`DocumentDetail`。

#### 删除文档

```http
DELETE /api/documents/{id}
```

响应：空数据或 `{ success: true }`。

#### 发布文档

```http
POST /api/documents/{id}/publish
```

请求：

```ts
interface PublishDocumentPayload {
  title: string
  summary: string
  coverUrl?: string
  tags: string[]
  visible: boolean
  allowComment: boolean
}
```

响应：`DocumentDetail`。

### 4.6 个人中心模块

当前文件：`src/api/modules/profile.ts`

#### 个人概要

```http
GET /api/me/profile
```

响应：

```ts
interface ProfileSummary {
  name: string
  email: string
  streakDays: number
  solvedCount: number
}
```

#### 最近活动

```http
GET /api/me/activities/recent
```

响应：

```ts
interface LearningActivity {
  id: string
  title: string
  time: string
  type: 'article' | 'chapter' | 'problem'
}
```

### 4.7 AI 助手模块

当前文件：`src/api/modules/ai.ts`

#### 提问

```http
POST /api/ai/chat
```

请求：

```ts
interface AskAiRequest {
  prompt: string
  context?: {
    route?: string
    articleId?: string
    documentId?: number
    problemId?: string
  }
}
```

响应：

```ts
interface AiMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  createdAt: string
}
```

## 5. 后端优先级建议

### P0：必须优先接入

- 登录/注册与 token。
- OJ 题目详情、语言模板、运行、提交。
- 文档文件夹树、文档列表、文档详情、保存文档。

### P1：核心体验完善

- 文档发布。
- 我的提交列表。
- 个人中心概要。
- 最近学习活动。

### P2：增强功能

- AI 助手真实接口。
- 文章列表/一周热点列表。
- 章节详情与题目关联。
- 文档删除、重命名文件夹、移动文件夹/文档、拖拽排序。

## 6. 当前前端需要后端注意的问题

- 当前 `src/api/document.ts` 和 `src/api/oj.ts` 暂未放在 `src/api/modules` 下，后续可统一迁移。
- 当前 `document.ts`、`oj.ts`、部分页面 mock 文案存在编码显示问题，真实接口对接时建议统一 UTF-8。
- 文档普通编辑模式内部将可编辑 HTML 转换为 Markdown，后端只需要存储 Markdown 字符串 `content`。
- OJ 运行和提交接口建议区分 `run` 与 `submit`：`run` 返回样例/自测结果，`submit` 返回正式判题结果。
- 前端当前没有统一 request 封装，接后端前建议新增 `src/api/request.ts`，统一 baseURL、token、错误处理。

