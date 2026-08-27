#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_PATH="${ECS_DEPLOY_PATH:-/opt/flowstudy}"
cd "$DEPLOY_PATH"

INPUT_WEB_IMAGE_TAG="${WEB_IMAGE_TAG:-}"
INPUT_SERVER_IMAGE_TAG="${SERVER_IMAGE_TAG:-}"
INPUT_JUDGE_IMAGE_TAG="${JUDGE_IMAGE_TAG:-}"
INPUT_OPENCODE_IMAGE_TAG="${OPENCODE_IMAGE_TAG:-}"
# These optional values are passed only by a manually dispatched workflow.
# They keep the production defaults in .env unchanged after a test deployment.
INPUT_STORE_ORDER_RATE_LIMIT="${DEPLOY_STORE_ORDER_RATE_LIMIT:-}"
INPUT_STORE_ORDER_RATE_WINDOW_SECONDS="${DEPLOY_STORE_ORDER_RATE_WINDOW_SECONDS:-}"
RESET_MYSQL_VOLUME="${RESET_MYSQL_VOLUME:-false}"

if [ ! -f ".env" ]; then
  echo "Missing $DEPLOY_PATH/.env. Create it from deploy/env.example before deploying." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. "$DEPLOY_PATH/.env"
set +a

required_vars=(
  SWR_REGISTRY
  SWR_NAMESPACE
  MYSQL_DATABASE
  MYSQL_USER
  MYSQL_PASSWORD
  MYSQL_ROOT_PASSWORD
  REDIS_PASSWORD
  RABBITMQ_DEFAULT_USER
  RABBITMQ_DEFAULT_PASS
  ELASTICSEARCH_PASSWORD
)
for required_var in "${required_vars[@]}"; do
  if [ -z "${!required_var:-}" ] || [[ "${!required_var}" == replace-with-real-* ]]; then
    echo "Missing required production setting: ${required_var} in $DEPLOY_PATH/.env" >&2
    exit 1
  fi
done

IMAGE_TAG="${1:-${IMAGE_TAG:-latest}}"
export IMAGE_TAG
export SWR_REGISTRY SWR_NAMESPACE IMAGE_TAG
export WEB_IMAGE_TAG="${INPUT_WEB_IMAGE_TAG:-${WEB_IMAGE_TAG:-$IMAGE_TAG}}"
export SERVER_IMAGE_TAG="${INPUT_SERVER_IMAGE_TAG:-${SERVER_IMAGE_TAG:-$IMAGE_TAG}}"
export JUDGE_IMAGE_TAG="${INPUT_JUDGE_IMAGE_TAG:-${JUDGE_IMAGE_TAG:-$IMAGE_TAG}}"
export OPENCODE_IMAGE_TAG="${INPUT_OPENCODE_IMAGE_TAG:-${OPENCODE_IMAGE_TAG:-$IMAGE_TAG}}"
export RATE_LIMIT_STORE_ORDER_PER_WINDOW="${INPUT_STORE_ORDER_RATE_LIMIT:-${RATE_LIMIT_STORE_ORDER_PER_WINDOW:-5}}"
export RATE_LIMIT_WINDOW_SECONDS="${INPUT_STORE_ORDER_RATE_WINDOW_SECONDS:-${RATE_LIMIT_WINDOW_SECONDS:-60}}"

if [ "$RESET_MYSQL_VOLUME" = "true" ]; then
  echo "Resetting the MySQL data volume as explicitly requested ..."
  mysql_volume="$(docker volume ls --filter label=com.docker.compose.volume=flowstudy-mysql-data --format '{{.Name}}')"
  volume_count="$(printf '%s\n' "$mysql_volume" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$volume_count" -gt 1 ]; then
    echo "Multiple MySQL volumes matched; refusing to delete any volume." >&2
    printf '%s\n' "$mysql_volume" >&2
    exit 1
  fi
  docker compose -f docker-compose.prod.yml stop mysql || true
  docker compose -f docker-compose.prod.yml rm -f mysql || true
  if [ "$volume_count" -eq 1 ]; then
    docker volume rm "$mysql_volume"
  else
    echo "MySQL data volume was already absent; continuing with initialization."
  fi
fi

mkdir -p "$DEPLOY_PATH/judge"
python3 - <<'PY'
import json
import os

config = {
    "rabbitmq": {
        "hostname": "rabbitmq",
        "port": 5672,
        "vhost": os.environ.get("RABBITMQ_VHOST", "/"),
        "username": os.environ["RABBITMQ_DEFAULT_USER"],
        "password": os.environ["RABBITMQ_DEFAULT_PASS"],
        "queue_name": os.environ.get("JUDGE_SUBMISSION_QUEUE", "flowstudy.judge.submission.v2"),
    },
    "mysql": {
        "hostname": "mysql",
        "port": 3306,
        "username": os.environ["MYSQL_USER"],
        "password": os.environ["MYSQL_PASSWORD"],
        "database": os.environ["MYSQL_DATABASE"],
    },
    "isolate": {
        "binary_path": os.environ.get("ISOLATE_BINARY_PATH", "/usr/local/bin/isolate"),
        "box_id_start": int(os.environ.get("ISOLATE_BOX_ID_START", "1")),
        "num_boxes": int(os.environ.get("ISOLATE_NUM_BOXES", "5")),
    },
    "judge": {
        "concurrency": int(os.environ.get("JUDGE_CONCURRENCY", "1")),
    },
}

with open("judge/config.json", "w", encoding="utf-8") as f:
    json.dump(config, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
chmod 600 "$DEPLOY_PATH/judge/config.json"

echo "Deploying FlowStudy with image tags: web=$WEB_IMAGE_TAG server=$SERVER_IMAGE_TAG judge=$JUDGE_IMAGE_TAG opencode=$OPENCODE_IMAGE_TAG"

docker compose -f docker-compose.prod.yml pull nginx web server mysql redis rabbitmq judge opencode-fixed
docker compose -f docker-compose.prod.yml pull elasticsearch
# The Nginx configuration is bind-mounted. Recreate it so a synchronized
# configuration is actually loaded on an already-running ECS deployment.
docker compose -f docker-compose.prod.yml up -d --force-recreate nginx
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps

echo "Waiting for Elasticsearch ..."
for i in $(seq 1 30); do
  if docker compose -f docker-compose.prod.yml exec -T elasticsearch curl -fsS -u "elastic:${ELASTICSEARCH_PASSWORD}" http://127.0.0.1:9200/_cluster/health >/dev/null; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "Elasticsearch health check failed." >&2
    docker compose -f docker-compose.prod.yml logs --tail=200 elasticsearch >&2 || true
    exit 1
  fi
  sleep 2
done

if [ -f "$DEPLOY_PATH/mysql/migration/20260827-content-search-resource.sql" ]; then
  echo "Applying resource metadata migration ..."
  docker compose -f docker-compose.prod.yml exec -T mysql mysql \
    -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" \
    < "$DEPLOY_PATH/mysql/migration/20260827-content-search-resource.sql"
fi

echo "Waiting for http://127.0.0.1/api/health ..."
for i in $(seq 1 30); do
  if curl -fsS --max-time 5 http://127.0.0.1/api/health >/dev/null; then
    echo "Smoke test passed."
    exit 0
  fi
  sleep 2
done

echo "Smoke test failed. Recent server logs:" >&2
docker compose -f docker-compose.prod.yml logs --tail=200 server >&2 || true
exit 1
