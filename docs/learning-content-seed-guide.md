# FlowStudy 学习内容数据生成规范

本文档用于指导 GPT 或人工批量生成 FlowStudy 的教程、博客、算法题、测试集和代码模板数据，最后产出可直接导入 MySQL 的 SQL 脚本。

目标：快速生成规范、可运行、可展示的站内学习内容。

## 1. 内容关系

FlowStudy 当前学习内容按下面关系组织：

```text
教程 fs_tutorial
  └── 博客 fs_blog
        └── 算法题 fs_problem
              ├── 测试用例 fs_problem_testcase
              └── 代码模板 fs_code_template
```

说明：

- 一个教程可以包含多篇博客。
- 一篇博客可以关联多道算法题。
- 一篇博客也可以是独立博客，此时 `tutorial_id` 填 `NULL`。
- 算法题必须挂在某篇博客下，即 `fs_problem.blog_id` 必填。
- 每道算法题至少要有 1 个样例测试用例和 1 个隐藏测试用例。
- 每道算法题建议提供 `java/cpp/go/python` 四种代码模板。

## 2. 教程写法

教程是一个学习路线或专题集合，不写太长正文，主要用于承载博客目录。

字段要求：

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| `id` | 教程 ID，手动指定，避免冲突 | `1001` |
| `title` | 教程标题 | `Java 集合框架入门` |
| `summary` | 教程摘要，100 字以内 | `系统学习 List、Map、Set 的使用场景和底层原理。` |
| `cover_url` | 封面，可填 `NULL` | `NULL` |
| `author_id` | 作者 ID，官方内容可填 `NULL` | `NULL` |
| `status` | 固定填 `PUBLISHED` | `PUBLISHED` |
| `sort_order` | 排序，越小越靠前 | `1` |
| `published_at` | 发布时间 | `NOW()` |
| `deleted` | 固定填 `0` | `0` |

教程生成要求：

- 标题简洁，像课程名称。
- 摘要说明学习目标。
- 不要复制网络文章正文。
- 如果来自官方资料，可以在博客正文中放来源链接。

示例：

```sql
INSERT INTO fs_tutorial (
    id, title, summary, cover_url, author_id, status,
    view_count, like_count, sort_order, published_at, deleted
) VALUES (
    1001,
    'Java 集合框架入门',
    '系统学习 List、Map、Set 的使用场景、常见操作和底层原理。',
    NULL,
    NULL,
    'PUBLISHED',
    0,
    0,
    1,
    NOW(),
    0
);
```

## 3. 博客写法

博客是具体知识点文章，可以属于某个教程，也可以独立存在。

字段要求：

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| `id` | 博客 ID，手动指定 | `2001` |
| `tutorial_id` | 所属教程 ID；独立博客填 `NULL` | `1001` |
| `title` | 博客标题 | `ArrayList 的基本使用和扩容机制` |
| `content_md` | Markdown 正文 | 见下方模板 |
| `summary` | 摘要，100 字以内 | `介绍 ArrayList 的常用方法和扩容机制。` |
| `cover_url` | 封面，可填 `NULL` | `NULL` |
| `author_id` | 作者 ID，官方内容可填 `NULL` | `NULL` |
| `sort_order` | 教程内排序 | `1` |
| `estimated_minutes` | 阅读分钟数 | `8` |
| `status` | 固定填 `PUBLISHED` | `PUBLISHED` |
| `published_at` | 发布时间 | `NOW()` |
| `deleted` | 固定填 `0` | `0` |

博客正文建议结构：

```md
## 学习目标

- 目标 1
- 目标 2

## 核心概念

用自己的话解释核心知识点。

## 示例

给出简单代码或场景。

## 常见问题

- 问题 1：回答
- 问题 2：回答

## 练习建议

建议读者完成哪些题目。

## 参考资料

- [资料名称](https://example.com)
```

生成要求：

- 正文使用 Markdown。
- 内容尽量原创总结，不要整篇复制网上文章。
- 如果引用外部资料，只放链接和简短说明。
- 每篇博客 300-800 字即可，适合快速填充数据。

示例：

```sql
INSERT INTO fs_blog (
    id, tutorial_id, title, content_md, summary, cover_url, author_id,
    sort_order, estimated_minutes, status, view_count, like_count,
    published_at, deleted
) VALUES (
    2001,
    1001,
    'ArrayList 的基本使用和扩容机制',
    '## 学习目标\n\n- 掌握 ArrayList 的常用操作\n- 理解动态数组扩容的基本思路\n\n## 核心概念\n\nArrayList 底层可以理解为一个动态数组。当元素数量超过当前容量时，会创建更大的数组并迁移旧数据。\n\n## 示例\n\n~~~java\nList<Integer> list = new ArrayList<>();\nlist.add(1);\nlist.add(2);\n~~~\n\n## 常见问题\n\n- ArrayList 查询快吗？按下标查询很快。\n- ArrayList 插入一定快吗？中间插入可能需要移动元素。\n\n## 练习建议\n\n完成一道数组查找或去重题，加深对线性结构的理解。',
    '介绍 ArrayList 的常用方法和动态扩容机制。',
    NULL,
    NULL,
    1,
    8,
    'PUBLISHED',
    0,
    0,
    NOW(),
    0
);
```

## 4. 算法题写法

算法题用于在线判题，必须能通过标准输入输出运行。

字段要求：

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| `id` | 题目 ID，手动指定 | `3001` |
| `blog_id` | 所属博客 ID | `2001` |
| `title` | 题目标题 | `两数之和` |
| `description_md` | Markdown 题面 | 见下方模板 |
| `difficulty` | `EASY/MEDIUM/HARD` | `EASY` |
| `input_description` | 输入说明 | `第一行输入 n...` |
| `output_description` | 输出说明 | `输出两个下标...` |
| `support_languages` | 支持语言，逗号分隔 | `java,cpp,go,python` |
| `time_limit_ms` | 时间限制 | `1000` |
| `memory_limit_mb` | 内存限制 | `256` |
| `status` | 固定填 `PUBLISHED` | `PUBLISHED` |
| `sort_order` | 排序 | `1` |
| `deleted` | 固定填 `0` | `0` |

题面建议结构：

```md
## 题目描述

清晰描述要解决的问题。

## 输入格式

说明每一行输入的含义。

## 输出格式

说明输出内容。

## 样例

输入：

```text
...
```

输出：

```text
...
```

## 数据范围

- 条件 1
- 条件 2
```

算法题生成要求：

- 必须使用标准输入输出。
- 不要写 LeetCode 函数签名题，除非同时提供 wrapper。
- 输入输出必须和测试用例完全一致。
- 输出末尾建议带换行。
- 难度分布建议：70% EASY，25% MEDIUM，5% HARD。

示例：

```sql
INSERT INTO fs_problem (
    id, blog_id, title, description_md, difficulty,
    input_description, output_description, support_languages,
    time_limit_ms, memory_limit_mb, status,
    submit_count, accepted_count, sort_order, deleted
) VALUES (
    3001,
    2001,
    '两数之和',
    '## 题目描述\n\n给定一个整数数组 nums 和一个目标值 target，请找到两个数，使它们的和等于 target。\n\n## 输入格式\n\n第一行输入整数 n。\n第二行输入 n 个整数。\n第三行输入整数 target。\n\n## 输出格式\n\n输出两个下标，使用空格分隔。\n\n## 样例\n\n输入：\n\n~~~text\n4\n2 7 11 15\n9\n~~~\n\n输出：\n\n~~~text\n0 1\n~~~\n\n## 数据范围\n\n- 2 <= n <= 10000\n- 每组数据保证有唯一答案',
    'EASY',
    '第一行输入整数 n；第二行输入 n 个整数；第三行输入目标值 target。',
    '输出两个下标，使用空格分隔。',
    'java,cpp,go,python',
    1000,
    256,
    'PUBLISHED',
    0,
    0,
    1,
    0
);
```

## 5. 测试用例写法

测试用例用于 judge 判题。

字段要求：

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| `id` | 测试用例 ID，手动指定 | `4001` |
| `problem_id` | 题目 ID | `3001` |
| `input_text` | 输入文本 | `'4\n2 7 11 15\n9\n'` |
| `expected_output` | 期望输出 | `'0 1\n'` |
| `is_sample` | 是否样例，`1` 是，`0` 否 | `1` |
| `sort_order` | 测试顺序 | `1` |
| `deleted` | 固定填 `0` | `0` |

测试集生成要求：

- 每道题至少 2 条测试用例。
- 至少 1 条 `is_sample = 1`，用于前端展示。
- 至少 1 条 `is_sample = 0`，用于正式提交隐藏测试。
- 输入输出必须包含换行符 `\n`。
- 多个答案可能正确的题目不适合当前简单比对逻辑，尽量避免。
- 输出必须唯一，且格式固定。

示例：

```sql
INSERT INTO fs_problem_testcase (
    id, problem_id, input_text, expected_output, is_sample, sort_order, deleted
) VALUES
    (4001, 3001, '4\n2 7 11 15\n9\n', '0 1\n', 1, 1, 0),
    (4002, 3001, '3\n3 2 4\n6\n', '1 2\n', 0, 2, 0),
    (4003, 3001, '2\n3 3\n6\n', '0 1\n', 0, 3, 0);
```

## 6. 代码模板写法

代码模板用于前端编辑器初始化。

字段要求：

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| `problem_id` | 题目 ID | `3001` |
| `language` | `java/cpp/go/python` | `java` |
| `template_code` | 用户看到的初始代码 | 见示例 |
| `judge_wrapper_code` | 包装代码，普通标准输入输出题填 `NULL` | `NULL` |
| `deleted` | 固定填 `0` | `0` |

当前推荐写法：

- 优先生成标准输入输出模板。
- `judge_wrapper_code` 填 `NULL`。
- 不要生成 LeetCode 函数式模板，除非明确要做 wrapper。

示例：

```sql
INSERT INTO fs_code_template (
    problem_id, language, template_code, judge_wrapper_code, deleted
) VALUES
    (
        3001,
        'java',
        'import java.util.*;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner sc = new Scanner(System.in);\n        // TODO: write your code here\n    }\n}\n',
        NULL,
        0
    ),
    (
        3001,
        'cpp',
        '#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    // TODO: write your code here\n    return 0;\n}\n',
        NULL,
        0
    ),
    (
        3001,
        'go',
        'package main\n\nimport \"fmt\"\n\nfunc main() {\n    // TODO: write your code here\n    _ = fmt.Println\n}\n',
        NULL,
        0
    ),
    (
        3001,
        'python',
        '# TODO: write your code here\n',
        NULL,
        0
    );
```

## 7. 完整 SQL 脚本模板

让 GPT 生成最终数据时，请按下面结构输出一个完整 SQL 文件。

```sql
USE flowstudy;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================================
-- Tutorial seed
-- ID range: 1001 - 1999
-- =========================================================
INSERT IGNORE INTO fs_tutorial (
    id, title, summary, cover_url, author_id, status,
    view_count, like_count, sort_order, published_at, deleted
) VALUES
    (...);

-- =========================================================
-- Blog seed
-- ID range: 2001 - 2999
-- =========================================================
INSERT IGNORE INTO fs_blog (
    id, tutorial_id, title, content_md, summary, cover_url, author_id,
    sort_order, estimated_minutes, status, view_count, like_count,
    published_at, deleted
) VALUES
    (...);

-- =========================================================
-- Problem seed
-- ID range: 3001 - 3999
-- =========================================================
INSERT IGNORE INTO fs_problem (
    id, blog_id, title, description_md, difficulty,
    input_description, output_description, support_languages,
    time_limit_ms, memory_limit_mb, status,
    submit_count, accepted_count, sort_order, deleted
) VALUES
    (...);

-- =========================================================
-- Problem testcase seed
-- ID range: 4001 - 9999
-- =========================================================
INSERT IGNORE INTO fs_problem_testcase (
    id, problem_id, input_text, expected_output, is_sample, sort_order, deleted
) VALUES
    (...);

-- =========================================================
-- Code template seed
-- =========================================================
INSERT IGNORE INTO fs_code_template (
    problem_id, language, template_code, judge_wrapper_code, deleted
) VALUES
    (...);

SET FOREIGN_KEY_CHECKS = 1;
```

## 8. 推荐 ID 规则

为了避免和初始化脚本里的示例数据冲突，建议使用下面 ID 范围：

| 类型 | ID 范围 |
| --- | --- |
| 教程 `fs_tutorial` | `1001 - 1999` |
| 博客 `fs_blog` | `2001 - 2999` |
| 题目 `fs_problem` | `3001 - 3999` |
| 测试用例 `fs_problem_testcase` | `4001 - 9999` |

示例关系：

```text
教程 1001
  ├── 博客 2001
  │     ├── 题目 3001
  │     │     ├── 测试用例 4001
  │     │     └── 测试用例 4002
  │     └── 题目 3002
  └── 博客 2002
```

## 9. 给 GPT 的生成提示词

可以把下面提示词复制给 GPT：

```text
请根据以下 FlowStudy 数据规范生成 MySQL 5.7 可执行的 SQL seed 脚本。

要求：
1. 生成 3 个教程，每个教程 3 篇博客。
2. 每篇博客正文使用 Markdown，300-800 字，内容必须原创总结，不要复制网络文章。
3. 每个教程至少关联 3 道算法题。
4. 每道算法题必须是标准输入输出题，不要使用 LeetCode 函数签名。
5. 每道题至少生成 1 个样例测试用例和 2 个隐藏测试用例。
6. 每道题生成 java、cpp、go、python 四种代码模板。
7. 输出必须是完整 SQL 文件，只输出 SQL，不要输出解释。
8. 使用 INSERT IGNORE。
9. 使用 utf8mb4，字符串中的换行使用 \n。
10. ID 使用：
   - 教程：1001 开始
   - 博客：2001 开始
   - 题目：3001 开始
   - 测试用例：4001 开始

请严格按表：
- fs_tutorial
- fs_blog
- fs_problem
- fs_problem_testcase
- fs_code_template

生成可直接执行的 SQL。
```

## 10. 执行方式

将 GPT 生成的 SQL 保存为：

```text
flowstudy-infra/mysql/seed/02-seed-learning-content.sql
```

执行：

```bash
mysql -uroot -p flowstudy < flowstudy-infra/mysql/seed/02-seed-learning-content.sql
```

如果使用 PowerShell：

```powershell
mysql -uroot -p flowstudy < .\flowstudy-infra\mysql\seed\02-seed-learning-content.sql
```

执行后可检查：

```sql
SELECT id, title, status FROM fs_tutorial ORDER BY id;
SELECT id, tutorial_id, title, status FROM fs_blog ORDER BY id;
SELECT id, blog_id, title, difficulty FROM fs_problem ORDER BY id;
SELECT problem_id, COUNT(*) AS testcase_count FROM fs_problem_testcase GROUP BY problem_id;
SELECT problem_id, language FROM fs_code_template ORDER BY problem_id, language;
```
