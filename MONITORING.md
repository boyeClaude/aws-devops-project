# Monitoring Setup — Phase 5, 6 & 7

This document covers the monitoring stack installed on the EC2 server as part of the DevOps project. No infrastructure changes were made to the CI/CD pipeline — this is a separate concern running alongside it.

## Stack Overview

```
Node Exporter → Prometheus → Grafana
(collects metrics)  (stores metrics)  (visualizes metrics)
```

| Tool | Purpose | Port |
|---|---|---|
| Node Exporter | Collects CPU, memory, disk, network metrics from the OS | 9100 |
| Prometheus | Scrapes and stores metrics from Node Exporter | 9090 |
| Grafana | Dashboard UI to visualize metrics and send alerts | 3000 |

All three are installed directly on the EC2 instance at `54.160.42.204`.

---

## Phase 5 — Node Exporter

Node Exporter is a Prometheus exporter that exposes Linux system metrics as an HTTP endpoint.

### Installation

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
```

### Systemd service

Created at `/etc/systemd/system/node_exporter.service` to run Node Exporter automatically on boot.

### Verify

Once running, metrics are available at:
```
http://54.160.42.204:9100/metrics
```

---

## Phase 6 — Prometheus

Prometheus scrapes the Node Exporter endpoint every 15 seconds and stores the metrics in a local time-series database.

### Installation

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.51.0/prometheus-2.51.0.linux-amd64.tar.gz
tar xvf prometheus-2.51.0.linux-amd64.tar.gz
sudo mv prometheus-2.51.0.linux-amd64/prometheus /usr/local/bin/
sudo mv prometheus-2.51.0.linux-amd64/promtool /usr/local/bin/
```

### Config

Created at `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
```

### Systemd service

Created at `/etc/systemd/system/prometheus.service` to run Prometheus automatically on boot, storing data in `/var/lib/prometheus/`.

### Verify

Prometheus UI available at:
```
http://54.160.42.204:9090
```

Go to **Status → Targets** and confirm `node_exporter` shows as **UP**.

---

## Phase 7 — Grafana

Grafana connects to Prometheus as a data source and provides a visual dashboard for all metrics.

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

### Data source

Connected Prometheus as the default data source:
- **URL:** `http://localhost:9090`
- Grafana and Prometheus are on the same server so `localhost` is used for internal communication

### Dashboard

Imported the community **Node Exporter Full** dashboard (ID: `1860`) from Grafana.com. This provides pre-built panels for:
- CPU usage
- Memory usage
- Disk space
- Network traffic
- System uptime

### Access

```
http://54.160.42.204:3000
```

---

## What's Next

| Phase | Description |
|---|---|
| ✅ Phase 5 | Node Exporter installed and exposing metrics |
| ✅ Phase 6 | Prometheus installed and scraping Node Exporter |
| ✅ Phase 7 | Grafana installed, connected to Prometheus, dashboard imported |
| ⏳ Phase 7 (cont.) | CPU alert rule configured in Grafana |
| ⏳ Phase 8 | Terraform — automate all infrastructure as code |
