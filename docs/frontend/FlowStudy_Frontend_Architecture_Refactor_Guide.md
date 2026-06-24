# FlowStudy 前端架构设计思想与后续重构指南

本文档用于记录当前 FlowStudy 前端的整体架构设计思想，方便后续 Codex 或其他 AI Agent 阅读、理解并辅助重构项目。

当前前端已经包含以下核心模块：

- 博客模块：用于公开内容展示、文章浏览、博客管理与发布。
- 文档模块：用于用户自己写文档、整理笔记、保存草稿和知识沉淀。
- 代码编辑 / OJ 模块：用于题目刷题、代码编辑、运行、提交和结果展示。

后续开发策略是：**先完成文档模块的功能开发并推送 PR，保证功能闭环可用；之后再进行结构重构和公共能力抽取。**

---

## 1. 当前阶段的开发策略

当前不建议一边写文档模块，一边大规模重构整个前端结构。更稳妥的策略是：

```text
第一阶段：先完成文档模块功能
  ↓
第二阶段：本地验证功能可用
  ↓
第三阶段：推送 feature 分支并提交 PR
  ↓
第四阶段：PR 合并后再统一重构前端结构
  ↓
第五阶段：抽离公共编辑器、渲染器、布局和业务逻辑
```

原因是当前博客、文档、代码编辑几个模块还在快速成型阶段，如果过早进行架构重构，容易出现以下问题：

- 功能还没有稳定，重构边界不清楚。
- 公共组件抽象过早，后续需求变化时反而难维护。
- Codex 在改代码时容易同时修改多个模块，导致 PR 难以 Review。
- 业务功能和架构调整混在一个 PR 中，出问题后不容易回滚。

因此当前原则是：

```text
先保证文档模块功能可用，再进行架构级重构。
```

---

## 2. 总体产品定位

FlowStudy 前端不应被理解为几个孤立页面，而应被理解为一个学习平台型前端系统：

```text
FlowStudy Web Client
= 学习内容创作
+ 知识沉淀整理
+ 博客分享传播
+ 在线编程训练
```

也可以拆成两条主线：

```text
FlowStudy 前端
├── 知识创作系统
│   ├── 文档
│   ├── 笔记
│   └── 博客
│
└── 编程训练系统
    ├── 题目
    ├── 代码编辑
    ├── 运行测试
    ├── 提交判题
    └── 结果展示
```

其中：

- 文档模块负责“私有沉淀”。
- 博客模块负责“公开分享”。
- OJ 模块负责“编程训练”。
- 代码编辑器、Markdown 编辑器、Markdown 渲染器、标签分类、草稿缓存、文件上传等是多个模块共享的底层能力。

---

## 3. 核心设计思想

### 3.1 不按页面思考，而按能力思考

不推荐把前端简单理解成：

```text
博客页面
文档页面
OJ 页面
代码编辑页面
```

这种设计容易导致每个模块各写一套组件，后续难以维护。

更推荐按照平台能力拆分：

```text
内容能力
├── Markdown 编辑
├── Markdown 预览
├── Markdown 渲染
├── 图片上传
├── 标签分类
├── 草稿保存
├── 发布设置
└── 文章搜索

编程能力
├── 代码编辑
├── 语言切换
├── 代码模板
├── 本地草稿
├── 运行测试
├── 提交判题
└── 结果展示

通用能力
├── 分栏布局
├── 表格分页
├── 表单校验
├── 空状态
├── 错误状态
├── Loading 状态
└── 响应式布局
```

页面的职责应该是组合这些能力，而不是把所有逻辑都写在页面里。

---

## 4. 文档与博客的关系

文档和博客不应完全割裂。它们的核心区别不在于编辑器，而在于内容状态和可见范围。

推荐关系是：

```text
Document：用户自己的私有文档、笔记、草稿
BlogPost：从某篇 Document 发布出来的公开文章
```

推荐内容流转方式：

```text
写文档
  ↓
保存草稿
  ↓
整理分类和标签
  ↓
完善摘要、封面、发布设置
  ↓
发布为博客
  ↓
公开展示
```

这意味着：

- 文档模块负责写作、整理、私有保存。
- 博客模块负责公开展示、阅读、搜索和互动。
- 博客内容可以来源于文档。
- 文档与博客应该尽可能复用 Markdown 编辑、Markdown 渲染、标签选择、图片上传、文章大纲等能力。

不要让用户在文档和博客之间复制粘贴内容，也不要为文档和博客分别维护两套完全独立的编辑器。

---

## 5. 代码编辑器的定位

代码编辑器不应该只属于 OJ 模块，而应该作为平台级通用组件存在。

错误设计：

```text
src/views/oj/OjProblemDetailView.vue 中直接写 Monaco Editor 逻辑
```

推荐设计：

```text
src/components/code/CodeEditor.vue
```

然后 OJ 页面通过组合方式使用：

```vue
<CodeEditor
  v-model="code"
  :language="language"
  :options="editorOptions"
/>
```

OJ 自己的业务面板可以写在：

```text
src/components/oj/OjCodeEditorPanel.vue
```

分工应为：

```text
CodeEditor.vue
  只负责代码编辑器本身，例如 Monaco 初始化、语言、主题、字体、内容绑定。

OjCodeEditorPanel.vue
  负责 OJ 业务，例如语言选择、代码模板、运行、提交、结果面板、草稿恢复。
```

这样未来 `CodeEditor.vue` 还可以复用于：

- OJ 刷题页面。
- 在线代码 Playground。
- 文档中的代码片段编辑。
- 博客中的代码示例编辑。
- 课程实验页面。

---

## 6. 目标目录结构

当前阶段不要求立即重构到该结构，但后续重构时应朝这个方向演进。

```text
src/
├── app/
│   ├── App.vue
│   ├── main.ts
│   └── providers/
│
├── router/
│   ├── index.ts
│   └── modules/
│       ├── blog.ts
│       ├── document.ts
│       ├── oj.ts
│       └── user.ts
│
├── layouts/
│   ├── MainLayout.vue
│   ├── WorkspaceLayout.vue
│   ├── BlogLayout.vue
│   └── OjLayout.vue
│
├── views/
│   ├── blog/
│   ├── document/
│   ├── oj/
│   └── user/
│
├── components/
│   ├── common/
│   ├── markdown/
│   ├── code/
│   ├── document/
│   ├── blog/
│   └── oj/
│
├── api/
│   ├── request.ts
│   ├── blog.ts
│   ├── document.ts
│   ├── oj.ts
│   ├── upload.ts
│   └── user.ts
│
├── types/
│   ├── common.ts
│   ├── blog.ts
│   ├── document.ts
│   ├── oj.ts
│   └── user.ts
│
├── stores/
│   ├── user.ts
│   ├── editor.ts
│   ├── document.ts
│   └── oj.ts
│
├── composables/
│   ├── useAutoSave.ts
│   ├── useDocumentEditor.ts
│   ├── useDocumentList.ts
│   ├── useCodeDraft.ts
│   ├── usePagination.ts
│   └── usePermission.ts
│
├── utils/
│   ├── storage.ts
│   ├── date.ts
│   ├── markdown.ts
│   ├── codeDraftStorage.ts
│   └── file.ts
│
└── styles/
    ├── reset.css
    ├── variables.css
    ├── theme.css
    └── markdown.css
```

核心原则：

```text
views：页面级组件，只负责页面组织。
components：可复用组件。
api：接口请求封装。
types：类型定义。
stores：全局状态。
composables：业务逻辑复用。
utils：纯工具函数。
styles：全局样式和主题。
```

---

## 7. 模块职责划分

### 7.1 文档模块

文档模块是当前优先开发的模块，目标是让用户能够完成自己的笔记和文档整理。

推荐路由：

```text
/document
/document/workspace
/document/:id
/document/:id/edit
```

推荐页面：

```text
src/views/document/
├── DocumentWorkspaceView.vue
├── DocumentListView.vue
├── DocumentEditView.vue
└── DocumentReadView.vue
```

推荐组件：

```text
src/components/document/
├── DocumentTree.vue
├── DocumentList.vue
├── DocumentEditor.vue
├── DocumentOutline.vue
├── DocumentMetaPanel.vue
├── DocumentPublishPanel.vue
├── DocumentSearchBox.vue
├── DocumentTagSelector.vue
└── DocumentMoveDialog.vue
```

文档模块应支持：

- 新建文档。
- 编辑文档。
- 保存草稿。
- 自动保存。
- 分类管理。
- 标签管理。
- 文档搜索。
- Markdown 编辑和预览。
- 文章大纲。
- 发布为博客。

当前开发阶段可以先实现最小闭环：

```text
文档列表
新建文档
编辑文档
保存草稿
分类 / 标签
发布入口
```

后续再完善：

```text
目录树拖拽
自动保存
历史版本
协同编辑
导入导出
```

---

### 7.2 博客模块

博客模块负责公开展示和管理已发布内容。

推荐路由：

```text
/blog
/blog/:id
/blog/manage
/blog/editor/:documentId
```

推荐页面：

```text
src/views/blog/
├── BlogListView.vue
├── BlogDetailView.vue
├── BlogManageView.vue
└── BlogPublishView.vue
```

推荐组件：

```text
src/components/blog/
├── BlogCard.vue
├── BlogToc.vue
├── BlogMetaInfo.vue
├── BlogTagList.vue
├── BlogPublishPanel.vue
└── BlogStatusBadge.vue
```

博客模块重点：

- 博客列表。
- 博客详情。
- 标签筛选。
- 搜索。
- 博客管理。
- 从文档发布。
- 公开阅读展示。
- 后续点赞、收藏、评论。

博客编辑能力应尽量复用文档模块的 Markdown 编辑器，而不是再做一套编辑器。

---

### 7.3 OJ / 代码编辑模块

OJ 模块负责在线刷题和代码提交。

推荐路由：

```text
/oj/problems
/oj/problems/:id
/oj/submissions
/oj/submissions/:id
/oj/rank
```

推荐页面：

```text
src/views/oj/
├── OjProblemListView.vue
├── OjProblemDetailView.vue
├── OjSubmissionListView.vue
├── OjSubmissionDetailView.vue
└── OjRankView.vue
```

推荐组件：

```text
src/components/oj/
├── OjProblemDescription.vue
├── OjCodeEditorPanel.vue
├── OjEditorToolbar.vue
├── OjTestCasePanel.vue
├── OjSubmitResultPanel.vue
└── OjSubmissionStatus.vue
```

通用代码编辑器应放在：

```text
src/components/code/
└── CodeEditor.vue
```

OJ 模块重点：

- 题目列表。
- 题目详情。
- 语言选择。
- 代码模板。
- 代码编辑。
- 运行测试。
- 提交判题。
- 结果展示。
- 提交记录。
- 代码草稿缓存。

---

## 8. 公共组件抽象方向

后续重构时，优先抽离以下公共组件。

### 8.1 MarkdownEditor

路径建议：

```text
src/components/markdown/MarkdownEditor.vue
```

职责：

- Markdown 编辑。
- 实时预览。
- 图片上传。
- 全屏编辑。
- 主题切换。
- 内容双向绑定。

使用场景：

- 文档编辑。
- 博客发布。
- 后续课程内容编辑。

---

### 8.2 MarkdownRenderer

路径建议：

```text
src/components/markdown/MarkdownRenderer.vue
```

职责：

- Markdown 内容渲染。
- 代码块高亮。
- 数学公式渲染。
- XSS 过滤。
- 标题锚点。
- 文章目录生成。

使用场景：

- 博客详情。
- 文档阅读。
- OJ 题目描述。
- 课程内容展示。

---

### 8.3 CodeEditor

路径建议：

```text
src/components/code/CodeEditor.vue
```

职责：

- Monaco Editor 封装。
- 代码内容绑定。
- 语言切换。
- 主题切换。
- 字体大小。
- 自动布局。
- 常用快捷键。

使用场景：

- OJ 刷题。
- 在线代码演示。
- 文档代码片段编辑。
- 课程实验。

---

### 8.4 SplitWorkspace

路径建议：

```text
src/components/common/SplitWorkspace.vue
```

职责：

- 左右分栏。
- 三栏工作台。
- 可拖拽调整宽度。
- 移动端响应式布局。

使用场景：

- 文档工作台。
- OJ 刷题页。
- 后续在线实验页。

---

### 8.5 TagSelector

路径建议：

```text
src/components/common/TagSelector.vue
```

职责：

- 标签选择。
- 标签创建。
- 标签展示。
- 标签颜色统一。

使用场景：

- 文档标签。
- 博客标签。
- 题目标签。

---

## 9. 推荐依赖选型

当前项目可以考虑以下依赖，但所有第三方组件都应封装一层，不要在页面里直接大量使用。

### 9.1 Markdown 编辑器

推荐：

```bash
pnpm add md-editor-v3
```

用于文档和博客编辑。

封装路径：

```text
src/components/markdown/MarkdownEditor.vue
```

---

### 9.2 代码编辑器

推荐：

```bash
pnpm add monaco-editor @guolao/vue-monaco-editor
```

用于 OJ 刷题代码编辑。

封装路径：

```text
src/components/code/CodeEditor.vue
```

---

### 9.3 分栏布局

推荐：

```bash
pnpm add splitpanes
```

用于文档工作台和 OJ 刷题页。

封装路径：

```text
src/components/common/SplitWorkspace.vue
```

---

### 9.4 Markdown 渲染与安全

如果不完全依赖 `md-editor-v3` 的预览渲染，可以考虑：

```bash
pnpm add markdown-it dompurify highlight.js katex
```

用途：

```text
markdown-it：Markdown 转 HTML
dompurify：XSS 清理
highlight.js：代码高亮
katex：数学公式
```

公开博客和文档阅读页必须注意 XSS 风险，不要直接渲染未经处理的 HTML。

---

## 10. 状态管理原则

不要把所有状态都放进 Pinia。应区分全局状态、页面状态和可复用业务状态。

### 10.1 适合放 Pinia 的状态

```text
用户信息
登录状态
全局主题
编辑器偏好设置
OJ 默认语言
当前用户文档分类缓存
```

推荐 store：

```text
src/stores/user.ts
src/stores/editor.ts
src/stores/document.ts
src/stores/oj.ts
```

### 10.2 不适合放 Pinia 的状态

```text
某个表格的 loading
某个弹窗是否打开
某个表单临时输入
某个页面的分页参数
```

这些应优先放在页面组件或 composable 中。

推荐 composable：

```text
useDocumentList.ts
useDocumentEditor.ts
useAutoSave.ts
useCodeDraft.ts
usePagination.ts
```

---

## 11. API 封装原则

页面组件中不应直接写 `axios` 或 `fetch` 请求。

推荐调用链：

```text
页面组件
  ↓
composable / store
  ↓
api 文件
  ↓
request.ts
  ↓
后端接口
```

### 11.1 文档 API

```text
src/api/document.ts
```

推荐函数：

```ts
getDocumentList(params)
getDocumentDetail(id)
createDocument(data)
updateDocument(id, data)
deleteDocument(id)
publishDocument(id, data)
```

### 11.2 博客 API

```text
src/api/blog.ts
```

推荐函数：

```ts
getBlogList(params)
getBlogDetail(id)
getMyBlogList(params)
unpublishBlog(id)
deleteBlog(id)
```

### 11.3 OJ API

```text
src/api/oj.ts
```

推荐函数：

```ts
getProblemList(params)
getProblemDetail(id)
runCode(data)
submitCode(data)
getSubmissionResult(id)
getSubmissionList(params)
```

---

## 12. 类型定义原则

所有接口数据、表单数据、组件 props、事件 emits 都应有 TypeScript 类型。

推荐类型文件：

```text
src/types/document.ts
src/types/blog.ts
src/types/oj.ts
src/types/common.ts
```

示例：

```ts
export type DocumentStatus = 'draft' | 'private' | 'published' | 'archived'

export interface DocumentItem {
  id: number
  title: string
  content: string
  summary?: string
  categoryId?: number
  tags: string[]
  status: DocumentStatus
  createdAt: string
  updatedAt: string
  publishedAt?: string
}

export interface BlogPost {
  id: number
  documentId: number
  title: string
  summary: string
  coverUrl?: string
  tags: string[]
  visible: boolean
  createdAt: string
  updatedAt: string
}
```

---

## 13. 草稿与自动保存设计

文档编辑和 OJ 代码编辑都必须考虑草稿保存。

### 13.1 文档草稿

推荐 key：

```text
document:draft:{documentId}
```

保存内容：

```text
标题
内容
标签
分类
最后编辑时间
```

### 13.2 OJ 代码草稿

推荐 key：

```text
oj:draft:{problemId}:{language}
```

保存内容：

```text
题目 ID
语言
代码内容
最后编辑时间
```

推荐封装：

```text
src/utils/storage.ts
src/utils/codeDraftStorage.ts
src/composables/useAutoSave.ts
```

不要在业务页面中散落使用：

```ts
localStorage.setItem(...)
localStorage.getItem(...)
```

这样做的好处是：

- 便于统一过期策略。
- 便于统一异常处理。
- 便于未来适配移动端、鸿蒙 ArkWeb 或其他存储方式。

---

## 14. 样式与视觉统一

博客、文档、OJ 虽然业务不同，但设计语言应统一。

需要统一的内容：

```text
页面最大宽度
卡片圆角
按钮风格
标签样式
空状态
错误状态
Loading 状态
Markdown 内容样式
代码块样式
编辑器主题
响应式布局
```

尤其是 Markdown 内容展示，不要在多个模块重复写不同样式。

推荐统一文件：

```text
src/styles/markdown.css
```

使用场景：

```text
BlogDetailView.vue
DocumentReadView.vue
OjProblemDescription.vue
MarkdownRenderer.vue
```

---

## 15. 响应式与跨端考虑

后续项目可能适配移动端或 HarmonyOS ArkWeb，因此前端开发时应避免和浏览器环境强耦合。

建议：

- 不要在业务组件中大量直接使用 `window`、`document`、`localStorage`、`sessionStorage`。
- 本地存储统一走 `src/utils/storage.ts`。
- 文件上传、下载、预览、外链打开应统一封装。
- 页面跳转统一使用 Vue Router 或项目导航工具。
- 不要依赖 hover 才能使用核心功能。
- 表格页面移动端应考虑卡片化或横向滚动。
- 编辑器页面移动端应考虑上下布局，而不是强制左右分屏。

---

## 16. 当前文档模块开发建议

当前阶段优先完成文档模块功能，不要同时做大范围重构。

推荐开发范围：

```text
1. 文档列表
2. 新建文档
3. 编辑文档
4. Markdown 编辑器
5. 保存草稿
6. 分类 / 标签
7. 文档阅读页
8. 发布为博客入口
```

当前阶段可以暂时接受部分局部实现，例如：

- 文档组件暂时放在 `components/document`。
- 文档页面暂时放在 `views/document`。
- Markdown 编辑器可以先局部接入。
- 自动保存可以先做基础版。
- 发布博客可以先预留入口或 mock 逻辑。

但需要避免：

- 在页面中直接写大量请求逻辑。
- 在页面中直接写大量 `localStorage`。
- 在文档模块里写死博客模块逻辑。
- 在多个地方重复写 Markdown 渲染样式。
- 文档模块和博客模块各自维护一套完全不同的编辑器。

---

## 17. 文档模块完成后的重构计划

文档模块功能完成并提交 PR 后，建议再开一个专门的重构分支。

推荐分支名：

```text
refactor/frontend-editor-architecture
```

或者：

```text
refactor/frontend-content-architecture
```

重构目标：

```text
1. 抽离 MarkdownEditor。
2. 抽离 MarkdownRenderer。
3. 抽离 CodeEditor。
4. 抽离 SplitWorkspace。
5. 抽离 TagSelector。
6. 统一文档和博客的内容类型。
7. 统一 Markdown 样式。
8. 统一草稿保存逻辑。
9. 整理 router modules。
10. 整理 api、types、composables。
```

重构时要遵守：

```text
不要改业务功能。
不要改变接口行为。
不要大幅调整 UI 表现。
每次重构尽量保持小步提交。
每个提交都能通过 lint/build。
```

---

## 18. 给 Codex 的执行要求

后续让 Codex 重构时，应遵守以下要求。

### 18.1 重构前必须先阅读

Codex 在重构前必须先阅读：

```text
package.json
src/router
src/views/blog
src/views/document
src/views/oj
src/components
src/api
src/types
src/stores
src/composables
```

并先输出：

```text
当前结构总结
重复代码位置
可抽离公共组件
重构风险
建议修改文件列表
```

在用户确认前，不要直接修改代码。

---

### 18.2 重构时必须小步进行

禁止一次性重构整个前端。

推荐顺序：

```text
第一步：抽离 MarkdownRenderer
第二步：抽离 MarkdownEditor
第三步：抽离 CodeEditor
第四步：抽离 SplitWorkspace
第五步：统一 styles/markdown.css
第六步：整理 document/blog 类型
第七步：整理 api 和 composables
第八步：整理 router modules
```

每一步都应：

```text
修改少量文件
说明修改原因
运行 type-check / lint / build
保留原有功能
```

---

### 18.3 Codex 不应做的事

Codex 重构时不要：

- 不经确认新增大量依赖。
- 不经确认删除已有页面。
- 不经确认修改后端接口路径。
- 不经确认改变路由地址。
- 不经确认大幅改变 UI 视觉。
- 把所有状态塞到 Pinia。
- 在组件中直接写 axios。
- 在业务组件中散落 localStorage。
- 直接提交真实 Token、API Key 或 `.env` 文件。

---

## 19. 建议写入 AGENTS.md 的摘要

可以把以下内容加入 `AGENTS.md`，作为 Codex 长期遵守的规则：

```md
## Frontend Architecture Principles

The frontend includes blog, document, and OJ/code editor modules. They should not be treated as isolated pages.

Core principles:

- Document and blog belong to the same content system. Document is private writing and knowledge organization; BlogPost is public content published from a Document.
- Code editor should be a reusable platform-level component, not an OJ-only implementation.
- Markdown editing, Markdown rendering, code editing, tag selection, file upload, draft storage, and split workspace layout should be abstracted as shared capabilities.
- Views should compose capabilities; complex logic should be placed in composables, stores, api, types, and utils.
- Do not call axios/fetch directly in Vue pages. Use `src/api`.
- Do not scatter browser APIs such as localStorage/window/document in business components. Use wrappers in `src/utils`.
- Complete feature work first, then refactor in a separate PR.
- During refactoring, make small steps and keep behavior unchanged.
```

---

## 20. 总结

FlowStudy 前端的核心不是简单地实现博客、文档和 OJ 页面，而是逐步形成一个“学习创作与编程训练工作台”。

最终目标是：

```text
文档负责知识沉淀
博客负责内容分享
OJ 负责编程训练
代码编辑器负责实践能力
Markdown 编辑器负责内容创作
公共组件负责统一体验
```

当前开发策略是：

```text
先完成文档模块功能
再提交 PR
再单独创建重构分支
再按公共能力逐步抽离架构
```

这样可以保证：

- 功能优先可用。
- PR 边界清晰。
- Review 更容易。
- 重构风险可控。
- Codex 后续能根据明确文档逐步重构项目。
