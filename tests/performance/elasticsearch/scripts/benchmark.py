#!/usr/bin/env python3
"""Compare Elasticsearch from+size and search_after deep pagination."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import statistics
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


SORT = [
    {"_score": "desc"},
    {"quality_score": "desc"},
    {"hot_score": "desc"},
    {"published_at": "desc"},
    {"id": "asc"},
]


def request(base: str, path: str, method: str = "GET", body: object | None = None) -> dict:
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    req = urllib.request.Request(f"{base.rstrip('/')}{path}", data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=120) as response:
        raw = response.read()
        return json.loads(raw) if raw else {}


def query_body(keyword: str, size: int, offset: int = 0, search_after=None, pit_id: str | None = None) -> dict:
    body = {
        "size": size,
        "track_total_hits": False,
        "query": {
            "function_score": {
                "query": {"multi_match": {"query": keyword, "fields": ["title^5", "tags^3", "content"]}},
                "functions": [
                    {"field_value_factor": {"field": "quality_score", "factor": 0.2, "modifier": "log1p", "missing": 0}},
                    {"field_value_factor": {"field": "hot_score", "factor": 0.01, "modifier": "log1p", "missing": 0}},
                ],
                "score_mode": "sum",
                "boost_mode": "sum",
            }
        },
        "sort": SORT,
    }
    if offset:
        body["from"] = offset
    if search_after is not None:
        body["search_after"] = search_after
    if pit_id:
        body["pit"] = {"id": pit_id, "keep_alive": "5m"}
    return body


def percentile(values: list[float], percent: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, int(round((percent / 100) * (len(ordered) - 1))))
    return ordered[index]


def run_once(base: str, index: str, keyword: str, mode: str, offset: int, size: int) -> dict:
    pit = request(f"{base}", f"/{index}/_pit?keep_alive=5m", "POST")
    pit_id = pit.get("id")
    started = time.perf_counter()
    latencies: list[float] = []
    ids: list[str] = []
    pages = 0
    try:
        if mode == "from-size":
            body = query_body(keyword, size, offset=offset, pit_id=pit_id)
            request_started = time.perf_counter()
            result = request(base, "/_search", "POST", body) if pit_id else request(base, f"/{index}/_search", "POST", body)
            latencies.append((time.perf_counter() - request_started) * 1000)
            hits = result.get("hits", {}).get("hits", [])
            ids = [str(hit.get("_id")) for hit in hits]
            pages = 1
        else:
            search_after = None
            target_ids: list[str] = []
            # search_after cannot jump; walk from the first page to the target offset.
            for current in range(0, offset + 1, size):
                body = query_body(keyword, size, search_after=search_after, pit_id=pit_id)
                request_started = time.perf_counter()
                result = request(base, "/_search", "POST", body) if pit_id else request(base, f"/{index}/_search", "POST", body)
                latencies.append((time.perf_counter() - request_started) * 1000)
                hits = result.get("hits", {}).get("hits", [])
                page_ids = [str(hit.get("_id")) for hit in hits]
                if current + size > offset:
                    target_ids = page_ids
                if not hits or len(hits) < size:
                    break
                search_after = hits[-1].get("sort")
                pages += 1
            ids = target_ids
        duplicate_count = len(ids) - len(set(ids))
        return {
            "mode": mode,
            "offset": offset,
            "page_size": size,
            "pages": pages,
            "request_count": len(latencies),
            "target_latency_ms": round(latencies[-1] if latencies else 0, 3),
            "cumulative_latency_ms": round((time.perf_counter() - started) * 1000, 3),
            "latencies": latencies,
            "duplicate_count": duplicate_count,
            "result_hash": hashlib.sha256("\n".join(ids).encode()).hexdigest()[:16],
        }
    finally:
        if pit_id:
            try:
                request(base, "/_pit", "DELETE", {"id": pit_id})
            except Exception:
                pass


def summarize(records: list[dict], mode: str, offset: int, size: int, concurrency: int) -> dict:
    latencies = [latency for record in records for latency in record["latencies"]]
    return {
        "mode": mode,
        "offset": offset,
        "page_size": size,
        "concurrency": concurrency,
        "iterations": len(records),
        "sample_count": len(records),
        "request_count": sum(record["request_count"] for record in records),
        "p50_ms": round(percentile(latencies, 50), 3),
        "p95_ms": round(percentile(latencies, 95), 3),
        "p99_ms": round(percentile(latencies, 99), 3),
        "mean_ms": round(statistics.mean(latencies), 3) if latencies else 0,
        "target_mean_ms": round(statistics.mean(record["target_latency_ms"] for record in records), 3),
        "cumulative_mean_ms": round(statistics.mean(record["cumulative_latency_ms"] for record in records), 3),
        "duplicate_count": sum(record["duplicate_count"] for record in records),
        "result_hashes": ",".join(sorted({record["result_hash"] for record in records})),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--es-url", default="http://localhost:9200")
    parser.add_argument("--index", default="flowstudy-pagination-benchmark")
    parser.add_argument("--keyword", default="数组")
    parser.add_argument("--modes", default="from-size,search-after")
    parser.add_argument("--depths", default="0,1000,10000,50000,100000")
    parser.add_argument("--page-sizes", default="20,50,100")
    parser.add_argument("--concurrency", default="1,4,16")
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument("--warmup", type=int, default=1)
    parser.add_argument("--output", type=Path, default=Path("results/es-pagination-summary.csv"))
    args = parser.parse_args()

    modes = [item.strip() for item in args.modes.split(",") if item.strip()]
    depths = [int(item) for item in args.depths.split(",")]
    page_sizes = [int(item) for item in args.page_sizes.split(",")]
    concurrencies = [int(item) for item in args.concurrency.split(",")]
    all_summaries = []
    node_stats_before = request(args.es_url, "/_nodes/stats/os,process,jvm,thread_pool,indices")
    for mode in modes:
        for size in page_sizes:
            for offset in depths:
                for concurrency in concurrencies:
                    job = lambda _: run_once(args.es_url, args.index, args.keyword, mode, offset, size)
                    with ThreadPoolExecutor(max_workers=concurrency) as pool:
                        list(pool.map(job, range(args.warmup * concurrency)))
                        records = list(pool.map(job, range(args.iterations * concurrency)))
                    summary = summarize(records, mode, offset, size, concurrency)
                    all_summaries.append(summary)
                    print(json.dumps(summary, ensure_ascii=False))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=all_summaries[0].keys())
        writer.writeheader()
        writer.writerows(all_summaries)
    json_path = args.output.with_suffix(".json")
    json_path.write_text(json.dumps(all_summaries, ensure_ascii=False, indent=2), encoding="utf-8")
    node_stats_path = args.output.with_name(f"{args.output.stem}-node-stats.json")
    node_stats_after = request(args.es_url, "/_nodes/stats/os,process,jvm,thread_pool,indices")
    node_stats_path.write_text(
        json.dumps({"before": node_stats_before, "after": node_stats_after}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"wrote {args.output}, {json_path}, and {node_stats_path}")


if __name__ == "__main__":
    main()
