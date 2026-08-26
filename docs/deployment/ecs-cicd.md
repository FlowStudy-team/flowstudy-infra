# FlowStudy ECS 单机自动化部署

## 1. 目标架构

本方案用于单台华为云 ECS 上部署 FlowStudy V1 主链路：

```text
GitHub Actions
  -> Huawei Cloud SWR
  -> SSH ECS
  -> /opt/flowstudy/deploy.sh
  -> Docker Compose
  -> http://ECS_HOST/api/health
```

当前部署服务：

| 服务 | 容器名 | 说明 |
|---|---|---|
| Nginx | `flowstudy-nginx` | 只暴露公网 `80` |
| Web | `flowstudy-web` | 前端静态站点容器 |
| Server | `flowstudy-server` | Java Core 服务，容器内 `8080` |
| MySQL | `flowstudy-mysql` | 业务数据库，不暴露 `3306` |
| Redis | `flowstudy-redis` | 缓存/预留，不暴露 `6379` |
| RabbitMQ | `flowstudy-rabbitmq` | 判题队列，不暴露管理端口 |
| Judge | `flowstudy-judge` | 消费 RabbitMQ，写回 MySQL |
| OpenCode | `flowstudy-opencode-fixed` | 内部运行时，不暴露 `4096` |

`flowstudy-ai` 暂不纳入本次部署，后续 V2 再扩展。

所有旧项目命名已废弃，部署、容器、网络、镜像和文档统一使用 `flowstudy`。

## 2. ECS 目录结构

ECS 部署目录固定为：

```text
/opt/flowstudy
```

部署后目录结构：

```text
/opt/flowstudy/
├── docker-compose.prod.yml
├── deploy.sh
├── .env
├── env.example
├── judge/
│   └── config.json
├── mysql/
│   └── init/
│       ├── 01-init.sql
│       └── 02-seed-algorithm-leetcode-style.sql
└── nginx/
    └── flowstudy.conf
```

`.env` 只保存在 ECS，不提交 Git。

## 3. ECS 初始化

ECS 已安装 Docker 和 Docker Compose 后，首次准备目录：

```bash
sudo mkdir -p /opt/flowstudy
sudo chown -R "$USER":"$USER" /opt/flowstudy
```

确认 Docker 可用：

```bash
docker version
docker compose version
```

确认已登录华为云 SWR：

```bash
docker login swr.cn-east-3.myhuaweicloud.com
```

如果公共镜像拉取不稳定，可以把以下公共镜像同步到 SWR 后再调整 `docker-compose.prod.yml`：

```text
nginx:1.27-alpine
mysql:8.4
redis:7-alpine
rabbitmq:3.13-management-alpine
```

## 4. ECS .env 示例

在 ECS 创建：

```bash
cp /opt/flowstudy/env.example /opt/flowstudy/.env
chmod 600 /opt/flowstudy/.env
vi /opt/flowstudy/.env
```

示例字段：

```env
SWR_REGISTRY=swr.cn-east-3.myhuaweicloud.com
SWR_NAMESPACE=flowstudy

IMAGE_TAG=latest
WEB_IMAGE_TAG=latest
SERVER_IMAGE_TAG=latest
JUDGE_IMAGE_TAG=latest
OPENCODE_IMAGE_TAG=latest

SPRING_PROFILES_ACTIVE=prod

MYSQL_DATABASE=flowstudy
MYSQL_USER=flowstudy
MYSQL_PASSWORD=replace-with-real-mysql-password
MYSQL_ROOT_PASSWORD=replace-with-real-root-password

REDIS_PASSWORD=replace-with-real-redis-password

RABBITMQ_DEFAULT_USER=flowstudy
RABBITMQ_DEFAULT_PASS=replace-with-real-rabbitmq-password
RABBITMQ_VHOST=/
JUDGE_SUBMISSION_QUEUE=flowstudy.judge.submission.v2

JWT_SECRET=replace-with-a-long-random-secret-at-least-32-bytes
JWT_EXPIRE_SECONDS=7200
```

不要把真实 `.env`、密码、token、私钥提交到 Git。

## 5. SWR 镜像约定

SWR 区域：

```text
华东-上海一
```

Registry：

```text
swr.cn-east-3.myhuaweicloud.com
```

组织名：

```text
flowstudy
```

镜像：

```text
swr.cn-east-3.myhuaweicloud.com/flowstudy/flowstudy-web:${WEB_IMAGE_TAG}
swr.cn-east-3.myhuaweicloud.com/flowstudy/flowstudy-server:${SERVER_IMAGE_TAG}
swr.cn-east-3.myhuaweicloud.com/flowstudy/flowstudy-judge:${JUDGE_IMAGE_TAG}
swr.cn-east-3.myhuaweicloud.com/flowstudy/flowstudy-runtime-node20-opencode:${OPENCODE_IMAGE_TAG}
```

镜像由各业务仓库 CI/CD 构建并推送到 SWR。`flowstudy-infra` 不构建应用镜像。

## 6. GitHub Secrets

在 `flowstudy-infra` 仓库配置：

| Secret | 示例 | 说明 |
|---|---|---|
| `SWR_REGISTRY` | `swr.cn-east-3.myhuaweicloud.com` | SWR registry |
| `SWR_NAMESPACE` | `flowstudy` | SWR 组织名 |
| `SWR_USERNAME` | 不写入文档 | SWR 用户名 |
| `SWR_PASSWORD` | 不写入文档 | SWR 密码或访问凭据 |
| `ECS_HOST` | `x.x.x.x` | ECS 公网 IP 或域名 |
| `ECS_USER` | `ubuntu` | SSH 用户 |
| `ECS_SSH_PRIVATE_KEY` | 不写入文档 | ECS 私钥 |
| `ECS_DEPLOY_PATH` | `/opt/flowstudy` | 部署目录 |

## 7. GitHub Actions 流程

CI：

```text
PR -> main
feature branch push
  -> docker compose config
  -> bash -n deploy.sh
  -> workflow YAML 解析
  -> 部署文档和模板存在性检查
  -> retired name 检查
```

CD：

```text
main push 或 workflow_dispatch
  -> checkout infra
  -> 校验部署模板
  -> SSH 连接 ECS
  -> 同步 docker-compose.prod.yml / deploy.sh / nginx / mysql/init
  -> 如果 ECS 没有 .env，则创建模板并失败退出
  -> 执行 /opt/flowstudy/deploy.sh
  -> curl http://ECS_HOST/api/health
```

## 8. 首次部署步骤

1. 确认业务镜像已推送到 SWR。
2. 确认 ECS 已 `docker login swr.cn-east-3.myhuaweicloud.com`。
3. 确认 GitHub Secrets 已配置。
4. 推送 `flowstudy-infra` 到 `main`，或手动运行 `Deploy` workflow。
5. 如果第一次 workflow 因缺少 `.env` 失败，登录 ECS 编辑：

```bash
vi /opt/flowstudy/.env
```

6. 再次运行 `Deploy` workflow。

手动部署也可以在 ECS 上执行：

```bash
cd /opt/flowstudy
./deploy.sh latest
```

## 9. 回滚

如果使用独立镜像 tag，优先修改 ECS `.env`：

```bash
WEB_IMAGE_TAG=previous-web-tag
SERVER_IMAGE_TAG=previous-server-tag
JUDGE_IMAGE_TAG=previous-judge-tag
OPENCODE_IMAGE_TAG=previous-opencode-tag
```

然后执行：

```bash
cd /opt/flowstudy
./deploy.sh
```

也可以通过 GitHub Actions `workflow_dispatch` 输入上一版 tag 触发回滚。

数据库回滚必须依赖上线前备份，不要直接删除 volume。

## 10. 部署成功确认

ECS 内部：

```bash
cd /opt/flowstudy
docker compose -f docker-compose.prod.yml ps
curl -f http://127.0.0.1/api/health
```

公网：

```bash
curl -f http://ECS_HOST/api/health
```

浏览器访问：

```text
http://ECS_HOST/
```

OJ 主链路验证：

```text
登录
-> 打开题目
-> 运行代码
-> 提交代码
-> Judge 消费
-> 前端显示最终结果
```

## 11. 常见问题

### docker login SWR 失败

检查：

```bash
docker login swr.cn-east-3.myhuaweicloud.com
```

确认区域、组织名、用户名、密码或访问凭据正确。

### pull 镜像失败

检查镜像 tag 是否存在：

```bash
docker pull swr.cn-east-3.myhuaweicloud.com/flowstudy/flowstudy-server:TAG
```

如果公共镜像失败，考虑把 `nginx/mysql/redis/rabbitmq` 同步到 SWR。

### /api/health 失败

优先查看：

```bash
cd /opt/flowstudy
docker compose -f docker-compose.prod.yml logs --tail=200 server
docker compose -f docker-compose.prod.yml logs --tail=200 nginx
docker compose -f docker-compose.prod.yml ps
```

`flowstudy-server` 必须实现 `GET /api/health` 并返回 `200`。

### 80 端口访问失败

检查：

```bash
sudo ss -lntp | grep ':80'
docker compose -f /opt/flowstudy/docker-compose.prod.yml logs --tail=200 nginx
```

同时确认 ECS 安全组放行 TCP `80`。

### OpenCode 4096 不应公网访问

本方案没有映射 `4096:4096`，只允许 Compose 内部网络访问：

```text
flowstudy-server -> http://opencode-fixed:4096
```

如果公网可以访问 `4096`，说明 ECS 上存在其他旧容器或安全组/iptables 规则，需要立即关闭。

### Judge 不消费任务

检查：

```bash
docker compose -f /opt/flowstudy/docker-compose.prod.yml logs --tail=200 judge
docker compose -f /opt/flowstudy/docker-compose.prod.yml logs --tail=200 rabbitmq
docker compose -f /opt/flowstudy/docker-compose.prod.yml logs --tail=200 mysql
```

重点确认：

```text
JUDGE_SUBMISSION_QUEUE=flowstudy.judge.submission.v2
RabbitMQ 用户密码正确
Judge config.json 已生成
MySQL schema 已初始化
Judge 镜像内 isolate 和编译器可用
```
