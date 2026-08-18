# Prometheus Container Monitor

A Bash-based Docker log checker that publishes numeric results to Pushgateway.
Prometheus scrapes the metrics and sends alerts through Alertmanager.

```text
monitor.sh -> Pushgateway -> Prometheus -> Alertmanager -> Slack
```

## Configure the stack

```bash
cd prometheus-container-monitor
cp alertmanager/config.example.yml alertmanager/config.local.yml
```

Replace the placeholder Slack webhook and channel only in `config.local.yml`.
The local file is ignored by Git. Then validate and start:

```bash
ALERTMANAGER_CONFIG_FILE=./alertmanager/config.local.yml docker compose config --quiet
ALERTMANAGER_CONFIG_FILE=./alertmanager/config.local.yml docker compose up -d
```

The ports bind to localhost by default. Use firewall-restricted private bindings
if agents on other hosts must reach Pushgateway.

## Configure and test the agent

```bash
cp agent/config/containers.example.conf agent/config/containers.conf
chmod +x agent/monitor.sh

MONITOR_ENV=uat \
DRY_RUN=true \
CONFIG_FILE="$PWD/agent/config/containers.conf" \
./agent/monitor.sh
```

For a real push, omit `DRY_RUN` and set a reachable URL:

```bash
MONITOR_ENV=uat \
PUSHGATEWAY_URL=http://127.0.0.1:9091 \
./agent/monitor.sh
```

The supported environments are `uat` and `prd`. Each `container|rule` pair must
be unique because one `PUT` replaces the complete grouping key for that host.

See [docs/cron.md](docs/cron.md) for the three-times-daily cron example.
