#!/usr/bin/env python3
"""Create a deterministic Elasticsearch index for deep-pagination tests."""

from __future__ import annotations

import argparse
import json
import random
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone


MAPPING = {
    "settings": {
        "number_of_shards": 3,
        "number_of_replicas": 0,
        "refresh_interval": "-1",
        "index.max_result_window": 1_000_000,
    },
    "mappings": {
        "properties": {
            "id": {"type": "keyword"},
            "title": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
            "content": {"type": "text"},
            "tags": {"type": "keyword"},
            "category": {"type": "keyword"},
            "quality_score": {"type": "float"},
            "hot_score": {"type": "float"},
            "published_at": {"type": "date"},
        }
    },
}


def request(url: str, method: str, body: object | None = None) -> dict:
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as response:
        raw = response.read()
        return json.loads(raw) if raw else {}


def document(index: int, rng: random.Random) -> dict:
    topics = ["数组", "链表", "哈希表", "动态规划", "图论", "二叉树", "并发", "数据库"]
    topic = topics[index % len(topics)]
    category = "algorithm" if index % 3 else "backend"
    return {
        "id": f"doc-{index:09d}",
        "title": f"{topic}学习教程 第 {index % 1000 + 1} 节",
        "content": f"FlowStudy {topic} 教程，包含代码示例、复杂度分析、边界条件和练习建议。样本文档编号 {index}。",
        "tags": [topic, "Java" if index % 2 else "Python", category],
        "category": category,
        "quality_score": round(0.5 + rng.random() * 0.5, 6),
        "hot_score": round(rng.random() * 1000, 6),
        "published_at": (datetime(2020, 1, 1, tzinfo=timezone.utc) + timedelta(minutes=index)).isoformat(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--es-url", default="http://localhost:9200")
    parser.add_argument("--index", default="flowstudy-pagination-benchmark")
    parser.add_argument("--count", type=int, default=1_000_000)
    parser.add_argument("--batch-size", type=int, default=2_000)
    parser.add_argument("--seed", type=int, default=20260826)
    parser.add_argument("--recreate", action="store_true")
    args = parser.parse_args()
    base = args.es_url.rstrip("/")

    if args.recreate:
        try:
            request(f"{base}/{args.index}", "DELETE")
        except urllib.error.HTTPError as exc:
            if exc.code != 404:
                raise
    request(f"{base}/{args.index}", "PUT", MAPPING)
    rng = random.Random(args.seed)
    for start in range(0, args.count, args.batch_size):
        end = min(start + args.batch_size, args.count)
        lines = []
        for index in range(start, end):
            lines.append(json.dumps({"index": {"_index": args.index, "_id": f"doc-{index:09d}"}}))
            lines.append(json.dumps(document(index, rng), ensure_ascii=False))
        req = urllib.request.Request(
            f"{base}/{args.index}/_bulk",
            data=("\n".join(lines) + "\n").encode("utf-8"),
            method="POST",
            headers={"Content-Type": "application/x-ndjson"},
        )
        with urllib.request.urlopen(req, timeout=120) as response:
            result = json.loads(response.read())
        if result.get("errors"):
            raise RuntimeError(f"bulk indexing failed near document {start}")
        if end % (args.batch_size * 10) == 0 or end == args.count:
            print(f"indexed {end}/{args.count}")
    request(f"{base}/{args.index}/_settings", "PUT", {"index": {"refresh_interval": "1s"}})
    request(f"{base}/{args.index}/_refresh", "POST")
    print(f"ready: {args.index}, documents={args.count}")


if __name__ == "__main__":
    main()
