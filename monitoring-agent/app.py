import json
import logging
import time
from datetime import datetime, timedelta, timezone

import docker
import yaml
import graypy

def load_config(path="config.yaml"):
    with open(path,'r',encoding="UTF-8") as f:
        return yaml.safe_load(f)
    

def setup_logger(config):
    logger = logging.getLogger("monitoring-agent")
    logger.setLevel(logging.INFO)

    console = logging.StreamHandler()
    console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(console)

    graylog = config.get("graylog", {})
    if graylog.get("enabled", True):
        handler = graypy.GELFUDPHandler(
            graylog["host"],
            int(graylog.get("port",12201))
        )
        logger.addHandler(handler)

    return logger

class monitorAgent:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        self.docker_client = docker.from_env()
        self.last_action_time = {}

    def now(self):
        return datetime.now(timezone.utc)
    
    def in_cooldown(self, key, cooldown_minutes):
        last_time = self.last_action_time.get(key)
        if not last_time:
            return False
        return self.now - last_time < timedelta(minutes=cooldown_minutes)
    
    def mark_action(self,key):
        self.last_action_time[key] = self.now()

    def send_event(
        self,
        container_name,
        event_type,
        severity,
        message,
        action='none',
        result='info',
        **extra_fields,
    ):
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

        self.logger.log(level,message,extra=payload)
        print(json.dumps({"message": message, **payload}), flush=True)

    def restart_container(self,container,container_name, reason, cooldown_minutes):
        cooldown_key = f"{container_name}:{reason}:restart"

        if self.in_cooldown(cooldown_key, cooldown_minutes):
            self.send_event(
                container_name,
                reason,
                "warning",
                f"{container_name} is still in {reason}, restart skipped due to cooldown",
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

        except Exception as e:
            self.send_event(
                container_name,
                reason,
                "critical",
                f"Failed to restart {container_name}: {e}",
                action="restart",
                result="failed",
            )

    def check_container(self,item):
        container_name = item["name"]
        auto_restart = item.get("auto_restart", False)
        cooldown_minutes = item.get("cooldown_minutes", 30)

        try:
            container = self.docker_client.containers.get(container_name)
        except docker.errors.NotFound:
            self.send_event(
                 container_name,
                "container_not_found",
                "critical",
                f"{container_name} not found",
                result="failed",
            )

            return
        except Exception as e :
            self.send_event(
                 container_name,
                "docker_api_error",
                "critical",
                f"Docker API error while checking {container_name}: {e}",
                result="failed",
            )

        container.reload()
        state = container.attrs.get("State",{})

        running = state.get("Running", False)
        status = state.get("Status")

        oom_killed = state.get("OOMKilled", False)
        exit_code = state.get("ExitCode")

        if oom_killed:
            self.send_event(
                container_name,
                "oom_killed",
                "critical",
                f"{container_name} was OOMKilled. exit_code={exit_code}",
                result="detected",
                exit_code=exit_code,
            )
            return
        
        if not running:
            self.send_event(
                container_name,
                "container_not_running",
                "critical",
                f"{container_name} is not running. status={status}, exit_code={exit_code}",
                result="detected",
                status=status,
                exit_code=exit_code,
            )

            return
        
        health = state.get("Health", {})
        health_status = health.get("Status")

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
                self.send_event(
                    container,
                    container_name,
                    "container_unhealthy",
                    cooldown_minutes,
                    )
            return
       
        self.logger.info(
            f"{container_name} is healthy",
            extra={
                "agent": self.config.get("agent_name", "sre-agent"),
                "container": container_name,
                "event_type": "container_ok",
                "severity": "info",
                "status": status,
                "health_status": health_status or "none",
            },
        )

    def run(self):
        interval = self.config.get("check_interval_seconds",60)

        while True:
            for item in self.config.get("containers",[]):
                self.check_container(item)

            time.sleep(interval)

if __name__ == "__main__":
    config = load_config()
    logger = setup_logger(config)
    agent = monitorAgent(config,logger)
    agent.run()