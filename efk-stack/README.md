# EFK Stack

This project provides a modular **EFK (Elasticsearch, Fluent Bit, Fluentd,
Kibana)** stack for logging and observability experiments.

> This configuration disables Elasticsearch security and is intended for a
> local lab. Do not expose it to an untrusted network.

## Layout

```text
efk-stack/
├── compose.yaml
├── fluent-bit/
└── fluentd/
    ├── Dockerfile
    └── fluent.conf
```

## Start the central stack

```bash
cd efk-stack
docker compose build fluentd
docker compose up -d
docker compose ps
```

Elasticsearch listens on port `9200`, Kibana on `5601`, and Fluentd's forward
input on `24224`. Fluent Bit is deployed separately near the log source. Set
`FLUENTD_HOST` in its runtime environment to the reachable Fluentd hostname or
address; no internal address is committed to the repository.

The architecture focuses on **scalability, extensibility, and log source isolation**, enabling various logging source to efficiently ingest, process, and analyze logs from multiple domains.

## Design Goals

- **Clear separation of responsibilities** between log collection and log processing
- **Easy extensibility** for onboarding new log sources
- **Production-ready architecture** suitable for enterprise environments

## Architecture Overview

This EFK implementation separates **Fluent Bit** and **Fluentd** into distinct layers:

- **Fluent Bit**
  Acts as a lightweight log forwarder deployed close to log sources. It is responsible for:
  - Collecting logs from various systems
  - Performing parsing and enrichment
  - Forwarding logs to Fluentd

- **Fluentd**
  Serves as the centralized log processing layer, responsible for:
  - Advanced relabelling and routing
  - Log normalization and enrichment

This separation improves **scalability**, **fault isolation**, and **future extensibility** of the logging pipeline.

## Log Source Design

The repository is structured to support **multiple log input sources**, such as:

- Network security devices (e.g. firewalls, VPNs)
- Operating systems and infrastructure logs
- Application and service logs
- Cloud and platform audit logs

Each log source is designed as an independent input configuration, making it easy to:
- Add new log sources
- Apply source-specific parsing and filtering
- Extend the platform without impacting existing pipelines

## Extensibility

The modular design allows new log sources and processing logic to be added with minimal changes:

- New Fluent Bit inputs can be introduced without modifying Fluentd pipelines
- Fluentd offloads the parsing burden and inputs can be extended independently
- Elasticsearch index patterns can be customized per log source or security domain

This makes the platform well-suited for evolving cyber security requirements and growing log volumes.

## Use Cases

- Centralized security log aggregation
- Threat detection and investigation
- Security monitoring and auditing
- Compliance and forensic analysis

## Future Enhancements

- Migrate the EFK platform to a Kubernetes-based deployment model
- Leverage Kubernetes-native components for improved scalability and resilience
- Introduce Helm charts and GitOps-based deployment workflows


---

This project aims to provide a **flexible and extensible EFK foundation** for building modern cyber logging and observability platforms.
