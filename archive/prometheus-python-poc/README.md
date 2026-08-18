# Prometheus Python Proof of Concept

Historical proof of concept that compares clocks over SSH, publishes the time
difference to Pushgateway, and alerts by email. It is retained for reference and
is not maintained as a deployment-ready project.

The original combined YAML has been split into valid Prometheus, rule, and
Alertmanager example files. Runtime credentials must be supplied through
environment variables; do not store them in this directory.
