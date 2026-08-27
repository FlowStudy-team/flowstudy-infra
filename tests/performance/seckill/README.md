# 会员秒杀压测方案

本方案使用本地 JMeter 发压，ECS 远程承载服务。JMeter 的线程数代表虚拟用户数；只有在请求被同步释放、或在持续时间窗口内形成稳定请求速率时，才分别对应瞬时并发或持续负载。旧版 `seckill.jmx` 是单次请求基线，不再用于描述“10 秒 Ramp-up 的并发压测”。

## 测试场景

### 1. 持续负载测试

使用 `sustained-load.jmx`，每个虚拟用户在指定持续时间内循环请求。通过多次执行逐级增加 `threads`，例如 50、100、300、500、1000；`ramp_seconds` 只表示将线程逐步启动的时间，不代表并发请求同时到达。正式 ECS 测试必须使用独立测试商品，并根据库存和目标 QPS 设置持续时长；禁止在正式商品上执行循环负载。必要时使用 `enable_throughput_cap=true` 控制目标请求速率。

```powershell
jmeter -n -t sustained-load.jmx -l sustained-100.jtl `
  -Jcore_host=1.92.196.205 -Jcore_port=80 -Jauth_token='<JWT>' `
  -Jproduct_id=1 -Jthreads=100 -Jramp_seconds=60 -Jduration_seconds=300
```

### 2. 瞬时并发测试

使用 `instant-concurrency.jmx`，线程数设置为 100、300、500、1000，并配置 `Synchronizing Timer` 的 `groupSize` 与线程数一致。线程启动后先在同步点等待，达到目标数量后同时释放，因此该场景用于模拟突发请求同时到达，而不是用 Ramp-up 时间推断并发量。

```powershell
jmeter -n -t instant-concurrency.jmx -l instant-1000.jtl `
  -Jcore_host=1.92.196.205 -Jcore_port=80 -Jauth_token='<JWT>' `
  -Jproduct_id=1 -Jconcurrency=1000 -Jsync_group_size=1000 `
  -Jsync_timeout_ms=60000 -Jramp_seconds=1
```

### 3. 防超卖测试

使用 `oversell-protection.jmx`，先准备一个独立测试商品，库存设置为 300；将 `requests` 和 `sync_group_size` 设置为大于 300，例如 500 或 1000，使请求尽可能同时到达。请求结束后等待 RabbitMQ 队列清空，再校验：成功订单数不超过 300、最终库存不小于 0、销量增加量与成功订单数一致、最终库存与成功订单数之和等于 300、订单号无重复。

```powershell
jmeter -n -t oversell-protection.jmx -l oversell-500.jtl `
  -Jcore_host=1.92.196.205 -Jcore_port=80 -Jauth_token='<JWT>' `
  -Jproduct_id=<TEST_PRODUCT_ID> -Jrequests=500 -Jsync_group_size=500
```

测试商品的创建和清理可通过 Infra 的 `Seckill Test Fixture` workflow 完成：选择 `prepare` 创建库存 300 的独立商品，记录 workflow 日志中的商品 ID；测试结束后选择 `cleanup` 并填写商品 ID。生产环境禁止直接修改正式商品库存。

## 统一采集指标

结果表只保留：QPS、P95 延迟、错误率、ECS CPU 使用率、RabbitMQ Queue Depth。QPS 为测试窗口内请求数除以实际时长；P95 使用 JMeter `elapsed` 计算；错误率为非预期响应数占比，防超卖场景中的库存不足响应应标记为业务预期；CPU 和 Queue Depth 必须在 ECS 侧同步采样。

## 执行顺序

1. 确认 ECS 健康检查、商品状态、Redis、RabbitMQ 和数据库正常。
2. 创建独立测试用户并获取 JWT，准备独立测试商品或记录准确的初始库存。
3. 压测前记录库存、销量、成功订单数和 RabbitMQ Queue Depth。
4. 启动 `Seckill ECS Monitor` workflow，持续采集 ECS Core 容器 CPU 和订单队列深度；随后本地启动 JMeter，保存 `.jtl` 原始结果。监控时长应覆盖预热、正式采样和排空队列阶段。
5. 持续负载按压力档位逐级执行；瞬时并发按 100/300/500/1000 分档执行；防超卖执行库存 300、请求数大于 300 的场景。
6. 等待订单消费者处理完成，再查询订单数、库存和销量，填写结果模板。
7. 恢复限流、删除测试用户和测试商品，保留 JTL、监控 workflow 日志和结果记录。

## 结果文件

使用 [`result-template.md`](result-template.md) 记录每个场景。旧版 `run-seckill.ps1` 依赖本地 MySQL、Redis、RabbitMQ，适合本地集成验证，不适合 ECS 远程压测；远程执行应直接使用上述三个 JMX 配置。
