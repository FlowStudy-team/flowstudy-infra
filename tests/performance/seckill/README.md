# FlowStudy 秒杀接口压测

本目录验证 `flowstudy-core` 的 `feat/store-seckill` 分支：Redis Lua 预扣库存、RabbitMQ 异步订单落库、数据库条件扣库存和库存回补是否能在并发请求下保持一致。

## 前置条件

- Core 使用 `feat/store-seckill` 启动在 `http://127.0.0.1:8080`。
- MySQL、Redis、RabbitMQ 已启动；RabbitMQ 管理插件可选，未开启时报告中队列深度为 `UNAVAILABLE`。
- 已安装 JMeter 5.6+，默认路径为 `F:\software\apache-jmeter-5.6.3\bin\jmeter.bat`。
- 设置数据库密码。不要将该命令或密码提交到仓库。

```powershell
$env:FLOWSTUDY_PERF_DB_PASSWORD = '<local-mysql-password>'
$env:FLOWSTUDY_PERF_RABBIT_PASSWORD = '<local-rabbitmq-password>'
```

运行时建议提高本机 Core 的订单限流容量，例如：

```powershell
$env:RATE_LIMIT_STORE_ORDER_PER_WINDOW = '10000'
$env:RATE_LIMIT_WINDOW_SECONDS = '60'
```

这避免单 IP 令牌桶限流掩盖秒杀库存链路的吞吐。限流行为应使用默认配置单独验证。

## 执行

在 infra 仓库执行：

```powershell
.\tests\performance\seckill\run-seckill.ps1
```

默认执行 `50`、`100`、`200` 并发。每个线程只发起一次下单请求，每档使用一个新建的、库存为 `100` 的测试商品，因此可直接观察抢购成功、售罄和是否超卖。

自定义并发和库存：

```powershell
.\tests\performance\seckill\run-seckill.ps1 `
  -ConcurrencyCsv '20,50,100' `
  -Stock 100 `
  -DbPassword '<local-mysql-password>'
```

测试结束后若确认无需保留测试数据，可重新执行并带 `-Cleanup`，或按 `cleanup-seckill.sql` 中的规则手工清理。原始结果默认被 Git 忽略。

## 结果文件

每次测试产生一个独立目录：

```text
results/<timestamp>/
  seckill-<concurrency>.jtl
  summary.csv
  mysql-before-<concurrency>.txt
  mysql-after-<concurrency>.txt
  redis-after-<concurrency>.txt
  rabbitmq-<concurrency>.txt
  report.md
```

`report.md` 给出并发、QPS、平均响应时间、P95、P99、HTTP 200/409/429/5xx、最终订单数、MySQL 与 Redis 库存、队列深度及超卖结论。

## 数据口径

- HTTP `200`：Redis 成功预扣库存并将订单任务投递给 RabbitMQ；它不代表订单已经写入 MySQL。
- HTTP `409`：库存已售罄，是库存受限秒杀场景中的预期响应，不计为服务端异常。
- `DB订单`：等待消息消费稳定后查询的最终订单数，是判定库存一致性的依据。
- `QPS`：本档总 HTTP 请求数除以最早与最晚请求时间戳之间的实际秒数。
- `P95/P99`：JMeter `elapsed` 字段的百分位响应时间。

无超卖需同时满足：

```text
DB订单 <= 初始库存
DB库存 >= 0
订单号无重复
DB库存 + DB订单 = 初始库存
Redis库存 = DB库存
```

本压测运行在同一台 Windows 机器，JMeter、Core、MySQL、Redis 和 RabbitMQ 争用同一套 CPU、内存和网络栈。它适合验证并发正确性和本机回归，不可直接作为 ECS 生产容量数据。
