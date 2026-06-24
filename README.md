# FlowStudy Infra

`flowstudy-infra` is the infrastructure and engineering documentation repository for FlowStudy. It keeps shared contracts, local development conventions, deployment assets, database initialization scripts, Nginx configuration, and environment variable examples in one place.

## Repository Scope

This repository is responsible for:

- Project architecture and engineering documentation
- Local development environment conventions
- Docker Compose and deployment references
- MySQL initialization scripts
- RabbitMQ / Redis / Nginx infrastructure configuration
- Environment variable examples for each service

Business service source code should live in separate repositories:

- `flowstudy-frontend`
- `flowstudy-core`
- `flowstudy-judge`
- `flowstudy-ai`

## Directory Structure

```text
flowstudy-infra/
+-- deploy/                  # Deployment assets and future environment-specific configs
+-- diagrams/                # Architecture and design diagrams
+-- docs/                    # Architecture, API, database, MQ, security, deployment docs
+-- env/                     # Environment variable examples
+-- mysql/
|   +-- init/                # MySQL initialization SQL scripts
+-- nginx/                   # Nginx reverse proxy configuration
+-- rabbitmq/                # RabbitMQ definitions and related configs
+-- scripts/                 # Local development and deployment helper scripts
+-- .gitignore
+-- README.md
```

## Key Documents

- [Project overview](docs/00-project-overview.md)
- [MVP scope and roadmap](docs/01-mvp-scope-roadmap.md)
- [System architecture](docs/02-system-architecture.md)
- [Repository structure](docs/03-repository-structure.md)
- [Local development environment](docs/04-dev-environment.md)
- [REST API contract](docs/05-restful-api-contract.md)
- [Database design](docs/07-database-design.md)
- [RabbitMQ message contract](docs/08-rabbitmq-message-contract.md)
- [Docker Compose deployment](docs/15-deployment-docker-compose.md)
- [Git workflow and engineering rules](docs/16-git-workflow-engineering-rules.md)
- [Test plan](docs/17-test-plan.md)

## Local Infrastructure

The expected local middleware stack is:

| Service | Port | Purpose |
|---|---:|---|
| MySQL | 3306 | Core business data |
| Redis | 6379 | Cache, session support, rate limiting |
| RabbitMQ | 5672 | Async judge tasks and behavior events |
| RabbitMQ Management | 15672 | Local MQ inspection |
| Nginx | 80 / 443 | Production reverse proxy entry |

If `docker-compose.yml` is present in this repository, start local infrastructure with:

```bash
docker compose up -d
```

Check service status:

```bash
docker compose ps
```

Stop services:

```bash
docker compose down
```

Clear local container volumes and restart from initialization scripts:

```bash
docker compose down -v
docker compose up -d
```

## Environment Files

Example environment files are stored under `env/`:

- `env/core.env.example`
- `env/judge.env.example`
- `env/ai.env.example`
- `env/frontend.env.example`

Copy examples to local environment files as needed, but do not commit real secrets:

```text
env/core.env
env/judge.env
env/ai.env
env/frontend.env
```

Secrets such as database passwords, JWT secrets, internal service tokens, and LLM API keys must be provided through local environment files or deployment secret management.

## Development Order

For local development, start services in this order:

```text
1. flowstudy-infra: MySQL, Redis, RabbitMQ
2. flowstudy-core
3. flowstudy-judge
4. flowstudy-ai
5. flowstudy-frontend
```

## Maintenance Rules

- Keep infrastructure contracts in `docs/` synchronized with service implementations.
- Commit only example environment files, never real `.env` files.
- Keep SQL initialization scripts deterministic and safe for local development.
- Do not expose MySQL, Redis, RabbitMQ, or Judge Service directly to the public network in production.
- Update this README when top-level directories, startup commands, or service conventions change.
