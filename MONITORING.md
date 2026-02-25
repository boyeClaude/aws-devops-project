# Monitoring Setup — Phase 5, 6 & 7

This document covers the full monitoring stack installed on the EC2 server. No changes were made to the CI/CD pipeline — monitoring runs alongside it as a separate concern.

## Stack Overview

```
Node Exporter → Prometheus → Grafana
(collects metrics)  (stores metrics)  (visualizes + alerts)
```

| Tool | Purpose | Port |
|---|---|---|
| Node Exporter | Collects CPU, memory, disk, network metrics from the OS | 9100 |
| Prometheus | Scrapes and stores metrics from Node Exporter | 9090 |
| Grafana | Dashboard UI to visualize metrics and send alerts | 3000 |

All three are installed directly on the EC2 instance at `54.160.42.204`.

---

## Phase 5 — Node Exporter

Node Exporter is a Prometheus exporter that exposes Linux system metrics as an HTTP endpoint. Prometheus then scrapes this endpoint to collect the data.

### Installation

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
```

### Systemd service

Created at `/etc/systemd/system/node_exporter.service` so Node Exporter starts automatically on boot.

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

### Verify

Metrics endpoint available at:
```
http://54.160.42.204:9100/metrics
```
You should see a large list of Go runtime and OS-level metrics in plain text.

---

## Phase 6 — Prometheus

Prometheus scrapes the Node Exporter endpoint every 15 seconds and stores the data in a local time-series database.

### Installation

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.51.0/prometheus-2.51.0.linux-amd64.tar.gz
tar xvf prometheus-2.51.0.linux-amd64.tar.gz
sudo mv prometheus-2.51.0.linux-amd64/prometheus /usr/local/bin/
sudo mv prometheus-2.51.0.linux-amd64/promtool /usr/local/bin/
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus
```

### Config file

Created at `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
```

This tells Prometheus to scrape Node Exporter on `localhost:9100` every 15 seconds.

### Systemd service

Created at `/etc/systemd/system/prometheus.service`:

```ini
[Unit]
Description=Prometheus
After=network.target

[Service]
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

### Verify

Prometheus UI available at:
```
http://54.160.42.204:9090
```

Navigate to **Status → Targets** — `node_exporter` should show state **UP**.

---

## Phase 7 — Grafana

Grafana connects to Prometheus as a data source, provides a visual dashboard for all metrics, and sends email alerts when thresholds are breached.

### Installation

```bash
sudo apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update -y
sudo apt-get install -y grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

### Access

```
http://54.160.42.204:3000
```

Default credentials on first login: `admin` / `admin` — Grafana prompts you to change the password immediately.

### Data source

Connected Prometheus as the default data source via **Connections → Data sources → Add data source**:
- **Type:** Prometheus
- **URL:** `http://localhost:9090`

Grafana and Prometheus are on the same server so `localhost` is used for internal communication — the public IP is only needed for browser access.

### Dashboard

Imported the community **Node Exporter Full** dashboard (ID: `1860`) via **Dashboards → New → Import**. This provides pre-built panels for CPU, memory, disk space, network traffic, and system uptime — all populated with live data from Prometheus.

---

## CPU Alert Setup

### 1. Configure SMTP for email notifications

Edited `/etc/grafana/grafana.ini` to enable email sending via Gmail:

```ini
[smtp]
enabled = true
host = smtp.gmail.com:587
user = your.email@gmail.com
password = your_gmail_app_password
from_address = your.email@gmail.com
from_name = Grafana
```

> **Important:** The password must be a Gmail App Password, not your regular Gmail password. Generate one at Google Account → Security → App passwords. The semicolons (`;`) that prefix lines in the default config are comments — they must be removed to activate each setting.

Restart Grafana after editing:

```bash
sudo systemctl restart grafana-server
```

### 2. Create a Contact Point

In Grafana: **Alerting → Contact points → Add contact point**

| Field | Value |
|---|---|
| Name | `email-alert` |
| Integration | Email |
| Address | your email address |

Test with the **Test** button — you should receive a test email before saving.

### 3. Create the Alert Rule

In Grafana: **Alerting → Alert rules → New alert rule**

| Setting | Value |
|---|---|
| Name | `CPU Usage High` |
| Query (PromQL) | `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Condition | IS ABOVE `80` |
| Folder | `monitoring` |
| Evaluation group | `cpu-rules` (interval: 1m) |
| Pending period | 5m |
| Contact point | `email-alert` |
| Summary | `CPU usage on EC2 has exceeded 80%` |

The PromQL query calculates real CPU usage by subtracting idle time from 100%. The 5 minute pending period prevents false alarms from short spikes — CPU must stay above the threshold for 5 continuous minutes before the alert fires.

### 4. Testing the alert

To verify the full alert flow end to end, a CPU stress process was run:

```bash
dd if=/dev/zero of=/dev/null &
```

The alert progressed through states: **Normal → Pending → Firing**, and an email notification was received confirming it works. The process was stopped with:

```bash
kill %1
```

After stopping, the alert returned to **Normal** and a resolution email was received.

> For a static website on a t3.micro, 80% is the appropriate real-world threshold. The test was run at 5% purely to verify the alerting pipeline works end to end.

---

## Key Concepts

| Concept | Explanation |
|---|---|
| `localhost` vs public IP | Services on the same server communicate via `localhost`. The public IP is only for external browser access. |
| Systemd services | All three tools run as systemd services so they start automatically on server reboot. |
| PromQL | Prometheus Query Language — used to query metrics. `rate()` calculates per-second rate over a time window. |
| Pending period | Prevents noisy alerts from brief spikes. Alert must stay above threshold for the full pending period before firing. |
| Gmail App Password | A 16-character password generated specifically for third-party apps. Required because Google blocks regular passwords for SMTP. |

---

## What's Next

| Phase | Description |
|---|---|
| ✅ Phase 5 | Node Exporter installed and exposing metrics |
| ✅ Phase 6 | Prometheus installed and scraping Node Exporter |
| ✅ Phase 7 | Grafana installed, dashboard imported, CPU email alert working |
| ⏳ Phase 8 | Terraform — automate all infrastructure as code |
