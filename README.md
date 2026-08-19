# Infrastructure Observability Toolkit

A public repository for reusable infrastructure logging and observability
experiments. The EFK project is self-contained and can be built, configured,
and deployed without relying on files from the repository root.

## Projects

| Project | Purpose | Status |
|---|---|---|
| [EFK Stack](efk-stack/README.md) | Fluent Bit/Fluentd log collection with Elasticsearch and Kibana | Prod Verified |


This repository provides containerized observability and monitoring examples, currently focused on an EFK (Elasticsearch, Fluentd/Fluent Bit, Kibana) logging stack for centralized log collection, processing, storage, and visualization.
The repository is designed to be extensible and may include additional monitoring and observability solutions in the future, such as metrics, tracing, alerting, and other logging platforms.
