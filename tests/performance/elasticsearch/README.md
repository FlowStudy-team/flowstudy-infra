# Elasticsearch 深分页性能测试

本目录用于对比 `from + size` 与 `search_after` 在百万级文档上的深分页性能。测试独立于业务服务，避免把接口层、网络网关或业务代码的耗时混入 Elasticsearch 对比。

## 测试环境

- Elasticsearch 8.15.3，单节点、3 分片、0 副本。
- Docker Compose 默认分配 2 GB JVM 堆。
- 测试索引默认写入 1,000,000 条确定性数据，并将 `index.max_result_window` 设置为 1,000,000，仅用于展示 `from + size` 的退化趋势。
- 查询包含 `multi_match` 相关性检索、质量分和热度字段权重，两个方案使用完全相同的查询和稳定排序：`_score desc`、`quality_score desc`、`hot_score desc`、`published_at desc`、`id asc`。
- 使用 PIT 固定测试期间的数据视图，避免两种方案因 refresh 或更新产生结果集差异。

## 运行

在本目录执行：

```powershell
.\scripts\run.ps1
```

小规模冒烟测试：

```powershell
.\scripts\run.ps1 -DocumentCount 10000 -KeepContainer
```

也可以分步执行：

```powershell
docker compose up -d
python .\scripts\generate_data.py --count 1000000 --recreate
python .\scripts\benchmark.py --output .\results\es-pagination-summary.csv
```

脚本默认测试页大小 `20,50,100`、深度 `0,1000,10000,50000,100000`、并发 `1,4,16`。并发值表示每个样本批次同时发出的请求数；可通过 `--depths`、`--page-sizes`、`--concurrency` 调整。生成 CSV、JSON 汇总和节点资源前后快照到 `results/`，该目录不会提交到 Git。

## 指标与解读

- `target_latency_ms`：目标页单次请求延迟。用于比较当前页本身的响应代价。
- `cumulative_latency_ms`：完成一次目标查询的总耗时；`search_after` 会从第一页顺序走到目标页，因此该指标会随深度增长。
- `p50/p95/p99`：所有实际 Elasticsearch 请求的延迟分位数。重点观察高并发下的尾延迟。
- `request_count`：完成样本所产生的 HTTP 查询请求数；`search_after` 深页通常显著更多。
- `duplicate_count` 与 `result_hashes`：用于检查分页是否重复，以及两种方案返回的目标页是否一致。相同查询、索引未变更且 PIT 正常时，两种方案的 hash 应一致。
- `*-node-stats.json`：测试前后 `_nodes/stats` 快照，可观察 JVM、GC、CPU、线程池和索引统计变化。生产容量评估还应配合连续采样的监控系统。

## 注意事项

`from + size` 适合可控的浅分页和需要随机跳页的场景，但每个分片都要构造并保留从起点到目标位置的候选结果，深度越大内存和排序开销越高；超过 `index.max_result_window` 会直接失败。`search_after` 适合连续翻页，单次请求成本稳定，但不能直接跳到任意页，脚本中的深页测试会累计执行此前所有页，因此同时报告单页延迟和累计耗时。

正式结论应至少分别运行冷启动、预热后、不同并发、不同页大小，并重复多轮；不要用 10,000 条数据的冒烟结果代替百万级数据结论。
