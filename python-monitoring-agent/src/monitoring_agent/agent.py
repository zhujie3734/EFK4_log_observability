import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import docker
import graypy
import yaml


def load_config(path: str | Path) -> dict[str, Any]:
    with Path(path).open(encoding="utf-8") as config_file:
        return yaml.safe_load(config_file) or {}


def setup_logger(config: dict[str, Any]) -> logging.Logger:
    logger = logging.getLogger("monitoring-agent")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    console = logging.StreamHandler()
    console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(console)

    graylog = config.get("graylog", {})
    if graylog.get("enabled", False):
        logger.addHandler(
            graypy.GELFUDPHandler(graylog["host"], int(graylog.get("port", 12201)))
        )

    return logger


class MonitorAgent:
    def __init__(self, config: dict[str, Any], logger: logging.Logger) -> None:
        self.config = config
        self.logger = logger
        self.docker_client = docker.from_env()
        self.last_action_time: dict[str, datetime] = {}

    @staticmethod
    def now() -> datetime:
        return datetime.now(timezone.utc)

    def in_cooldown(self, key: str, cooldown_minutes: int) -> bool:
        last_time = self.last_action_time.get(key)
        if not last_time:
            return False
        return self.now() - last_time < timedelta(minutes=cooldown_minutes)

    def mark_action(self, key: str) -> None:
        self.last_action_time[key] = self.now()

    def send_event(
        self,
        container_name: str,
        event_type: str,
        severity: str,
        message: str,
        action: str = "none",
        result: str = "info",
        **extra_fields: object,
    ) -> None:
        level = logging.ERROR if severity == "critical" else logging.WARNING
        payload = {
            "agent": self.config.get("agent_name", "monitor-agent"),
            "container": container_name,
            "event_type": event_type,
            "severity": severity,
            "action": action,
            "result": result,
            **extra_fields,
        }
        self.logger.log(level, message, extra=payload)
        print(json.dumps({"message": message, **payload}), flush=True)

    def restart_container(
        self, container: Any, container_name: str, reason: str, cooldown_minutes: int
    ) -> None:
        cooldown_key = f"{container_name}:{reason}:restart"
        if self.in_cooldown(cooldown_key, cooldown_minutes):
            self.send_event(
                container_name,
                reason,
                "warning",
                f"{container_name} is still in {reason}; restart skipped during cooldown",
                action="restart",
                result="cooldown",
            )
            return

        try:
            container.restart(timeout=20)
            self.mark_action(cooldown_key)
            self.send_event(
                container_name,
                reason,
                "critical",
                f"{container_name} restarted because of {reason}",
                action="restart",
                result="success",
            )
        except Exception as error:
            self.send_event(
                container_name,
                reason,
                "critical",
                f"Failed to restart {container_name}: {error}",
                action="restart",
                result="failed",
            )

    def check_container(self, item: dict[str, Any]) -> None:
        container_name = item["name"]
        auto_restart = item.get("auto_restart", False)
        cooldown_minutes = item.get("cooldown_minutes", 30)

        try:
            container = self.docker_client.containers.get(container_name)
            container.reload()
        except docker.errors.NotFound:
            self.send_event(
                container_name,
                "container_not_found",
                "critical",
                f"{container_name} not found",
                result="failed",
            )
            return
        except Exception as error:
            self.send_event(
                container_name,
                "docker_api_error",
                "critical",
                f"Docker API error while checking {container_name}: {error}",
                result="failed",
            )
            return

        state = container.attrs.get("State", {})
        running = state.get("Running", False)
        status = state.get("Status")
        oom_killed = state.get("OOMKilled", False)
        exit_code = state.get("ExitCode")

        if oom_killed:
            self.send_event(
                container_name,
                "oom_killed",
                "critical",
                f"{container_name} was OOM-killed (exit_code={exit_code})",
                result="detected",
                exit_code=exit_code,
            )
            return

        if not running:
            self.send_event(
                container_name,
                "container_not_running",
                "critical",
                f"{container_name} is not running (status={status}, exit_code={exit_code})",
                result="detected",
                status=status,
                exit_code=exit_code,
            )
            return

        health_status = state.get("Health", {}).get("Status")
        if health_status == "unhealthy":
            self.send_event(
                container_name,
                "container_unhealthy",
                "critical",
                f"{container_name} is unhealthy",
                result="detected",
                health_status=health_status,
            )
            if auto_restart:
                self.restart_container(
                    container, container_name, "container_unhealthy", cooldown_minutes
                )
            return

        self.logger.info(
            "%s is healthy",
            container_name,
            extra={
                "agent": self.config.get("agent_name", "monitor-agent"),
                "container": container_name,
                "event_type": "container_ok",
                "severity": "info",
                "status": status,
                "health_status": health_status or "none",
            },
        )

    def run(self) -> None:
        interval = int(self.config.get("check_interval_seconds", 60))
        while True:
            for item in self.config.get("containers", []):
                self.check_container(item)
            time.sleep(interval)


def main() -> None:
    config_path = os.environ.get("MONITOR_CONFIG", "config/config.local.yaml")
    config = load_config(config_path)
    MonitorAgent(config, setup_logger(config)).run()


if __name__ == "__main__":
    main()
