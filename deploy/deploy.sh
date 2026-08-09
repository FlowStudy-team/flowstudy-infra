#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_PATH="${ECS_DEPLOY_PATH:-/opt/flowstudy}"
cd "$DEPLOY_PATH"

INPUT_WEB_IMAGE_TAG="${WEB_IMAGE_TAG:-}"
INPUT_SERVER_IMAGE_TAG="${SERVER_IMAGE_TAG:-}"
INPUT_JUDGE_IMAGE_TAG="${JUDGE_IMAGE_TAG:-}"
INPUT_OPENCODE_IMAGE_TAG="${OPENCODE_IMAGE_TAG:-}"

if [ ! -f ".env" ]; then
  echo "Missing $DEPLOY_PATH/.env. Create it from deploy/env.example before deploying." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. "$DEPLOY_PATH/.env"
set +a

IMAGE_TAG="${1:-${IMAGE_TAG:-latest}}"
export IMAGE_TAG
export SWR_REGISTRY SWR_NAMESPACE IMAGE_TAG
export WEB_IMAGE_TAG="${INPUT_WEB_IMAGE_TAG:-${WEB_IMAGE_TAG:-$IMAGE_TAG}}"
export SERVER_IMAGE_TAG="${INPUT_SERVER_IMAGE_TAG:-${SERVER_IMAGE_TAG:-$IMAGE_TAG}}"
export JUDGE_IMAGE_TAG="${INPUT_JUDGE_IMAGE_TAG:-${JUDGE_IMAGE_TAG:-$IMAGE_TAG}}"
export OPENCODE_IMAGE_TAG="${INPUT_OPENCODE_IMAGE_TAG:-${OPENCODE_IMAGE_TAG:-$IMAGE_TAG}}"

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
        "queue_name": os.environ.get("RABBITMQ_QUEUE", "submission_queue"),
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

docker compose -f docker-compose.prod.yml pull web server judge opencode-fixed
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps

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
