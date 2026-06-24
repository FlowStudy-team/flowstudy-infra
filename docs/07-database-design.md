# 07. FlowStudy 数据库设计文档

## 1. 文档目标

本文档定义 FlowStudy 当前 V1 阶段使用的 MySQL 表结构。当前阶段暂不开发 AI 模块，数据库优先支撑：

```text
用户注册登录
教程 / 博客内容展示
题目、测试用例、代码模板
运行代码 run
提交判题 submission
Judge 写回结果
行为埋点预留
```

初始化脚本：

```text
flowstudy-infra/mysql/init/01-init.sql
```

已有旧库迁移脚本：

```text
flowstudy-infra/mysql/migration/
```

## 2. 基本规范

| 项目 | 规范 |
|---|---|
| 数据库名 | `flowstudy` |
| MySQL 版本 | 本地兼容 MySQL 5.7.24+ |
| 字符集 | `utf8mb4` |
| 排序规则 | `utf8mb4_unicode_ci` |
| 存储引擎 | `InnoDB` |
| 主键 | `BIGINT AUTO_INCREMENT` |
| 时间字段 | `created_at`、`updated_at` |
| 逻辑删除 | 主业务表使用 `deleted TINYINT NOT NULL DEFAULT 0` |
| 状态字段 | 使用 `VARCHAR` 保存枚举，便于 MVP 阶段演进 |
| 外键策略 | MVP 不创建物理外键，通过索引和业务代码保证关系 |

## 3. 当前核心模型

内容模型已经从旧的 `article/chapter` 调整为 `tutorial/blog`：

```text
sys_user
   ├── fs_tutorial.author_id
   ├── fs_blog.author_id
   ├── fs_submission.user_id
   └── fs_code_run.user_id

fs_tutorial
   └── fs_blog.tutorial_id 可为空
          └── fs_problem.blog_id
                 ├── fs_problem_testcase.problem_id
                 ├── fs_code_template.problem_id
                 ├── fs_submission.problem_id
                 │      └── fs_judge_case_result.submission_id
                 └── fs_code_run.problem_id
                        └── fs_code_run_case_result.run_id
```

关系说明：

```text
1. tutorial 表示教程，是系统化学习内容集合。
2. blog 表示具体内容单元，可以属于某个 tutorial，也可以独立存在。
3. problem 绑定 blog，不再绑定旧 chapter。
4. submission 是正式提交，使用数据库全部测试点。
5. code_run 是运行按钮，使用前端传入的测试点。
```

## 4. 表清单

| 表名 | 作用 | 阶段 |
|---|---|---|
| `sys_user` | 用户、角色、登录凭证 | V1 |
| `fs_tutorial` | 教程主表 | V1 |
| `fs_blog` | 博客/教程内容表 | V1 |
| `fs_problem` | 题目主表 | V1 |
| `fs_problem_testcase` | 样例和隐藏测试点 | V1 |
| `fs_code_template` | 代码模板和 Judge wrapper | V1 |
| `fs_submission` | 正式提交记录 | V1 |
| `fs_judge_case_result` | 提交测试点结果 | V1 |
| `fs_code_run` | 运行按钮记录 | V1 |
| `fs_code_run_case_result` | 运行测试点结果 | V1 |
| `fs_behavior_event` | 行为埋点预留 | V1/V2 |
| `fs_mq_message_log` | MQ 幂等与排查日志 | V1 |
| `fs_ai_conversation` | AI 会话预留 | V2 |
| `fs_ai_message` | AI 消息预留 | V2 |
| `fs_user_profile` | 学习画像预留 | V3 |
| `fs_learning_note` | 学习笔记预留 | V3 |

## 5. 关键表说明

### 5.1 `sys_user`

保存账号、密码哈希、角色和状态。

关键字段：

| 字段 | 说明 |
|---|---|
| `username` | 用户名 |
| `email` | 邮箱，可为空 |
| `password_hash` | BCrypt 等安全哈希，禁止明文 |
| `role` | `USER` / `ADMIN` |
| `status` | `1` 正常，`0` 禁用 |
| `deleted` | 逻辑删除 |

唯一性：

```text
active_username：未删除用户用户名唯一
active_email：未删除用户邮箱唯一
```

### 5.2 `fs_tutorial`

教程集合表。

关键字段：

| 字段 | 说明 |
|---|---|
| `title` | 教程标题 |
| `summary` | 教程摘要 |
| `cover_url` | 封面 |
| `author_id` | 作者用户 ID |
| `status` | `DRAFT` / `PUBLISHED` / `OFFLINE` |
| `view_count` | 浏览数 |
| `like_count` | 点赞数 |
| `sort_order` | 排序 |

### 5.3 `fs_blog`

博客内容表。它既可以作为教程中的章节，也可以作为独立博客。

关键字段：

| 字段 | 说明 |
|---|---|
| `tutorial_id` | 所属教程 ID；`NULL` 表示独立博客 |
| `title` | 博客标题 |
| `content_md` | Markdown 正文 |
| `summary` | 摘要 |
| `author_id` | 作者用户 ID |
| `sort_order` | 教程内排序 |
| `estimated_minutes` | 预计阅读分钟数 |
| `status` | `DRAFT` / `PUBLISHED` / `OFFLINE` |

设计约定：

```text
1. 教程详情页展示 tutorial 下的 blog 列表。
2. 学习中心可以单独展示独立 blog。
3. blog 正文统一存 Markdown，不存 HTML。
```

### 5.4 `fs_problem`

题目主表。

关键字段：

| 字段 | 说明 |
|---|---|
| `blog_id` | 所属博客 ID |
| `description_md` | Markdown 题面 |
| `difficulty` | `EASY` / `MEDIUM` / `HARD` |
| `support_languages` | 逗号分隔，例如 `java,cpp,go,python` |
| `time_limit_ms` | 时间限制 |
| `memory_limit_mb` | 内存限制 |
| `submit_count` | 提交次数 |
| `accepted_count` | 通过次数 |

注意：

```text
problem 只绑定 blog，不再使用 chapter_id。
```

### 5.5 `fs_problem_testcase`

题目测试点表。

关键字段：

| 字段 | 说明 |
|---|---|
| `problem_id` | 题目 ID |
| `input_text` | 标准输入 |
| `expected_output` | 期望输出 |
| `is_sample` | `1` 样例，`0` 隐藏测试点 |
| `sort_order` | 测试点顺序 |

展示规则：

```text
题目详情接口只返回 is_sample = 1 的测试点。
提交判题使用该题全部未删除测试点。
运行按钮不直接使用隐藏测试点，只使用前端传入测试点。
```

### 5.6 `fs_code_template`

题目语言模板表。

关键字段：

| 字段 | 说明 |
|---|---|
| `problem_id` | 题目 ID |
| `language` | `java` / `cpp` / `go` / `python` |
| `template_code` | 展示给前端的初始代码 |
| `judge_wrapper_code` | LeetCode 模式下 Judge 使用的完整程序模板 |

LeetCode 模式约定：

```text
judge_wrapper_code 中使用 {{USER_CODE}} 占位。
Core 负责把用户代码填入 wrapper。
Judge 只编译最终 code，不理解业务模板。
```

### 5.7 `fs_submission`

正式提交总表。

关键字段：

| 字段 | 说明 |
|---|---|
| `user_id` | 提交用户 |
| `problem_id` | 题目 |
| `language` | 语言 |
| `code` | 用户原始代码 |
| `judge_code` | 发送给 Judge 的完整代码 |
| `submit_mode` | `FULL_PROGRAM` / `TEMPLATE_WRAPPED` |
| `status` | 判题状态 |
| `score` | 分数 |
| `compile_message` | 编译信息 |
| `runtime_message` | 运行信息 |

正式提交流程：

```text
Core 插入 PENDING
-> Core 投递 SUBMISSION 任务
-> Judge 更新 RUNNING
-> Judge 写最终状态和测试点结果
```

### 5.8 `fs_judge_case_result`

正式提交的测试点结果表。

关键字段：

| 字段 | 说明 |
|---|---|
| `submission_id` | 提交 ID |
| `testcase_id` | 数据库测试点 ID |
| `case_index` | 测试点序号 |
| `status` | 测试点状态 |
| `input_text` | 判题输入 |
| `actual_output` | 实际输出 |
| `expected_output` | 期望输出 |
| `error_message` | 错误信息 |

唯一约束：

```text
submission_id + case_index
```

用于防止 Judge 重复消费时重复插入。

### 5.9 `fs_code_run`

运行按钮总表。它不是正式提交，不参与题目通过率统计。

关键字段与 `fs_submission` 基本一致，但没有 `score`。

运行流程：

```text
Core 接收前端 testCases
-> Core 插入 fs_code_run
-> Core 投递 RUN 任务
-> Judge 写 fs_code_run_case_result
-> 前端轮询 runs/{runId}
```

### 5.10 `fs_code_run_case_result`

运行按钮测试点结果表。

与 `fs_judge_case_result` 的区别：

```text
1. 关联 run_id。
2. testcase_id 可以为空，因为用户自定义测试点不一定来自数据库。
3. 可以完整展示 input_text，因为输入来自用户本次运行请求。
```

### 5.11 `fs_behavior_event`

行为埋点表。当前阶段只保留契约和表结构，暂不做复杂 AI 分析。

关键字段：

| 字段 | 说明 |
|---|---|
| `tutorial_id` | 教程 ID |
| `blog_id` | 博客 ID |
| `problem_id` | 题目 ID |
| `submission_id` | 提交 ID |
| `event_type` | 行为类型 |
| `duration_seconds` | 停留时间 |
| `extra_json` | 扩展数据 |

事件命名建议：

```text
TUTORIAL_VIEW
BLOG_VIEW
BLOG_LEAVE
PROBLEM_VIEW
CODE_EDIT
CODE_RUN
CODE_SUBMIT
JUDGE_ERROR_VIEW
```

## 6. 枚举

内容状态：

```text
DRAFT
PUBLISHED
OFFLINE
```

题目难度：

```text
EASY
MEDIUM
HARD
```

运行 / 判题状态：

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

提交模式：

```text
FULL_PROGRAM
TEMPLATE_WRAPPED
```

语言：

```text
java
cpp
go
python
```

## 7. 初始化与迁移

新建本地库：

```bash
mysql -uroot -p < flowstudy-infra/mysql/init/01-init.sql
```

已有旧库先备份：

```bash
mysqldump -uroot -p flowstudy > flowstudy_backup.sql
```

然后按时间顺序执行：

```bash
mysql -uroot -p flowstudy < flowstudy-infra/mysql/migration/20260621-article-chapter-to-tutorial-blog.sql
mysql -uroot -p flowstudy < flowstudy-infra/mysql/migration/20260623-sync-run-and-judge-contract.sql
```

Docker 首次初始化：

```bash
cd flowstudy-infra
docker compose up -d mysql
```

如果已有 volume，`docker-entrypoint-initdb.d` 不会重复执行。需要重建本地测试库时：

```bash
docker compose down -v
docker compose up -d mysql
```

## 8. 注意事项

1. 不要再新增 `fs_article` / `fs_chapter` 业务依赖。
2. 旧表迁移后保留为 `fs_article_legacy` / `fs_chapter_legacy`，确认数据无误后再人工删除。
3. 正式提交和运行按钮必须分表保存，避免运行记录污染提交统计。
4. 隐藏测试点只用于提交判题，不应该在题目详情接口泄露。
5. AI 相关表可以保留为预留表，但当前阶段不开发 AI 业务逻辑。
