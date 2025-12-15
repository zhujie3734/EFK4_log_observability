# Log Monitoring EFK Platform

This repository provides a modular **EFK (Elasticsearch, Fluent Bit, Fluentd, Kibana)** stack designed specifically for **logging and observability** use cases.

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
