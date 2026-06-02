# 07. FlowStudy 数据库设计文档

> 建议位置：`flowstudy-infra/docs/07-database-design.md`  
> 初始化脚本建议位置：`flowstudy-infra/mysql/init/01-init.sql`

## 1. 设计目标

FlowStudy 的数据库主要服务于 `flowstudy-core`，同时为 `flowstudy-judge` 和 `flowstudy-ai` 提供必要的数据沉淀与查询基础。

数据库需要支撑以下业务：

1. 用户注册、登录、权限与用户资料。
2. 技术文章、章节、题目、测试用例和代码模板管理。
3. 用户代码提交记录、判题状态、单测试点结果持久化。
4. 学习行为埋点，为 AI 画像和个性化笔记生成提供原始数据。
5. AI 会话、AI 消息、用户画像、学习笔记等 AI 模块数据沉淀。
6. RabbitMQ 异步消息幂等与消费日志。

## 2. 数据库基本规范

| 项目 | 规范 |
|---|---|
| 数据库名 | `flowstudy` |
| 字符集 | `utf8mb4` |
| 排序规则 | `utf8mb4_unicode_ci` |
| 存储引擎 | `InnoDB` |
| 主键 | `BIGINT AUTO_INCREMENT` |
| 时间字段 | `created_at`、`updated_at` |
| 逻辑删除 | 业务主表统一使用 `deleted TINYINT NOT NULL DEFAULT 0` |
| 状态字段 | 使用 `VARCHAR(32/64)` 保存枚举值，避免早期频繁改表 |
| JSON 字段 | 使用 MySQL `JSON` 类型保存扩展画像、埋点 extra 等半结构化数据 |
| 外键策略 | MVP 阶段不强制创建物理外键，由业务代码和索引保证关系 |

## 3. 表命名规范

| 前缀 | 含义 | 示例 |
|---|---|---|
| `sys_` | 系统基础表 | `sys_user` |
| `fs_` | FlowStudy 业务表 | `fs_article`、`fs_submission` |

## 4. 核心实体关系

```text
sys_user
   ├── fs_article.author_id
   ├── fs_submission.user_id
   ├── fs_behavior_event.user_id
   ├── fs_ai_conversation.user_id
   ├── fs_ai_message.user_id
   ├── fs_user_profile.user_id
   └── fs_learning_note.user_id

fs_article
   └── fs_chapter.article_id
          └── fs_problem.chapter_id
                 ├── fs_problem_testcase.problem_id
                 ├── fs_code_template.problem_id
                 └── fs_submission.problem_id
                          └── fs_judge_case_result.submission_id
```

> 当前脚本默认不强制创建外键约束，而是通过索引和业务代码保证关系正确。这样更适合早期 MVP、测试数据导入、逻辑删除和多服务演进。

## 5. 表清单

| 表名 | 作用 | 所属模块 | MVP 优先级 |
|---|---|---|---|
| `sys_user` | 用户、角色、账号状态 | auth / user | P0 |
| `fs_article` | 文章主表 | article | P0 |
| `fs_chapter` | 文章章节表 | chapter | P0 |
| `fs_problem` | 题目主表 | problem | P0 |
| `fs_problem_testcase` | 题目测试用例表 | problem / judge | P0 |
| `fs_code_template` | 题目代码模板表 | problem | P0 |
| `fs_submission` | 用户代码提交记录 | submission | P0 |
| `fs_judge_case_result` | 单测试点判题结果 | submission / judge | P0 |
| `fs_behavior_event` | 用户学习行为埋点 | tracking | P1 |
| `fs_ai_conversation` | AI 会话表 | ai | P2 |
| `fs_ai_message` | AI 消息表 | ai | P2 |
| `fs_user_profile` | 用户学习画像表 | ai / profile | P2 |
| `fs_learning_note` | AI / 手动学习笔记 | note | P2 |
| `fs_mq_message_log` | MQ 消息幂等与消费日志 | mq | P1 |

---

## 6. 数据库表详情

### 6.1 `sys_user` 用户表

**用途**：保存平台用户账号、登录凭证、角色和账号状态。用于注册、登录、JWT 鉴权、权限判断和用户资料展示。

**主要关系**：

- `sys_user.id` 可关联 `fs_submission.user_id`、`fs_behavior_event.user_id`、`fs_ai_conversation.user_id`、`fs_user_profile.user_id` 等。
- MVP 阶段不建立物理外键，由业务代码保证用户存在性。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 用户 ID，主键 |
| `username` | `VARCHAR(64)` | 否 | 无 | 用户名，登录标识之一 |
| `email` | `VARCHAR(128)` | 是 | `NULL` | 邮箱，登录标识之一，可选 |
| `password_hash` | `VARCHAR(255)` | 否 | 无 | 密码哈希，禁止明文存储，建议 BCrypt |
| `nickname` | `VARCHAR(64)` | 是 | `NULL` | 用户昵称 |
| `avatar_url` | `VARCHAR(512)` | 是 | `NULL` | 用户头像 URL |
| `role` | `VARCHAR(32)` | 否 | `USER` | 用户角色：`USER` / `ADMIN` |
| `status` | `TINYINT` | 否 | `1` | 账号状态：`1` 正常，`0` 禁用 |
| `last_login_at` | `DATETIME` | 是 | `NULL` | 最近登录时间 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除：`0` 未删除，`1` 已删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 用户主键 |
| `uk_sys_user_username` | `username` | 唯一索引 | 防止用户名重复 |
| `uk_sys_user_email` | `email` | 唯一索引 | 防止邮箱重复；MySQL 允许多个 `NULL` |
| `idx_sys_user_role` | `role` | 普通索引 | 按角色筛选用户 |
| `idx_sys_user_status` | `status` | 普通索引 | 按账号状态筛选 |

**开发注意事项**：

- 注册时必须校验 `username` 和 `email` 唯一性。
- 返回给前端的 VO 中绝不能包含 `password_hash`。
- 登录成功后建议更新 `last_login_at`。
- 管理员接口需要基于 `role` 进行权限判断。

---

### 6.2 `fs_article` 文章表

**用途**：保存技术文章的基本信息。文章是 FlowStudy 学习内容的一级入口。

**主要关系**：

- `fs_article.author_id` 对应 `sys_user.id`。
- `fs_article.id` 被 `fs_chapter.article_id` 引用。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 文章 ID，主键 |
| `title` | `VARCHAR(255)` | 否 | 无 | 文章标题 |
| `summary` | `VARCHAR(512)` | 是 | `NULL` | 文章摘要，用于列表页展示 |
| `cover_url` | `VARCHAR(512)` | 是 | `NULL` | 封面图 URL |
| `author_id` | `BIGINT` | 是 | `NULL` | 作者用户 ID |
| `status` | `VARCHAR(32)` | 否 | `DRAFT` | 状态：`DRAFT` / `PUBLISHED` / `OFFLINE` |
| `view_count` | `BIGINT` | 否 | `0` | 浏览次数 |
| `like_count` | `BIGINT` | 否 | `0` | 点赞次数 |
| `sort_order` | `INT` | 否 | `0` | 排序值，越小越靠前 |
| `published_at` | `DATETIME` | 是 | `NULL` | 发布时间 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 文章主键 |
| `idx_fs_article_author_id` | `author_id` | 普通索引 | 查询作者发布的文章 |
| `idx_fs_article_status` | `status` | 普通索引 | 查询已发布文章 |
| `idx_fs_article_sort_order` | `sort_order` | 普通索引 | 首页或列表排序 |
| `idx_fs_article_created_at` | `created_at` | 普通索引 | 时间倒序列表 |

**开发注意事项**：

- 普通用户接口默认只查询 `status = PUBLISHED` 且 `deleted = 0` 的文章。
- 管理后台可查询 `DRAFT`、`OFFLINE` 状态。
- `view_count` 早期可简单自增，后期可使用 Redis 缓冲后异步落库。

---

### 6.3 `fs_chapter` 章节表

**用途**：保存文章下的章节内容，正文使用 Markdown 存储。

**主要关系**：

- `fs_chapter.article_id` 对应 `fs_article.id`。
- `fs_chapter.id` 被 `fs_problem.chapter_id` 引用。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 章节 ID，主键 |
| `article_id` | `BIGINT` | 否 | 无 | 所属文章 ID |
| `title` | `VARCHAR(255)` | 否 | 无 | 章节标题 |
| `content_md` | `MEDIUMTEXT` | 否 | 无 | Markdown 章节内容 |
| `sort_order` | `INT` | 否 | `0` | 章节排序 |
| `estimated_minutes` | `INT` | 是 | `NULL` | 预计学习分钟数 |
| `status` | `VARCHAR(32)` | 否 | `PUBLISHED` | 状态：`DRAFT` / `PUBLISHED` / `OFFLINE` |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 章节主键 |
| `idx_fs_chapter_article_id` | `article_id` | 普通索引 | 查询某文章下章节 |
| `idx_fs_chapter_status` | `status` | 普通索引 | 筛选已发布章节 |
| `idx_fs_chapter_sort_order` | `sort_order` | 普通索引 | 章节排序 |

**开发注意事项**：

- 查询文章详情时通常需要同时查询章节列表，但不一定返回 `content_md` 全文。
- 查询章节详情时才返回 `content_md`。
- AI 上下文接口会读取当前章节内容，因此字段长度使用 `MEDIUMTEXT`。

---

### 6.4 `fs_problem` 题目表

**用途**：保存章节绑定的练习题基本信息，包括题面、难度、支持语言、时间限制和内存限制。

**主要关系**：

- `fs_problem.chapter_id` 对应 `fs_chapter.id`。
- `fs_problem.id` 被 `fs_problem_testcase.problem_id`、`fs_code_template.problem_id`、`fs_submission.problem_id` 引用。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 题目 ID，主键 |
| `chapter_id` | `BIGINT` | 否 | 无 | 所属章节 ID |
| `title` | `VARCHAR(255)` | 否 | 无 | 题目标题 |
| `description_md` | `MEDIUMTEXT` | 否 | 无 | Markdown 题目描述 |
| `difficulty` | `VARCHAR(32)` | 否 | `EASY` | 难度：`EASY` / `MEDIUM` / `HARD` |
| `input_description` | `TEXT` | 是 | `NULL` | 输入说明 |
| `output_description` | `TEXT` | 是 | `NULL` | 输出说明 |
| `support_languages` | `VARCHAR(255)` | 否 | `java,cpp,go,python` | 支持语言，逗号分隔 |
| `time_limit_ms` | `INT` | 否 | `1000` | 时间限制，毫秒 |
| `memory_limit_mb` | `INT` | 否 | `256` | 内存限制，MB |
| `status` | `VARCHAR(32)` | 否 | `PUBLISHED` | 状态：`DRAFT` / `PUBLISHED` / `OFFLINE` |
| `submit_count` | `BIGINT` | 否 | `0` | 提交次数 |
| `accepted_count` | `BIGINT` | 否 | `0` | 通过次数 |
| `sort_order` | `INT` | 否 | `0` | 题目排序 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 题目主键 |
| `idx_fs_problem_chapter_id` | `chapter_id` | 普通索引 | 查询某章节题目 |
| `idx_fs_problem_difficulty` | `difficulty` | 普通索引 | 按难度筛选 |
| `idx_fs_problem_status` | `status` | 普通索引 | 筛选已发布题目 |
| `idx_fs_problem_sort_order` | `sort_order` | 普通索引 | 题目排序 |

**开发注意事项**：

- 普通用户只能看到 `PUBLISHED` 且 `deleted = 0` 的题目。
- `support_languages` MVP 阶段可用逗号分隔字符串；后期如需更强查询能力，可拆成题目语言关联表。
- `submit_count`、`accepted_count` 可由提交结果消费流程异步更新。

---

### 6.5 `fs_problem_testcase` 题目测试用例表

**用途**：保存题目的样例测试点和隐藏测试点。用于题目展示和 Judge 判题。

**主要关系**：

- `fs_problem_testcase.problem_id` 对应 `fs_problem.id`。
- `fs_judge_case_result.testcase_id` 可对应 `fs_problem_testcase.id`。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 测试用例 ID，主键 |
| `problem_id` | `BIGINT` | 否 | 无 | 所属题目 ID |
| `input_text` | `MEDIUMTEXT` | 否 | 无 | 输入内容 |
| `expected_output` | `MEDIUMTEXT` | 否 | 无 | 期望输出 |
| `is_sample` | `TINYINT` | 否 | `0` | 是否样例：`1` 样例，`0` 隐藏测试点 |
| `sort_order` | `INT` | 否 | `0` | 测试点排序 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 测试用例主键 |
| `idx_fs_problem_testcase_problem_id` | `problem_id` | 普通索引 | 查询某题全部测试点 |
| `idx_fs_problem_testcase_sample` | `problem_id, is_sample` | 组合索引 | 查询某题样例测试点 |
| `idx_fs_problem_testcase_sort_order` | `sort_order` | 普通索引 | 测试点排序 |

**开发注意事项**：

- 普通题目详情接口只返回 `is_sample = 1` 的测试点。
- 提交判题时 Core 或 Judge 才能读取隐藏测试点。
- 后期测试点过大时，可迁移到对象存储，数据库只保存 `testcase_set_id` 或文件引用。

---

### 6.6 `fs_code_template` 题目代码模板表

**用途**：保存某题在不同语言下的初始代码模板，用于前端 Monaco Editor 初始化。

**主要关系**：

- `fs_code_template.problem_id` 对应 `fs_problem.id`。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 代码模板 ID，主键 |
| `problem_id` | `BIGINT` | 否 | 无 | 所属题目 ID |
| `language` | `VARCHAR(32)` | 否 | 无 | 语言：`java` / `cpp` / `go` / `python` |
| `template_code` | `MEDIUMTEXT` | 否 | 无 | 代码模板内容 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 模板主键 |
| `uk_fs_code_template_problem_language` | `problem_id, language` | 唯一索引 | 同一题目同一语言只能有一个模板 |
| `idx_fs_code_template_problem_id` | `problem_id` | 普通索引 | 查询某题所有语言模板 |

**开发注意事项**：

- `GET /api/v1/problems/{problemId}/template?language=java` 应使用该表查询。
- 如果某题没有配置模板，可以由后端返回语言默认模板。

---

### 6.7 `fs_submission` 代码提交记录表

**用途**：保存用户每一次代码提交的总体信息和最终判题状态。

**主要关系**：

- `fs_submission.user_id` 对应 `sys_user.id`。
- `fs_submission.problem_id` 对应 `fs_problem.id`。
- `fs_submission.id` 被 `fs_judge_case_result.submission_id` 引用。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 提交 ID，主键 |
| `user_id` | `BIGINT` | 否 | 无 | 提交用户 ID |
| `problem_id` | `BIGINT` | 否 | 无 | 题目 ID |
| `language` | `VARCHAR(32)` | 否 | 无 | 提交语言 |
| `code` | `MEDIUMTEXT` | 否 | 无 | 用户提交代码 |
| `status` | `VARCHAR(64)` | 否 | `PENDING` | 判题状态 |
| `score` | `INT` | 否 | `0` | 得分 |
| `time_used_ms` | `INT` | 是 | `NULL` | 最大或总运行耗时，毫秒 |
| `memory_used_kb` | `INT` | 是 | `NULL` | 最大内存占用，KB |
| `compile_message` | `MEDIUMTEXT` | 是 | `NULL` | 编译信息 |
| `runtime_message` | `MEDIUMTEXT` | 是 | `NULL` | 运行错误信息 |
| `trace_id` | `VARCHAR(64)` | 是 | `NULL` | 链路追踪 ID |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 提交主键 |
| `idx_fs_submission_user_id` | `user_id` | 普通索引 | 查询用户提交记录 |
| `idx_fs_submission_problem_id` | `problem_id` | 普通索引 | 查询题目提交记录 |
| `idx_fs_submission_status` | `status` | 普通索引 | 查询待判题或异常提交 |
| `idx_fs_submission_created_at` | `created_at` | 普通索引 | 提交时间排序 |
| `idx_fs_submission_user_created` | `user_id, created_at` | 组合索引 | 用户提交列表倒序查询 |
| `idx_fs_submission_problem_created` | `problem_id, created_at` | 组合索引 | 题目提交列表倒序查询 |
| `idx_fs_submission_trace_id` | `trace_id` | 普通索引 | 链路排查 |

**开发注意事项**：

- 用户提交代码时先插入 `PENDING` 状态。
- Core 不运行代码，只负责投递 `judge.submit.created` 消息。
- Judge 回传结果后由 Core 消费消息并更新该表。
- `COMPILE_ERROR` 是用户代码错误，不应映射为系统异常错误码。

---

### 6.8 `fs_judge_case_result` 单测试点判题结果表

**用途**：保存一次提交中每个测试点的运行结果，用于提交详情展示和问题排查。

**主要关系**：

- `fs_judge_case_result.submission_id` 对应 `fs_submission.id`。
- `fs_judge_case_result.testcase_id` 可对应 `fs_problem_testcase.id`。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 测试点结果 ID，主键 |
| `submission_id` | `BIGINT` | 否 | 无 | 提交 ID |
| `testcase_id` | `BIGINT` | 是 | `NULL` | 测试用例 ID |
| `case_index` | `INT` | 否 | 无 | 测试点序号，从 1 开始 |
| `status` | `VARCHAR(64)` | 否 | 无 | 测试点状态 |
| `time_used_ms` | `INT` | 是 | `NULL` | 耗时，毫秒 |
| `memory_used_kb` | `INT` | 是 | `NULL` | 内存占用，KB |
| `actual_output` | `MEDIUMTEXT` | 是 | `NULL` | 实际输出 |
| `expected_output` | `MEDIUMTEXT` | 是 | `NULL` | 期望输出 |
| `error_message` | `MEDIUMTEXT` | 是 | `NULL` | 错误信息 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 测试点结果主键 |
| `uk_fs_judge_case_submission_index` | `submission_id, case_index` | 唯一索引 | 保证同一次提交同一测试点只写一次，支持幂等 |
| `idx_fs_judge_case_submission_id` | `submission_id` | 普通索引 | 查询一次提交的所有测试点 |
| `idx_fs_judge_case_status` | `status` | 普通索引 | 筛选异常测试点 |

**开发注意事项**：

- 消费 Judge 结果时必须考虑 RabbitMQ 重复投递。
- 唯一索引 `submission_id + case_index` 可避免重复插入同一测试点。
- 对隐藏测试点，前端可不展示完整 `expected_output`，避免泄露答案。

---

### 6.9 `fs_behavior_event` 用户行为事件表

**用途**：保存用户学习过程中的原始行为事件，为 AI 画像、学习笔记和学习报告提供数据基础。

**主要关系**：

- `user_id` 对应 `sys_user.id`。
- 可选关联 `article_id`、`chapter_id`、`problem_id`、`submission_id`。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 行为事件 ID，主键 |
| `user_id` | `BIGINT` | 否 | 无 | 用户 ID |
| `article_id` | `BIGINT` | 是 | `NULL` | 文章 ID |
| `chapter_id` | `BIGINT` | 是 | `NULL` | 章节 ID |
| `problem_id` | `BIGINT` | 是 | `NULL` | 题目 ID |
| `submission_id` | `BIGINT` | 是 | `NULL` | 提交 ID |
| `event_type` | `VARCHAR(64)` | 否 | 无 | 事件类型 |
| `duration_seconds` | `INT` | 是 | `NULL` | 停留时长，秒 |
| `extra_json` | `JSON` | 是 | `NULL` | 扩展信息，例如滚动比例、编辑次数、错误类型 |
| `trace_id` | `VARCHAR(64)` | 是 | `NULL` | 链路追踪 ID |
| `occurred_at` | `DATETIME` | 否 | 无 | 事件发生时间，由前端或 Core 写入 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 入库时间 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 事件主键 |
| `idx_fs_behavior_user_id` | `user_id` | 普通索引 | 查询用户行为 |
| `idx_fs_behavior_event_type` | `event_type` | 普通索引 | 按事件类型统计 |
| `idx_fs_behavior_article_chapter` | `article_id, chapter_id` | 组合索引 | 统计文章/章节学习行为 |
| `idx_fs_behavior_problem_id` | `problem_id` | 普通索引 | 统计题目行为 |
| `idx_fs_behavior_submission_id` | `submission_id` | 普通索引 | 关联提交行为 |
| `idx_fs_behavior_occurred_at` | `occurred_at` | 普通索引 | 按时间范围分析 |
| `idx_fs_behavior_trace_id` | `trace_id` | 普通索引 | 链路排查 |

**开发注意事项**：

- 埋点接口建议支持批量上报，降低请求次数。
- 原始行为表后期数据量会很大，可考虑按月分表或迁移到 ClickHouse。
- Core 收到埋点后可同步入库，再异步投递 `behavior.*` 消息给 AI 服务。

---

### 6.10 `fs_ai_conversation` AI 会话表

**用途**：保存 AI 侧边栏会话的基本信息，用于会话列表、上下文关联和历史记录管理。

**主要关系**：

- `user_id` 对应 `sys_user.id`。
- 可选关联 `article_id`、`chapter_id`、`problem_id`，表示该会话发生在哪个学习上下文。
- `fs_ai_conversation.id` 被 `fs_ai_message.conversation_id` 引用。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | AI 会话 ID，主键 |
| `user_id` | `BIGINT` | 否 | 无 | 用户 ID |
| `article_id` | `BIGINT` | 是 | `NULL` | 关联文章 ID |
| `chapter_id` | `BIGINT` | 是 | `NULL` | 关联章节 ID |
| `problem_id` | `BIGINT` | 是 | `NULL` | 关联题目 ID |
| `title` | `VARCHAR(255)` | 是 | `NULL` | 会话标题，可由首条问题生成 |
| `status` | `VARCHAR(32)` | 否 | `ACTIVE` | 状态：`ACTIVE` / `ARCHIVED` |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 会话主键 |
| `idx_fs_ai_conversation_user_id` | `user_id` | 普通索引 | 查询用户会话列表 |
| `idx_fs_ai_conversation_context` | `article_id, chapter_id, problem_id` | 组合索引 | 查询某学习上下文下的会话 |
| `idx_fs_ai_conversation_created_at` | `created_at` | 普通索引 | 按创建时间排序 |

**开发注意事项**：

- 同一用户可以在不同章节或题目下创建多个 AI 会话。
- 删除会话建议逻辑删除，保留后续画像分析能力。

---

### 6.11 `fs_ai_message` AI 消息表

**用途**：保存 AI 会话中的每一条消息，包括用户问题、AI 回答和系统提示。

**主要关系**：

- `conversation_id` 对应 `fs_ai_conversation.id`。
- `user_id` 对应 `sys_user.id`。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | AI 消息 ID，主键 |
| `conversation_id` | `BIGINT` | 否 | 无 | 会话 ID |
| `user_id` | `BIGINT` | 否 | 无 | 用户 ID |
| `role` | `VARCHAR(32)` | 否 | 无 | 角色：`user` / `assistant` / `system` |
| `content` | `MEDIUMTEXT` | 否 | 无 | 消息内容 |
| `model_name` | `VARCHAR(128)` | 是 | `NULL` | 使用的模型名称 |
| `token_count` | `INT` | 是 | `NULL` | 消耗 Token 数量 |
| `trace_id` | `VARCHAR(64)` | 是 | `NULL` | 链路追踪 ID |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 消息主键 |
| `idx_fs_ai_message_conversation_id` | `conversation_id` | 普通索引 | 查询会话消息 |
| `idx_fs_ai_message_user_id` | `user_id` | 普通索引 | 查询用户 AI 交互历史 |
| `idx_fs_ai_message_created_at` | `created_at` | 普通索引 | 消息时间排序 |
| `idx_fs_ai_message_trace_id` | `trace_id` | 普通索引 | 链路排查 |

**开发注意事项**：

- SSE 流式回答结束后再持久化完整 assistant 消息。
- 不建议把所有历史消息都塞入 Prompt，应由 AI 服务做摘要与检索。
- 可定期将长对话摘要写入用户画像或学习记忆表。

---

### 6.12 `fs_user_profile` 用户学习画像表

**用途**：保存 AI 从用户行为、代码提交和问答历史中提炼出的结构化学习画像。

**主要关系**：

- `user_id` 对应 `sys_user.id`。
- 每个用户最多一条画像记录。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 画像 ID，主键 |
| `user_id` | `BIGINT` | 否 | 无 | 用户 ID |
| `ability_json` | `JSON` | 是 | `NULL` | 能力画像，例如知识点掌握程度 |
| `weak_points_json` | `JSON` | 是 | `NULL` | 易错点，例如数组越界、空指针、循环边界 |
| `coding_style_json` | `JSON` | 是 | `NULL` | 代码风格，例如命名习惯、语言偏好 |
| `summary_md` | `MEDIUMTEXT` | 是 | `NULL` | 画像摘要 Markdown，便于展示或拼 Prompt |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 画像主键 |
| `uk_fs_user_profile_user_id` | `user_id` | 唯一索引 | 每个用户最多一条画像 |

**开发注意事项**：

- 画像更新建议异步执行，不应阻塞用户提交代码或 AI 问答。
- `summary_md` 可以作为长期记忆摘要，AI 问答时优先加载。
- 原始行为仍保留在 `fs_behavior_event`，画像表只保存提炼结果。

---

### 6.13 `fs_learning_note` 学习笔记表

**用途**：保存 AI 自动生成或用户手动编辑的学习笔记。

**主要关系**：

- `user_id` 对应 `sys_user.id`。
- 可选关联 `article_id`、`chapter_id`，表示笔记来源。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | 学习笔记 ID，主键 |
| `user_id` | `BIGINT` | 否 | 无 | 用户 ID |
| `article_id` | `BIGINT` | 是 | `NULL` | 关联文章 ID |
| `chapter_id` | `BIGINT` | 是 | `NULL` | 关联章节 ID |
| `title` | `VARCHAR(255)` | 否 | 无 | 笔记标题 |
| `content_md` | `MEDIUMTEXT` | 否 | 无 | Markdown 笔记内容 |
| `source` | `VARCHAR(32)` | 否 | `AI` | 来源：`AI` / `MANUAL` |
| `status` | `VARCHAR(32)` | 否 | `GENERATED` | 状态：`GENERATED` / `EDITED` / `ARCHIVED` |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |
| `deleted` | `TINYINT` | 否 | `0` | 逻辑删除 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 笔记主键 |
| `idx_fs_learning_note_user_id` | `user_id` | 普通索引 | 查询用户笔记列表 |
| `idx_fs_learning_note_article_chapter` | `article_id, chapter_id` | 组合索引 | 查询某文章/章节笔记 |
| `idx_fs_learning_note_created_at` | `created_at` | 普通索引 | 按创建时间排序 |

**开发注意事项**：

- AI 生成笔记建议先创建任务，再异步写入该表。
- 用户编辑 AI 笔记后可以将 `status` 更新为 `EDITED`。
- 删除笔记建议逻辑删除，避免误删用户学习资产。

---

### 6.14 `fs_mq_message_log` MQ 消息幂等与消费日志表

**用途**：记录 RabbitMQ 消息处理状态，用于幂等控制、失败重试和问题排查。

**主要关系**：

- 与具体业务表无强关联，核心字段是 `message_id` 和 `trace_id`。
- 可用于 Judge 结果消费、行为事件消费、AI 笔记任务消费等场景。

| 字段 | 类型 | 是否为空 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `BIGINT` | 否 | 自增 | MQ 日志 ID，主键 |
| `message_id` | `VARCHAR(128)` | 否 | 无 | 消息唯一 ID，用于幂等 |
| `trace_id` | `VARCHAR(64)` | 是 | `NULL` | 链路追踪 ID |
| `event_type` | `VARCHAR(128)` | 否 | 无 | 事件类型，例如 `judge.result.finished` |
| `producer` | `VARCHAR(64)` | 是 | `NULL` | 生产者服务 |
| `consumer` | `VARCHAR(64)` | 是 | `NULL` | 消费者服务 |
| `exchange_name` | `VARCHAR(128)` | 是 | `NULL` | RabbitMQ 交换机 |
| `routing_key` | `VARCHAR(128)` | 是 | `NULL` | 路由键 |
| `status` | `VARCHAR(32)` | 否 | `PENDING` | 状态：`PENDING` / `PROCESSED` / `FAILED` / `IGNORED` |
| `retry_count` | `INT` | 否 | `0` | 重试次数 |
| `error_message` | `MEDIUMTEXT` | 是 | `NULL` | 处理失败错误信息 |
| `payload_json` | `JSON` | 是 | `NULL` | 消息载荷快照 |
| `occurred_at` | `DATETIME` | 是 | `NULL` | 消息发生时间 |
| `processed_at` | `DATETIME` | 是 | `NULL` | 处理完成时间 |
| `created_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP` | 创建时间 |
| `updated_at` | `DATETIME` | 否 | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | 更新时间 |

**索引与约束**：

| 索引名 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `PRIMARY` | `id` | 主键 | 日志主键 |
| `uk_fs_mq_message_log_message_id` | `message_id` | 唯一索引 | 保证消息幂等 |
| `idx_fs_mq_message_log_trace_id` | `trace_id` | 普通索引 | 链路排查 |
| `idx_fs_mq_message_log_event_type` | `event_type` | 普通索引 | 按事件类型查询 |
| `idx_fs_mq_message_log_status` | `status` | 普通索引 | 查询失败或待处理消息 |
| `idx_fs_mq_message_log_created_at` | `created_at` | 普通索引 | 按创建时间查询 |

**开发注意事项**：

- 消费消息前可先根据 `message_id` 插入日志，唯一键冲突表示重复消息。
- 消费成功后更新为 `PROCESSED` 并写入 `processed_at`。
- 消费失败后更新为 `FAILED` 并记录 `error_message`，后续可人工或定时任务重试。

---

## 7. 关键枚举建议

### 7.1 用户角色

```text
USER
ADMIN
```

### 7.2 内容状态

```text
DRAFT
PUBLISHED
OFFLINE
```

### 7.3 题目难度

```text
EASY
MEDIUM
HARD
```

### 7.4 判题状态

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

### 7.5 行为事件类型

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

### 7.6 AI 消息角色

```text
user
assistant
system
```

### 7.7 MQ 消息状态

```text
PENDING
PROCESSED
FAILED
IGNORED
```

---

## 8. 重点设计说明

### 8.1 为什么普通用户不能直接看到隐藏测试用例

`fs_problem_testcase` 中通过 `is_sample` 区分样例测试点和隐藏测试点。普通题目详情接口只返回 `is_sample = 1` 的数据；提交判题时，Core 或 Judge 才能读取全部测试用例。

### 8.2 为什么提交记录和测试点结果拆表

`fs_submission` 保存一次提交的总体状态，例如 `ACCEPTED`、`COMPILE_ERROR`、耗时、内存和分数；`fs_judge_case_result` 保存每个测试点的运行结果。这样前端既可以快速展示提交列表，也可以在详情页展示每个测试点。

### 8.3 为什么增加 `fs_code_template`

不同题目、不同语言的初始代码模板不同。使用独立表可以让前端根据 `problemId + language` 获取模板，而不是把模板硬编码在前端。

### 8.4 为什么增加 `fs_mq_message_log`

RabbitMQ 可能出现重复投递。`fs_mq_message_log` 用于记录 `message_id`，保证 Judge 结果消费、行为消息消费等流程具备幂等能力。

### 8.5 为什么 AI 相关表放在数据库中

AI 会话、消息、用户画像和学习笔记是 FlowStudy 的核心创新数据资产。即使 AI 推理在 `flowstudy-ai` 服务中完成，最终结构化数据也应沉淀到数据库，便于用户查看、检索和后续分析。

---

## 9. 索引设计原则

1. 所有外部关联字段都建立普通索引，例如 `user_id`、`article_id`、`chapter_id`、`problem_id`、`submission_id`。
2. 列表查询常用字段建立索引，例如 `status`、`created_at`、`difficulty`。
3. 登录字段建立唯一索引，例如 `username`、`email`。
4. MQ 幂等字段 `message_id` 建立唯一索引。
5. 代码提交列表常用 `(user_id, created_at)`、`(problem_id, created_at)` 组合索引。
6. 不建议盲目给所有字段加索引，长文本字段和 JSON 字段 MVP 阶段不建立索引。

---

## 10. MVP 阶段建议优先落地的表

第一阶段建议先实现以下表：

```text
sys_user
fs_article
fs_chapter
fs_problem
fs_problem_testcase
fs_code_template
fs_submission
fs_judge_case_result
fs_behavior_event
fs_mq_message_log
```

AI 相关表可以先建好但不开发完整业务：

```text
fs_ai_conversation
fs_ai_message
fs_user_profile
fs_learning_note
```

---

## 11. 初始化脚本使用方式

将 `01-init.sql` 放入：

```text
flowstudy-infra/mysql/init/01-init.sql
```

然后在 `docker-compose.yml` 中挂载：

```yaml
volumes:
  - ./mysql/init:/docker-entrypoint-initdb.d
```

首次启动 MySQL：

```bash
docker compose up -d mysql
```

如果已经启动过 MySQL 且 volume 中已有旧数据，初始化脚本不会自动重新执行。需要清空 volume：

```bash
docker compose down -v
docker compose up -d mysql
```

---

## 12. 后续演进建议

1. 后期测试用例数量很大时，可以把隐藏测试用例迁移到对象存储，数据库只保存 `testcase_set_id`。
2. 生产环境中，用户代码和大段判题输出可以考虑归档或限制长度，避免提交表过大。
3. 行为埋点表后期可能非常大，可以按月分表或迁移到 ClickHouse / Elasticsearch。
4. AI 消息表后期可以增加向量索引或同步到向量数据库，用于 RAG 检索。
5. 管理后台上线后，需要增加内容审核、发布记录和操作日志表。
6. 如果后期要做多租户或课程体系，可以增加 `fs_course`、`fs_tag`、`fs_article_tag`、`fs_user_progress` 等表。
