# 10. Judge Service 设计文档

## 1. 模块定位

`flowstudy-judge` 是 FlowStudy 的判题服务，负责消费代码提交任务，在受限环境中编译和运行用户代码，并将判题结果回传给 `flowstudy-core`。

在系统角色上，Judge Service 是 FlowStudy 的“后厨执行者”。它不直接面对前端用户，不处理用户登录、文章展示、题目展示等业务，只专注于安全、稳定、可控地运行用户代码。

## 2. 职责边界

### 2.1 Judge Service 负责什么

Judge Service 负责以下内容：

1. 从 RabbitMQ 消费判题任务消息。
2. 创建隔离的临时工作目录。
3. 将用户代码写入工作目录。
4. 根据语言类型执行编译。
5. 在沙箱环境中运行用户代码。
6. 对每个测试点注入标准输入。
7. 捕获标准输出、标准错误、退出码、运行时间和内存占用。
8. 将实际输出与期望输出进行比对。
9. 生成整体判题状态和测试点结果。
10. 通过 RabbitMQ 回传判题结果。
11. 记录判题日志，携带 traceId 便于排查。

### 2.2 Judge Service 不负责什么

Judge Service 不负责以下内容：

1. 不负责用户注册、登录和权限判断。
2. 不负责文章、章节、题目管理。
3. 不直接向前端返回判题结果。
4. 不直接修改 Core 数据库，MVP 阶段通过 MQ 回传结果。
5. 不执行 AI 分析和学习笔记生成。
6. 不信任用户代码，不允许用户代码直接运行在宿主机环境中。

## 3. 推荐技术栈

| 类别 | 技术 |
|---|---|
| 编程语言 | Go 1.22+ |
| 消息队列客户端 | RabbitMQ Go Client，例如 `amqp091-go` |
| 沙箱方式 MVP | Docker 容器隔离 |
| 沙箱方式进阶 | Linux namespace / cgroups / seccomp，或接入成熟开源沙箱 |
| 日志 | zap / logrus / slog |
| 配置 | 环境变量 + `.env.example` |
| 健康检查 | HTTP `/health` |
| 并发控制 | Goroutine worker pool |

MVP 阶段建议先使用 Docker 沙箱实现最小可运行版本。后期如果需要更强安全性和性能，再替换为更底层的 Linux 沙箱或成熟开源判题引擎。

## 4. 服务输入与输出

### 4.1 输入：判题任务消息

Judge 消费以下队列：

```text
Queue:      fs.judge.submit.queue
Exchange:   fs.judge.exchange
RoutingKey: judge.submit.created
```

消息结构必须遵守 `08-rabbitmq-message-contract.md`。

核心 payload：

```json
{
  "submitId": 90001,
  "userId": 10001,
  "problemId": 100,
  "language": "java",
  "code": "public class Main { public static void main(String[] args) { } }",
  "timeLimitMs": 1000,
  "memoryLimitMb": 256,
  "testCases": [
    {
      "caseId": 1,
      "caseIndex": 1,
      "input": "4\n2 7 11 15\n9",
      "expectedOutput": "0 1",
      "isSample": true
    }
  ]
}
```

### 4.2 输出：判题结果消息

Judge 判题完成后向以下 Exchange 投递结果：

```text
Exchange:   fs.judge.result.exchange
RoutingKey: judge.result.finished
Consumer:   flowstudy-core
```

核心 payload：

```json
{
  "submitId": 90001,
  "status": "ACCEPTED",
  "score": 100,
  "timeUsedMs": 12,
  "memoryUsedKb": 20480,
  "compileMessage": null,
  "runtimeMessage": null,
  "caseResults": [
    {
      "caseId": 1,
      "caseIndex": 1,
      "status": "ACCEPTED",
      "timeUsedMs": 4,
      "memoryUsedKb": 10240,
      "actualOutput": "0 1",
      "expectedOutput": "0 1"
    }
  ]
}
```

## 5. 判题状态模型

Judge 需要生成以下状态：

| 状态 | 含义 | 触发条件 |
|---|---|---|
| `ACCEPTED` | 通过 | 所有测试点输出正确 |
| `WRONG_ANSWER` | 答案错误 | 程序正常结束，但输出与期望输出不一致 |
| `COMPILE_ERROR` | 编译错误 | 编译阶段失败 |
| `RUNTIME_ERROR` | 运行错误 | 程序运行时非零退出、异常崩溃 |
| `TIME_LIMIT_EXCEEDED` | 超时 | 单个测试点运行时间超过限制 |
| `MEMORY_LIMIT_EXCEEDED` | 超内存 | 内存占用超过限制 |
| `SYSTEM_ERROR` | 系统错误 | 沙箱异常、容器启动失败、Judge 内部异常 |

其中 `COMPILE_ERROR`、`WRONG_ANSWER`、`RUNTIME_ERROR` 等是用户代码导致的业务结果，不等同于系统异常。只有 Judge 自身处理失败才使用 `SYSTEM_ERROR`。

## 6. 整体判题流程

完整流程如下：

```text
启动 Judge Service
    ↓
连接 RabbitMQ
    ↓
监听 fs.judge.submit.queue
    ↓
消费 judge.submit.created 消息
    ↓
校验消息结构
    ↓
创建本次提交的临时工作目录
    ↓
写入用户代码文件
    ↓
根据语言执行编译
    ↓
如果编译失败，生成 COMPILE_ERROR
    ↓
如果编译成功，逐个运行测试用例
    ↓
采集输出、耗时、内存、退出码
    ↓
比对输出
    ↓
生成测试点结果和整体结果
    ↓
投递 judge.result.finished 消息
    ↓
清理临时工作目录
    ↓
ACK 原始消息
```

## 7. 推荐目录结构

```text
flowstudy-judge/
├── cmd/
│   └── judge/
│       └── main.go
├── internal/
│   ├── config/
│   ├── mq/
│   │   ├── consumer.go
│   │   ├── producer.go
│   │   └── message.go
│   ├── judge/
│   │   ├── service.go
│   │   ├── status.go
│   │   ├── comparator.go
│   │   └── result.go
│   ├── sandbox/
│   │   ├── sandbox.go
│   │   ├── docker_sandbox.go
│   │   └── workspace.go
│   ├── language/
│   │   ├── config.go
│   │   ├── java.go
│   │   ├── cpp.go
│   │   ├── go.go
│   │   └── python.go
│   ├── worker/
│   │   └── pool.go
│   └── log/
├── scripts/
├── Dockerfile
├── .env.example
├── go.mod
└── README.md
```

## 8. 工作目录设计

每次提交都应创建独立工作目录，避免不同用户代码互相影响。

目录示例：

```text
/tmp/flowstudy-sandbox/
└── submit-90001-9f2c1a7e/
    ├── Main.java
    ├── Main.class
    ├── input-1.txt
    ├── output-1.txt
    ├── error-1.txt
    └── run.log
```

命名建议：

```text
submit-{submitId}-{traceId}
```

判题结束后必须清理临时目录。若判题异常，也必须通过 defer / finally 机制清理。

## 9. 语言配置设计

建议为每种语言定义统一配置：

```go
type LanguageConfig struct {
    Language       string
    SourceFileName string
    CompileCommand []string
    RunCommand     []string
    NeedCompile    bool
}
```

### 9.1 Java

```text
源文件: Main.java
编译: javac Main.java
运行: java Main
```

要求用户 Java 代码主类名固定为 `Main`。

### 9.2 C++

```text
源文件: main.cpp
编译: g++ main.cpp -O2 -std=c++17 -o main
运行: ./main
```

### 9.3 Go

```text
源文件: main.go
编译: go build -o main main.go
运行: ./main
```

### 9.4 Python

```text
源文件: main.py
编译: 无
运行: python3 main.py
```

MVP 阶段可以先支持 Java 和 C++，后续再加入 Go 和 Python。

## 10. Docker 沙箱设计

MVP 阶段建议通过 Docker 运行用户代码，避免直接在宿主机运行。

容器运行时应尽量设置以下限制：

```text
--network none              禁止联网
--memory 256m               限制内存
--cpus 1.0                  限制 CPU
--pids-limit 64             限制进程数
--read-only                 尽量只读文件系统
--rm                        运行后自动删除容器
--security-opt no-new-privileges
```

工作目录以只挂载必要目录为原则。用户代码只应访问当前提交目录，不允许访问宿主机敏感目录。

示意命令：

```bash
docker run --rm \
  --network none \
  --memory 256m \
  --cpus 1.0 \
  --pids-limit 64 \
  --security-opt no-new-privileges \
  -v /tmp/flowstudy-sandbox/submit-90001:/workspace \
  -w /workspace \
  flowstudy/java-runner:17 \
  java Main
```

注意：该命令只是设计示意，实际实现时需要由 Go 程序动态构造，并且严格处理超时、输出大小和异常。

## 11. 编译流程

对于需要编译的语言，先执行编译阶段。

流程：

```text
写入源代码
    ↓
执行编译命令
    ↓
捕获 stdout / stderr
    ↓
如果退出码非 0，返回 COMPILE_ERROR
    ↓
如果编译成功，进入运行阶段
```

编译错误结果示例：

```json
{
  "submitId": 90001,
  "status": "COMPILE_ERROR",
  "score": 0,
  "timeUsedMs": 0,
  "memoryUsedKb": 0,
  "compileMessage": "Main.java:3: error: ';' expected",
  "runtimeMessage": null,
  "caseResults": []
}
```

编译阶段也必须有超时限制，避免编译过程卡死。

## 12. 运行流程

每个测试点单独运行，避免一个测试点污染另一个测试点。

流程：

```text
for testcase in testCases:
    准备标准输入
    启动沙箱运行程序
    等待程序结束或超时
    捕获标准输出和标准错误
    记录耗时和内存
    根据退出码、超时、内存判断状态
    如果正常结束，则比对输出
```

如果某个测试点已经失败，MVP 阶段可以选择立即停止后续测试点，也可以继续运行所有测试点。建议 MVP 阶段采用“遇到首个失败即可停止”，这样实现更简单、资源消耗更低。

## 13. 输出比对规则

MVP 阶段采用标准文本比对规则：

1. 去除输出末尾多余空白字符。
2. 统一换行符为 `\n`。
3. 默认大小写敏感。
4. 中间空格默认严格比较。

归一化逻辑示例：

```text
actual = normalize(actualOutput)
expected = normalize(expectedOutput)
if actual == expected:
    ACCEPTED
else:
    WRONG_ANSWER
```

后期可以支持 Special Judge，但 MVP 阶段不建议加入。

## 14. 资源限制

资源限制来自题目配置：

```text
timeLimitMs
memoryLimitMb
```

Judge 必须同时使用外部超时控制和容器资源限制。

### 14.1 时间限制

时间限制以单个测试点为单位。

例如：

```text
timeLimitMs = 1000
```

表示每个测试点最多运行 1000ms。

为避免系统误差，可以设置少量额外缓冲，例如 100ms，但最终结果仍以题目限制为准。

### 14.2 内存限制

内存限制以容器内存限制为主。

例如：

```text
memoryLimitMb = 256
```

对应 Docker 参数：

```text
--memory 256m
```

如果容器因内存不足被杀死，应返回 `MEMORY_LIMIT_EXCEEDED` 或 `RUNTIME_ERROR`。如果能够准确识别 OOM，优先返回 `MEMORY_LIMIT_EXCEEDED`。

### 14.3 输出大小限制

为防止用户代码无限输出，必须限制 stdout 和 stderr 最大长度。

建议 MVP：

```text
stdout 最大 1MB
stderr 最大 1MB
```

超过限制时可终止程序并返回 `RUNTIME_ERROR` 或 `OUTPUT_LIMIT_EXCEEDED`。如果系统暂时不定义 `OUTPUT_LIMIT_EXCEEDED`，可以归类为 `RUNTIME_ERROR`。

## 15. 并发模型

Judge Service 应使用 Worker Pool 控制并发，防止同时启动过多沙箱压垮机器。

环境变量：

```env
SANDBOX_MAX_CONCURRENCY=4
```

流程：

```text
RabbitMQ Consumer 拉取消息
    ↓
投递到 worker pool
    ↓
worker 获取任务
    ↓
执行判题
    ↓
发送结果
    ↓
ACK 消息
```

RabbitMQ 的 prefetch 数量应与 worker 数量接近，例如：

```text
prefetch = SANDBOX_MAX_CONCURRENCY
```

这样可以避免 Judge 一次拉取过多任务但来不及处理。

## 16. 消息确认与失败处理

Judge 消费消息必须使用手动 ACK。

### 16.1 成功处理

当以下动作全部完成后才 ACK：

```text
判题完成
结果消息投递成功
临时资源清理完成
```

### 16.2 用户代码错误

如果用户代码编译错误、运行错误、答案错误、超时，这些都属于正常判题结果。Judge 应发送对应判题结果，然后 ACK 原消息。

### 16.3 系统错误

如果发生 Judge 内部错误，例如 Docker 无法启动、消息结构非法、RabbitMQ 断连，应记录日志并按照重试策略处理。

对于无法恢复的问题，发送 `SYSTEM_ERROR` 判题结果，或者让消息进入死信队列。

## 17. 幂等设计

Judge 可能收到重复消息，因此必须支持幂等。

建议规则：

1. 以 `submitId` 作为业务幂等键。
2. 如果本地正在处理同一个 `submitId`，拒绝重复执行。
3. 如果已经成功发送过该 `submitId` 的结果，重复消息可以直接 ACK。
4. 后期可使用 Redis 或本地持久化记录处理状态。

MVP 阶段可以先依赖 Core 的结果消费幂等，Judge 端至少保证重复任务不会造成服务崩溃。

## 18. 日志规范

每次判题必须记录：

```text
traceId
messageId
submitId
problemId
language
status
timeUsedMs
memoryUsedKb
error summary
```

示例：

```text
[judge] traceId=9f2c1a7e messageId=msg-judge-000001 submitId=90001 language=java judge start
[judge] traceId=9f2c1a7e submitId=90001 compile success
[judge] traceId=9f2c1a7e submitId=90001 caseIndex=1 status=ACCEPTED timeUsedMs=4 memoryUsedKb=10240
[judge] traceId=9f2c1a7e submitId=90001 judge finished status=ACCEPTED score=100
```

日志中不要完整打印用户代码，最多打印代码长度、语言和必要错误摘要。完整代码应由 Core 保存在数据库中。

## 19. 健康检查接口

Judge 可以暴露一个仅用于本地或内网的健康检查接口：

```http
GET /health
```

返回：

```json
{
  "status": "UP",
  "service": "flowstudy-judge",
  "rabbitmq": "UP",
  "timestamp": 1710000000000
}
```

Judge 不对公网暴露业务接口。

## 20. 环境变量

`.env.example` 建议如下：

```env
APP_NAME=flowstudy-judge
APP_PORT=9000

RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=flowstudy
RABBITMQ_PASSWORD=flowstudy123
RABBITMQ_VHOST=/

JUDGE_SUBMIT_QUEUE=fs.judge.submit.queue
JUDGE_RESULT_EXCHANGE=fs.judge.result.exchange
JUDGE_RESULT_ROUTING_KEY=judge.result.finished

SANDBOX_WORK_DIR=/tmp/flowstudy-sandbox
SANDBOX_MAX_CONCURRENCY=4
SANDBOX_DEFAULT_TIME_LIMIT_MS=1000
SANDBOX_DEFAULT_MEMORY_LIMIT_MB=256
SANDBOX_STDOUT_LIMIT_BYTES=1048576
SANDBOX_STDERR_LIMIT_BYTES=1048576

ENABLE_DOCKER_SANDBOX=true
DOCKER_JAVA_IMAGE=flowstudy/java-runner:17
DOCKER_CPP_IMAGE=flowstudy/cpp-runner:latest
DOCKER_GO_IMAGE=flowstudy/go-runner:1.22
DOCKER_PYTHON_IMAGE=flowstudy/python-runner:3.11
```

## 21. MVP 开发优先级

Judge Service 建议按照以下顺序开发：

```text
第一阶段：服务骨架
    读取环境变量
    日志初始化
    RabbitMQ 连接
    /health 接口

第二阶段：MQ 消费与结果回传
    消费 fs.judge.submit.queue
    解析消息
    构造假判题结果
    投递 judge.result.finished

第三阶段：本地最小判题
    创建工作目录
    写入代码
    支持 Java 或 C++ 编译
    运行样例测试
    输出比对

第四阶段：Docker 沙箱
    禁止联网
    限制内存
    限制时间
    限制进程数
    清理临时目录

第五阶段：多语言支持
    Java
    C++
    Go
    Python

第六阶段：稳定性增强
    Worker Pool
    幂等处理
    死信队列
    日志完善
    性能测试
```

MVP 验收标准：Core 投递一条 `judge.submit.created` 消息后，Judge 能够消费任务，运行至少一种语言的代码，完成输出比对，并向 Core 回传 `judge.result.finished` 消息。
