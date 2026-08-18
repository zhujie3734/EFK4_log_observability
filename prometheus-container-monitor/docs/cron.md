# Scheduling with cron

Use absolute paths and explicitly set the timezone and environment. This example
runs at 05:00, 13:00, and 21:00 in London time:

```cron
CRON_TZ=Europe/London
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MONITOR_ENV=uat

0 5,13,21 * * * /bin/bash /opt/container-monitor/agent/monitor.sh >> /opt/container-monitor/agent/cron.log 2>&1
```

Copy `agent/config/containers.example.conf` to `agent/config/containers.conf`
and test the exact command manually before installing the cron entry.
