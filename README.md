# Infrastructure Observability Toolkit

A small monorepo for infrastructure monitoring and observability experiments.
Each project is self-contained so it can be built, configured, and deployed
without relying on files from the repository root.

## Projects

| Project | Purpose | Status |
|---|---|---|
| [EFK Stack](efk-stack/README.md) | Fluent Bit/Fluentd log collection with Elasticsearch and Kibana | Lab / prototype |
| [Python Monitoring Agent](python-monitoring-agent/README.md) | Docker container health checks with optional Graylog output | Prototype |
| [Prometheus Container Monitor](prometheus-container-monitor/README.md) | Bash checks published through Pushgateway and alerted through Prometheus/Alertmanager | Lab / prototype |

Historical experiments that are not part of the supported deployment paths are
kept under [`archive/`](archive/README.md).

## Repository conventions

- Copy `*.example.*` files to their documented local filenames before use.
- Never commit passwords, webhook URLs, private keys, or internal hostnames.
- Run Compose commands from the selected project's directory.
- Treat the examples as a starting point and enable authentication, TLS, access
  controls, resource limits, and pinned image versions before production use.

## Quick start

Choose one project and follow its README. For example:

```bash
cd prometheus-container-monitor
cp agent/config/containers.example.conf agent/config/containers.conf
cp alertmanager/config.example.yml alertmanager/config.local.yml
docker compose config --quiet
```

## License

This repository is licensed under the terms in [LICENSE](LICENSE).
