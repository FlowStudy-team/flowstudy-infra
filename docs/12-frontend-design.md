# 12. Frontend 设计文档

## 1. 文档目的

本文档定义 `flowstudy-frontend` 的页面结构、组件划分、状态管理、API 接入、代码编辑器、Markdown 渲染、判题结果展示、AI 侧边栏和埋点上报方案。

前端是 FlowStudy 的用户体验入口，目标是把“阅读文章、在线写代码、提交判题、询问 AI、生成笔记”整合成一个沉浸式学习界面。

## 2. 前端职责

`flowstudy-frontend` 负责：

```text
1. 用户注册、登录和登录态维护
2. 文章列表、文章详情和章节阅读
3. 题目详情展示
4. Monaco Editor 在线代码编辑
5. 代码提交与判题结果展示
6. AI 侧边栏问答
7. 学习行为埋点
8. 学习笔记与个人画像展示
```

前端不负责：

```text
1. 业务鉴权真实逻辑
2. 判题执行
3. LLM 调用
4. 用户画像计算
5. 数据库直接访问
```

## 3. 推荐技术栈

```text
框架：Vue 3
构建工具：Vite
语言：TypeScript
路由：Vue Router
状态管理：Pinia
HTTP：Axios
UI 组件库：Element Plus / Naive UI / Ant Design Vue
Markdown 渲染：md-editor-v3 / markdown-it
代码编辑器：Monaco Editor
质量工具：ESLint + Prettier
测试：Vitest + Playwright 可选
```

如果当前项目已经选定 UI 框架，后续应保持一致，不要混用多个大型 UI 库。

## 4. 推荐目录结构

```text
flowstudy-frontend/
├── src/
│   ├── main.ts
│   ├── App.vue
│   ├── router/
│   ├── stores/
│   │   ├── auth.ts
│   │   ├── article.ts
│   │   └── submission.ts
│   ├── api/
│   │   ├── request.ts
│   │   ├── auth.ts
│   │   ├── article.ts
│   │   ├── problem.ts
│   │   ├── submission.ts
│   │   ├── tracking.ts
│   │   └── ai.ts
│   ├── views/
│   │   ├── LoginView.vue
│   │   ├── RegisterView.vue
│   │   ├── ArticleListView.vue
│   │   ├── ChapterReadView.vue
│   │   ├── ProblemDetailView.vue
│   │   ├── SubmissionDetailView.vue
│   │   ├── NotesView.vue
│   │   └── ProfileView.vue
│   ├── components/
│   │   ├── layout/
│   │   ├── markdown/
│   │   ├── editor/
│   │   ├── ai/
│   │   ├── submission/
│   │   └── common/
│   ├── composables/
│   │   ├── useAuth.ts
│   │   ├── useSseChat.ts
│   │   ├── useTracking.ts
│   │   └── usePolling.ts
│   ├── types/
│   ├── utils/
│   └── styles/
├── public/
├── .env.example
├── package.json
└── README.md
```

## 5. 路由设计

```text
/                           首页 / 项目介绍
/login                      登录
/register                   注册
/articles                   文章列表
/articles/:articleId        文章详情
/chapters/:chapterId        章节阅读
/problems/:problemId        题目详情与代码编辑
/submissions/:submitId      提交详情
/notes                      我的学习笔记
/profile                    个人中心 / 学习画像
/admin                      管理后台入口，后期实现
```

MVP 阶段优先实现：

```text
/login
/register
/articles
/chapters/:chapterId
/problems/:problemId
/submissions/:submitId
```

## 6. 核心页面设计

### 6.1 章节阅读页

路径：

```text
/chapters/:chapterId
```

页面区域：

```text
左侧：文章目录 / 章节目录
中间：Markdown 文章内容
右侧：AI 侧边栏
底部或侧边：关联题目列表
```

主要功能：

```text
1. 渲染章节 Markdown
2. 展示当前章节关联题目
3. 记录阅读停留时间
4. 支持打开 AI 侧边栏提问
5. 支持跳转到题目详情页
```

### 6.2 题目详情页

路径：

```text
/problems/:problemId
```

页面区域：

```text
左侧：题目描述、输入输出说明、样例
右侧：Monaco Editor
底部：运行 / 提交按钮、判题结果
右侧浮层：AI 助手
```

主要功能：

```text
1. 展示题目描述和样例
2. 获取语言代码模板
3. 编辑代码
4. 提交代码
5. 轮询判题结果
6. AI 根据当前题目、代码和报错回答问题
```

### 6.3 AI 侧边栏

建议组件：

```text
components/ai/AiSidebar.vue
components/ai/AiMessageList.vue
components/ai/AiInputBox.vue
```

AI 请求上下文：

```json
{
  "conversationId": null,
  "articleId": 1,
  "chapterId": 10,
  "problemId": 100,
  "submitId": 90001,
  "question": "为什么我的代码运行超时？"
}
```

SSE 处理：

```text
event: delta -> 追加内容
event: done  -> 结束本轮回答
event: error -> 显示错误提示
```

## 7. API 接入规范

统一 Axios 实例：

```text
src/api/request.ts
```

请求拦截：

```text
1. 自动添加 Authorization: Bearer <token>
2. 自动添加 X-Trace-Id
3. 自动添加 Content-Type: application/json
```

响应拦截：

```text
1. 判断 Result<T>.code
2. code = 0 返回 data
3. code = 40100 清空 token 并跳转登录
4. code != 0 展示错误 message
5. 保留 traceId 用于错误排查
```

## 8. 统一类型定义

```ts
export interface Result<T> {
  code: number
  message: string
  data: T
  traceId: string
  timestamp: number
}

export interface PageResult<T> {
  records: T[]
  total: number
  page: number
  size: number
}
```

接口函数不应在组件里直接写 URL，统一放到 `src/api`。

## 9. Monaco Editor 设计

支持语言：

```text
java
cpp
go
python
```

功能要求：

```text
1. 根据题目和语言加载代码模板
2. 自动保存草稿到 localStorage
3. 切换语言时提示是否覆盖当前代码
4. 提交前校验代码非空
5. 可配置字号、主题、自动换行
```

草稿 key：

```text
flowstudy:code-draft:{userId}:{problemId}:{language}
```

## 10. 判题结果展示

提交成功后返回：

```json
{
  "submitId": 90001,
  "status": "PENDING"
}
```

前端流程：

```text
1. 提交代码
2. 展示 PENDING 状态
3. 每 1~2 秒轮询 GET /submissions/{submitId}
4. 最终状态出现后停止轮询
5. 展示耗时、内存、得分、编译错误、运行错误和测试点结果
```

最终状态：

```text
ACCEPTED
WRONG_ANSWER
COMPILE_ERROR
RUNTIME_ERROR
TIME_LIMIT_EXCEEDED
MEMORY_LIMIT_EXCEEDED
SYSTEM_ERROR
```

轮询最大时间建议 30 秒，超时后提示稍后刷新。

## 11. 学习行为埋点

事件类型：

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

接口：

```http
POST /api/v1/tracking/events
```

实现方式：

```text
1. 页面进入时记录 startedAt
2. 页面离开时计算停留时间
3. 批量上报，减少请求次数
4. 对代码编辑事件做节流
5. 登录用户才上报用户行为
```

## 12. 路由守卫

需要登录的页面：

```text
/problems/:problemId
/submissions/:submitId
/notes
/profile
/admin
```

规则：

```text
1. 无 token 访问受保护页面 -> 跳转 /login
2. token 过期 -> 清空登录态
3. ADMIN 页面需要 role = ADMIN
```

## 13. 环境变量

`.env.example`：

```env
VITE_APP_NAME=FlowStudy
VITE_API_BASE_URL=http://localhost:8080/api/v1
VITE_AI_BASE_URL=http://localhost:8000/api/v1
VITE_ENABLE_AI_SIDEBAR=true
VITE_ENABLE_TRACKING=true
```

不要在前端保存真实 LLM API Key。

## 14. MVP 开发顺序

```text
阶段 1：项目骨架、路由、基础布局
阶段 2：登录 / 注册页面
阶段 3：文章列表、文章详情、章节阅读
阶段 4：题目详情、Monaco Editor
阶段 5：代码提交、轮询判题结果
阶段 6：AI 侧边栏静态版
阶段 7：SSE 接入真实 AI 服务
阶段 8：行为埋点与学习笔记页面
```

## 15. 验收标准

```text
1. 用户可以注册和登录
2. 登录态刷新后仍能保持
3. 用户可以浏览文章和章节
4. Markdown 渲染正常
5. 用户可以进入题目并编辑代码
6. 代码模板能正常加载
7. 用户可以提交代码
8. 判题结果轮询正常
9. AI 侧边栏可以流式输出
10. 页面行为可以上报到 Core
```
