# Automated System Health & Alerting Daemon

A lightweight Bash-based health check tool for RHEL/CentOS/Rocky Linux systems, packaged as a `systemd` service and scheduled with a `systemd` timer. It monitors CPU load, RAM usage, disk usage (including LVM), and failed `systemd` services — logging results and raising syslog alerts when disk usage crosses a threshold.

## Features

- CPU load average vs. core count
- RAM usage (used/total, percentage)
- Disk usage per mounted filesystem, with alerting above 85%
- Detection of any failed `systemd` services
- Logs to a dedicated file (`/var/log/sys_health.log`) and to syslog via `logger`
- Runs automatically every 5 minutes via a `systemd` timer (no cron required)
- Log rotation configured out of the box

## Repository Contents

| File | Purpose |
|---|---|
| `sys_health.sh` | The monitoring script |
| `sys-health.service` | `systemd` service unit — defines how the script runs |
| `sys-health.timer` | `systemd` timer unit — defines the 5-minute schedule |
| `sys_health` | `logrotate` config for `/var/log/sys_health.log` |

## Requirements

- RHEL, CentOS, Rocky Linux, or Fedora (or any `systemd`-based distro)
- Root or `sudo` access
- Standard utilities: `bash`, `awk`, `df`, `free`, `uptime`, `nproc`, `systemctl`, `logger` (all present by default on RHEL family systems)

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

### 2. Install the script

```bash
sudo cp sys_health.sh /usr/local/bin/sys_health.sh
sudo chmod +x /usr/local/bin/sys_health.sh
```

### 3. Install the systemd unit files

```bash
sudo cp sys-health.service /etc/systemd/system/sys-health.service
sudo cp sys-health.timer /etc/systemd/system/sys-health.timer
```

### 4. Install the logrotate config (optional but recommended)

```bash
sudo cp sys_health /etc/logrotate.d/sys_health
```

### 5. Reload systemd and enable the timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sys-health.timer
```

`enable` registers the timer to start on every boot; `--now` also starts it immediately, so you don't need to wait 5 minutes for the first log entry.

## Verifying the Installation

Check that the timer is active and scheduled:

```bash
systemctl status sys-health.timer
systemctl list-timers | grep sys-health
```

Manually trigger one run instead of waiting:

```bash
sudo systemctl start sys-health.service
```

Confirm it worked:

```bash
# Application log
cat /var/log/sys_health.log

# Service-specific systemd logs
journalctl -u sys-health.service -n 20

# Syslog alerts (only appear if disk usage exceeds 85% or a service has failed)
sudo tail -f /var/log/messages | grep sys_health
```

## Configuration

Two values can be adjusted directly at the top of `sys_health.sh`:

```bash
LOGFILE="/var/log/sys_health.log"   # where results are logged
THRESHOLD=85                        # disk usage % that triggers an alert
```

The check interval is set in `sys-health.timer`:

```ini
[Timer]
OnBootSec=2min        # first run, 2 minutes after boot
OnUnitActiveSec=5min  # repeat every 5 minutes thereafter
```

After changing any `.service` or `.timer` file, reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart sys-health.timer
```

## Uninstallation

```bash
sudo systemctl disable --now sys-health.timer
sudo rm /etc/systemd/system/sys-health.service
sudo rm /etc/systemd/system/sys-health.timer
sudo rm /etc/logrotate.d/sys_health
sudo rm /usr/local/bin/sys_health.sh
sudo systemctl daemon-reload
```

## Troubleshooting

**Timer isn't firing / service didn't run**
```bash
systemctl status sys-health.timer
systemctl status sys-health.service
journalctl -u sys-health.service --since "1 hour ago"
```

**Log file isn't being written / permission-denied errors**
Check SELinux is not blocking the write (common cause on RHEL):
```bash
ls -Z /var/log/sys_health.log
sudo ausearch -m avc -ts recent
sudo restorecon -v /var/log/sys_health.log
```

**No alerts showing up in `/var/log/messages`**
Confirm `rsyslog` is running and test `logger` directly:
```bash
systemctl status rsyslog
logger -t sys_health -p local0.warning "test message"
grep sys_health /var/log/messages
```

## How It Works

```
systemd (PID 1)
   │
   ├── sys-health.timer  --fires every 5 min-->  sys-health.service
   │                                                    │
   │                                     runs /usr/local/bin/sys_health.sh
   │                                                    │
   │                    ┌───────────────────────────────┼───────────────────────┐
   │                    ▼                                ▼                       ▼
   │         writes to sys_health.log              calls logger            journalctl captures
   │         (direct >> redirection)                     │                 stdout/stderr
   │                                                      ▼
   │                                              rsyslog daemon
   │                                                      │
   │                                                      ▼
   │                                            /var/log/messages
```
