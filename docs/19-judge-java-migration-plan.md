# 19. Judge Java 版改造计划

## 1. 背景与目标

当前 `flowstudy-judge` 使用 C++17 + CMake + RabbitMQ + MySQL + isolate 实现，已经具备消费判题任务、编译运行用户代码、比较输出并写回 MySQL 的能力。后续如果希望统一后端技术栈、降低维护门槛，可以新建 Java 版 Judge Worker。

本计划目标不是立即替换现有 C++ Judge，而是在不破坏当前判题链路的前提下，新增一个可灰度切换的 Java Judge 实现。

推荐仓库形态：

```text
flowstudy-core          Java 主业务服务，负责任务编排、鉴权、题目和提交记录
flowstudy-judge         当前 C++ Judge，继续作为稳定版本保留
flowstudy-judge-java    新 Java Judge Worker，完成后再灰度替换
```

不建议把 Judge 直接放进 `flowstudy-core`，因为判题涉及沙箱、进程、权限和不可信代码执行，必须和主业务服务隔离。

## 2. 技术选型

```text
语言与框架：Java 17 + Spring Boot 3
消息队列：Spring AMQP / RabbitMQ
数据库：MyBatis 或 JdbcTemplate + MySQL
沙箱执行：ProcessBuilder 调用 isolate
日志：SLF4J + Logback，统一 traceId
配置：application.yml + 环境变量
构建部署：Maven + Docker + GitHub Actions + SWR
```

Java 版 Judge 只负责执行任务，不提供面向用户的 HTTP 业务接口。可选提供内部健康检查：

```http
GET /health
```

用于容器编排和运维探活。

## 3. 目标工作流

```text
1. Core 接收代码运行或提交判题请求
2. Core 生成最终可编译代码，包含 FULL_PROGRAM 或 TEMPLATE_WRAPPED 两种模式
3. Core 写入 fs_submission 或 fs_code_run，状态为 PENDING
4. Core 向 RabbitMQ 投递统一判题任务消息
5. Java Judge 消费消息，校验 schema_version、task_type、ID 和 testcases
6. Java Judge 将任务状态更新为 RUNNING
7. Java Judge 创建独立 workspace，并初始化 isolate box
8. 根据 language 写入源码文件，执行编译命令
9. 编译成功后逐个测试用例运行程序
10. 收集 stdout、stderr、exitCode、timeUsedMs、memoryUsedKb
11. 规范化输出并比较 expected_output
12. 写回 fs_submission/fs_judge_case_result 或 fs_code_run/fs_code_run_case_result
13. 清理 workspace 和 isolate box
14. ack RabbitMQ 消息
```

当前契约仍保持：

```text
Queue: submission_queue
Result writeback: Judge 直接写 MySQL
```

后续如需让 Core 消费判题结果，可再引入 `judge.result.finished` 结果消息，但不建议和 Java 迁移同时做。

## 4. 模块设计

推荐目录：

```text
flowstudy-judge-java/
├── pom.xml
├── Dockerfile
├── src/main/java/com/flowstudy/judge/
│   ├── FlowstudyJudgeApplication.java
│   ├── config/
│   │   ├── JudgeProperties.java
│   │   ├── RabbitConfig.java
│   │   └── DataSourceConfig.java
│   ├── mq/
│   │   ├── JudgeTaskListener.java
│   │   ├── JudgeTaskMessage.java
│   │   └── JudgeTaskValidator.java
│   ├── service/
│   │   ├── JudgeTaskService.java
│   │   ├── SubmissionWritebackService.java
│   │   └── RunWritebackService.java
│   ├── sandbox/
│   │   ├── IsolateSandbox.java
│   │   ├── SandboxCommand.java
│   │   ├── SandboxResult.java
│   │   └── WorkspaceManager.java
│   ├── language/
│   │   ├── LanguageConfig.java
│   │   ├── LanguageRegistry.java
│   │   └── Language.java
│   ├── compare/
│   │   └── OutputComparator.java
│   └── model/
│       ├── JudgeStatus.java
│       ├── CaseResult.java
│       └── JudgeResult.java
└── src/test/
```

职责边界：

```text
mq            只处理消息消费、ack/nack 和消息结构校验
service       编排一次判题任务，决定写哪张结果表
sandbox       封装 isolate init/run/cleanup 和文件系统 workspace
language      管理 Java/C++/Python/Go 等语言的编译运行命令
compare       只处理输出规范化和答案比较
writeback     只处理 MySQL 状态与测试点结果写回
```

## 5. 消息契约

Java Judge 必须兼容当前 `docs/08-rabbitmq-message-contract.md`：

```json
{
  "schema_version": "1.0",
  "task_type": "SUBMISSION",
  "submission_id": 90001,
  "run_id": null,
  "user_id": 10001,
  "problem_id": 100,
  "language": "java",
  "code": "public class Main { public static void main(String[] args) {} }",
  "submit_mode": "FULL_PROGRAM",
  "time_limit_ms": 1000,
  "memory_limit_mb": 256,
  "testcases": [
    {
      "case_id": 1,
      "case_index": 1,
      "input": "1 2\n",
      "expected_output": "3\n",
      "is_sample": true
    }
  ]
}
```

关键约束：

```text
1. task_type=SUBMISSION 时 submission_id 必须为数字，run_id 必须为 null
2. task_type=RUN 时 run_id 必须为数字，submission_id 必须为 null
3. code 字段必须是 Core 处理后的最终完整代码
4. TEMPLATE_WRAPPED 模式由 Core 负责拼接 judge_wrapper_code
5. Judge 不理解业务模板，只编译运行 code
```

## 6. 语言执行配置

Java Judge 应将语言配置做成可维护表，而不是散落在 if/else 中。

示例：

```text
java
  sourceFile: Main.java
  compile: javac -J-Xms16m -J-Xmx128m -J-XX:ReservedCodeCacheSize=32m Main.java
  run: java -Xms16m -Xmx128m -XX:ReservedCodeCacheSize=32m Main

cpp
  sourceFile: main.cpp
  compile: g++ main.cpp -O2 -std=c++17 -o main
  run: ./main

python
  sourceFile: main.py
  compile: none
  run: python3 main.py
```

Go 语言可以作为第二阶段支持：

```text
go
  sourceFile: main.go
  compile: go build -o main main.go
  run: ./main
```

## 7. isolate 封装要求

Java 通过 `ProcessBuilder` 调用 isolate，不直接实现 Linux sandbox。

必须封装以下能力：

```text
1. isolate --box-id={id} --cleanup
2. isolate --box-id={id} --init
3. 挂载 workspace、JDK、Python、必要系统目录
4. 设置 time、wall-time、mem、processes
5. 执行编译命令
6. 执行运行命令并注入 stdin
7. 读取 stdout、stderr 和 meta 文件
8. finally 中强制 cleanup
```

Java 运行需要重点处理：

```text
1. javac/java 在 isolate 中的 JDK 路径挂载
2. Java VM 线程数限制
3. Java heap、metaspace、code cache 参数
4. /etc/alternatives、/usr/lib/jvm、java.security 等路径可见性
```

这些问题是当前 C++ Judge 已经踩过的主要坑，Java 版必须在第一阶段回归测试覆盖。

## 8. 幂等、失败和重试

建议处理规则：

```text
1. 消息解析失败：记录错误并 ack，避免毒消息无限重试
2. 系统错误：写回 SYSTEM_ERROR 后 ack
3. DB 暂时不可用：nack/requeue 或进入 DLQ，不能静默丢弃
4. 重复消费：通过 submission_id/run_id + case_index 唯一约束保证测试点结果幂等
5. RUNNING 超时任务：Core 或运维脚本定期补偿为 SYSTEM_ERROR
```

后续可引入：

```text
fs_judge_task_log
message_id
trace_id
retry_count
dead_letter_reason
```

但不建议在迁移第一阶段强行扩展数据库。

## 9. 阶段计划

### Phase 1：最小可运行 Java Worker

目标：

```text
1. Spring Boot 启动
2. 连接 RabbitMQ 和 MySQL
3. 消费 submission_queue
4. 支持 cpp/java/python 三种语言
5. 支持 SUBMISSION 和 RUN 两类任务
6. 直写当前 MySQL 结果表
```

预计：

```text
全职 4~7 天
业余 1.5~2.5 周
```

### Phase 2：稳定性增强

目标：

```text
1. worker pool 并发
2. traceId 贯穿日志
3. 更严格的消息校验
4. 任务超时和进程树清理
5. 编译/运行错误脱敏
6. Docker 镜像和 GitHub Actions
```

### Phase 3：灰度替换 C++ Judge

目标：

```text
1. 同一套 Core 消息同时可被 C++ Judge 或 Java Judge 消费
2. 通过环境变量控制启动哪个 Worker
3. 对同一批题目做结果一致性对比
4. Java Judge 通过后再替换生产 compose 镜像
```

## 10. 验收标准

必须满足：

```text
1. C++/Java/Python 的 AC、WA、CE、RE、TLE 都有测试样例
2. LeetCode TEMPLATE_WRAPPED 代码由 Core 拼接后可正常判题
3. RUN 任务只运行前端传入测试用例，不读取隐藏用例
4. SUBMISSION 任务执行全部数据库测试用例
5. 失败测试用例可写回 input、expected_output、actual_output、error_message
6. RabbitMQ 重复投递不会造成重复测试点数据
7. isolate cleanup 在成功和失败路径都执行
8. Docker 镜像可在 ECS 上启动并消费任务
```

## 11. 风险与建议

主要风险：

```text
1. Java 调 isolate 后仍然要处理 Linux 权限、cgroup、JDK 路径和资源限制
2. 迁移期间如果同时改变 MQ 契约和 DB 结构，联调成本会明显上升
3. Judge 是安全边界服务，不能因为改成 Java 就降低隔离要求
```

建议：

```text
1. 保留 C++ Judge 作为可回滚版本
2. Java Judge 第一阶段完全兼容现有消息和表结构
3. 等 Java 版稳定后，再考虑结果消息回传 Core、DLQ、审计表等增强项
```

