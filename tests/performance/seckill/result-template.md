# 会员秒杀压测结果记录

- 测试日期：
- 环境：ECS `1.92.196.205`
- JMeter 版本：
- Core 镜像/提交：
- 商品 ID：
- 初始库存：
- 限流配置：
- RabbitMQ 订单队列：`flowstudy.store.order.queue`

## 核心结果

| 场景 | 压力档位 | 请求数 | QPS | P95(ms) | 错误率 | ECS CPU 平均值 | ECS CPU 峰值 | Queue Depth 最大值 | Queue Depth 最终值 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 持续负载 | 50 threads / 300s |  |  |  |  |  |  |  |  |
| 持续负载 | 100 threads / 300s |  |  |  |  |  |  |  |  |
| 持续负载 | 300 threads / 300s |  |  |  |  |  |  |  |  |
| 持续负载 | 500 threads / 300s |  |  |  |  |  |  |  |  |
| 持续负载 | 1000 threads / 300s |  |  |  |  |  |  |  |  |
| 瞬时并发 | 100 simultaneous |  |  |  |  |  |  |  |  |
| 瞬时并发 | 300 simultaneous |  |  |  |  |  |  |  |  |
| 瞬时并发 | 500 simultaneous |  |  |  |  |  |  |  |  |
| 瞬时并发 | 1000 simultaneous |  |  |  |  |  |  |  |  |
| 防超卖 | stock=300, requests=500 |  |  |  |  |  |  |  |  |

## 防超卖最终校验

| 项目 | 结果 |
|---|---:|
| 初始库存 | 300 |
| 成功订单数 |  |
| 最终库存 |  |
| 最终销量增量 |  |
| 重复订单号数 |  |
| `成功订单数 <= 300` | PASS / FAIL |
| `最终库存 >= 0` | PASS / FAIL |
| `最终库存 + 成功订单数 = 300` | PASS / FAIL |
| `销量增量 = 成功订单数` | PASS / FAIL |
| Queue 最终积压为 0 | PASS / FAIL |

## 结论

- 持续负载结论：
- 瞬时并发结论：
- 防超卖结论：
- 异常与限制：

原始文件：

- JMeter JTL：
- ECS CPU 采样：
- RabbitMQ Queue Depth 采样：
- 数据校验记录：
