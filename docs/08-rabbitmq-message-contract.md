# 08. RabbitMQ 消息契约文档

## 1. 文档目标

本文档统一 `flowstudy-core`、`flowstudy-judge` 之间的异步消息契约。当前阶段暂不开发 AI 模块，因此 MQ 优先保证两条 V1 主链路：

```text
运行代码：Core -> RabbitMQ -> Judge -> MySQL
提交判题：Core -> RabbitMQ -> Judge -> MySQL
```

当前实现中，Judge 直接消费任务并写回 MySQL。后续如需让 Core 消费判题结果，可以再启用 `judge.result.finished` 消息。

## 2. 命名规范

当前本地开发默认队列：

```text
submission_queue
```

推荐后续标准化命名：

| 类型 | 名称 |
|---|---|
| Exchange | `fs.judge.exchange` |
| Queue | `fs.judge.task.queue` |
| RoutingKey - 提交 | `judge.submit.created` |
| RoutingKey - 运行 | `judge.run.created` |
| DLX | `fs.dlx.exchange` |
| DLQ | `fs.dlq.queue` |

MVP 本地环境可以只使用一个队列承载 `SUBMISSION` 和 `RUN` 两类任务，靠消息体中的 `task_type` 区分。

## 3. 通用消息结构

Core 投递给 Judge 的消息统一为 JSON：

```json
{
  "schema_version": "1.0",
  "task_type": "SUBMISSION",
  "submission_id": 90001,
  "run_id": null,
  "user_id": 10001,
  "problem_id": 100,
  "language": "java",
  "code": "public class Main {}",
  "submit_mode": "FULL_PROGRAM",
  "time_limit_ms": 1000,
  "memory_limit_mb": 256,
  "testcases": []
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `schema_version` | string | 是 | 消息版本，当前 `1.0` |
| `task_type` | string | 是 | `SUBMISSION` / `RUN` |
| `submission_id` | number/null | 提交必填 | `fs_submission.id` |
| `run_id` | number/null | 运行必填 | `fs_code_run.id` |
| `user_id` | number | 是 | 用户 ID |
| `problem_id` | number | 是 | 题目 ID |
| `language` | string | 是 | `java` / `cpp` / `go` / `python` |
| `code` | string | 是 | 发送给 Judge 的完整代码，可能是用户代码，也可能是 wrapper 后代码 |
| `submit_mode` | string | 是 | `FULL_PROGRAM` / `TEMPLATE_WRAPPED` |
| `time_limit_ms` | number | 是 | 时间限制，毫秒 |
| `memory_limit_mb` | number | 是 | 内存限制，MB |
| `testcases` | array | 是 | 本次运行或判题使用的测试点 |

注意：

```text
1. ID 字段必须是数字或 null，不能传字符串。
2. task_type=SUBMISSION 时 submission_id 必须为数字，run_id 必须为 null。
3. task_type=RUN 时 run_id 必须为数字，submission_id 必须为 null。
4. code 字段必须是最终交给 Judge 编译的源码。
5. 如果题目使用 LeetCode 模式，Core 负责用 judge_wrapper_code 包装用户代码。
```

## 4. 测试用例结构

```json
{
  "case_id": 1,
  "case_index": 1,
  "input": "4\n2 7 11 15\n9\n",
  "expected_output": "0 1\n",
  "is_sample": true
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `case_id` | number/null | 否 | 数据库测试点 ID；用户自定义运行用例可以为 null |
| `case_index` | number | 是 | 测试点序号，从 1 开始 |
| `input` | string | 是 | 标准输入 |
| `expected_output` | string/null | 否 | 期望输出；为空时只运行不比较 |
| `is_sample` | boolean | 是 | 是否样例测试点 |

提交判题时，Core 应传入数据库中的全部测试点，包括隐藏测试点。

运行代码时，Core 应传入前端请求体中的全部测试点，包括用户修改后的默认测试点和新增自定义测试点。

## 5. 提交判题任务

### 5.1 业务流程

```text
1. 前端调用 POST /api/v1/problems/{problemId}/submissions
2. Core 校验登录态、题目、语言和代码
3. Core 读取题目全部测试点
4. Core 根据 submit_mode 生成 judge_code
5. Core 写入 fs_submission，状态 PENDING
6. Core 投递 SUBMISSION 任务到 RabbitMQ
7. Judge 消费任务、编译、运行、比较输出
8. Judge 更新 fs_submission 和 fs_judge_case_result
9. 前端轮询 GET /api/v1/submissions/{submitId}
```

### 5.2 消息示例

```json
{
  "schema_version": "1.0",
  "task_type": "SUBMISSION",
  "submission_id": 90001,
  "run_id": null,
  "user_id": 10001,
  "problem_id": 100,
  "language": "java",
  "code": "public class Main { public static void main(String[] args) { } }",
  "submit_mode": "FULL_PROGRAM",
  "time_limit_ms": 1000,
  "memory_limit_mb": 256,
  "testcases": [
    {
      "case_id": 1,
      "case_index": 1,
      "input": "4\n2 7 11 15\n9\n",
      "expected_output": "0 1\n",
      "is_sample": true
    },
    {
      "case_id": 2,
      "case_index": 2,
      "input": "3\n3 2 4\n6\n",
      "expected_output": "1 2\n",
      "is_sample": false
    }
  ]
}
```

## 6. 运行代码任务

### 6.1 业务流程

```text
1. 前端展示默认样例测试点
2. 用户可以修改默认测试点，也可以新增测试点
3. 前端调用 POST /api/v1/problems/{problemId}/runs
4. Core 只使用请求体里的 testCases，不读取隐藏测试点
5. Core 根据 submit_mode 生成 judge_code
6. Core 写入 fs_code_run，状态 PENDING
7. Core 投递 RUN 任务到 RabbitMQ
8. Judge 消费任务并更新 fs_code_run 和 fs_code_run_case_result
9. 前端轮询 GET /api/v1/runs/{runId}
```

### 6.2 消息示例

```json
{
  "schema_version": "1.0",
  "task_type": "RUN",
  "submission_id": null,
  "run_id": 80001,
  "user_id": 10001,
  "problem_id": 100,
  "language": "java",
  "code": "public class Main { public static void main(String[] args) { } }",
  "submit_mode": "FULL_PROGRAM",
  "time_limit_ms": 1000,
  "memory_limit_mb": 256,
  "testcases": [
    {
      "case_id": null,
      "case_index": 1,
      "input": "4\n2 7 11 15\n9\n",
      "expected_output": "0 1\n",
      "is_sample": true
    }
  ]
}
```

## 7. Judge 写回规则

Judge 根据 `task_type` 写不同表：

| `task_type` | 总表 | 测试点结果表 |
|---|---|---|
| `SUBMISSION` | `fs_submission` | `fs_judge_case_result` |
| `RUN` | `fs_code_run` | `fs_code_run_case_result` |

总体状态字段：

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

写回原则：

```text
1. 开始处理后将总表状态更新为 RUNNING。
2. 编译失败时写 compile_message，不写测试点结果或写入第一个失败结果均可，但前后端要保持一致。
3. 运行失败时写 runtime_message，并写入失败测试点 error_message。
4. WRONG_ANSWER 写入 actual_output 和 expected_output。
5. ACCEPTED 写入全部测试点通过结果。
6. 消息重复消费时，使用 submission_id/run_id + case_index 唯一索引保证幂等。
```

## 8. LeetCode 模式约定

题目可以通过 `fs_code_template.judge_wrapper_code` 支持函数式提交：

```text
template_code：展示给前端的用户代码模板
judge_wrapper_code：Judge 实际编译的完整程序模板，必须包含 {{USER_CODE}} 占位符
```

处理职责：

```text
Core 负责判断是否存在 judge_wrapper_code。
Core 负责把用户代码替换进 {{USER_CODE}}。
Core 负责把 submit_mode 写成 TEMPLATE_WRAPPED。
Judge 只编译运行 code 字段，不再理解业务模板。
```

这样可以避免 Judge 同时理解题目业务和多语言模板，职责更清晰。

## 9. 错误处理

| 场景 | 处理 |
|---|---|
| 消息 JSON 解析失败 | 记录错误并 ACK 丢弃，避免阻塞队列 |
| `task_type` 非法 | 记录错误并 ACK 丢弃 |
| `submission_id` / `run_id` 类型错误 | 记录错误并 ACK 丢弃 |
| 编译错误 | 更新为 `COMPILE_ERROR` |
| 用户代码运行错误 | 更新为 `RUNTIME_ERROR` |
| 沙箱或系统异常 | 更新为 `SYSTEM_ERROR` |
| 数据库写回失败 | 不 ACK 或进入重试/死信，避免结果丢失 |

## 10. 后续演进

后续可以把当前单队列升级为标准拓扑：

```text
fs.judge.exchange
  ├── judge.submit.created -> fs.judge.submit.queue
  └── judge.run.created    -> fs.judge.run.queue
```

如果后续 Judge 不再直接写数据库，则新增结果消息：

```text
judge.result.finished
```

由 Core 消费后统一更新数据库。
