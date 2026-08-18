# Python Monitoring Agent

A prototype Python agent that checks Docker container state and health, emits
structured events, and can optionally forward GELF messages to Graylog.

## Configure

```bash
cd python-monitoring-agent
cp config/config.example.yaml config/config.local.yaml
```

Edit the local file with container names and a reachable Graylog address. The
local configuration is ignored by Git.

## Run with Docker

```bash
docker compose config --quiet
docker compose up -d --build
docker compose logs -f sre-agent
```

The Docker socket grants the container powerful control over the host. Run this
agent only on trusted systems and use `auto_restart: false` until its behaviour
has been validated for each target container.

## Run locally

```bash
uv sync
MONITOR_CONFIG=config/config.local.yaml uv run monitoring-agent
```
