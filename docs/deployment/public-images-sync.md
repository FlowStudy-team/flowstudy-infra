# FlowStudy 公共基础镜像同步说明

## 背景

ECS 直接从 Docker Hub 拉取 `nginx`、`mysql`、`redis`、`rabbitmq` 等公共镜像时可能失败。生产部署改为统一从华为云 SWR 拉取镜像，降低上线时的外部网络依赖。

## 同步方式

在 `flowstudy-infra` 仓库手动触发 GitHub Actions：

```text
Actions -> Sync Public Images -> Run workflow
```

该 workflow 会从 Docker Hub 拉取公共镜像，重新 tag 后推送到华为云 SWR。

## 同步镜像

```text
nginx:1.27-alpine
mysql:8.4
redis:7-alpine
rabbitmq:3.13-management-alpine
```

推送后的 SWR 镜像地址：

```text
swr.cn-east-3.myhuaweicloud.com/flowstudy/nginx:1.27-alpine
swr.cn-east-3.myhuaweicloud.com/flowstudy/mysql:8.4
swr.cn-east-3.myhuaweicloud.com/flowstudy/redis:7-alpine
swr.cn-east-3.myhuaweicloud.com/flowstudy/rabbitmq:3.13-management-alpine
```

## 依赖 Secrets

`flowstudy-infra` 仓库或 `FlowStudy-team` 组织需要配置：

```text
SWR_REGISTRY=swr.cn-east-3.myhuaweicloud.com
SWR_NAMESPACE=flowstudy
SWR_USERNAME=华为云SWR用户名
SWR_PASSWORD=华为云SWR密码或访问凭证
```

## 部署顺序

1. 确认业务镜像 `flowstudy-web`、`flowstudy-server`、`flowstudy-judge`、`flowstudy-runtime-node20-opencode` 已推送到 SWR。
2. 手动触发 `Sync Public Images`，确认公共镜像同步成功。
3. 在 ECS 执行：

```bash
cd /opt/flowstudy
./deploy.sh latest
```

## 常见错误

如果 ECS 部署时报：

```text
failed to resolve reference rabbitmq/mysql/redis/nginx
```

优先检查：

```text
1. Sync Public Images workflow 是否成功
2. SWR 组织 flowstudy 下是否存在对应镜像
3. ECS 是否已 docker login swr.cn-east-3.myhuaweicloud.com
4. /opt/flowstudy/.env 中 SWR_REGISTRY 和 SWR_NAMESPACE 是否正确
```

