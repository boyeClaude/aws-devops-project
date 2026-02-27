#!/bin/bash
set -e

# Log all output to a file so we can debug if anything goes wrong
exec > /var/log/setup.log 2>&1

echo "=========================================="
echo " Starting server setup - $(date)"
echo "=========================================="

# ─── System Update ────────────────────────────────────────────────────────────
echo ">>> Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ─── Nginx ────────────────────────────────────────────────────────────────────
echo ">>> Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
chown -R ubuntu:ubuntu /var/www/html
chmod -R 755 /var/www/html

# Add a default index page so the site isn't blank
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
  <head><title>DevOps Project</title></head>
  <body>
    <h1>Server is up!</h1>
    <p>Deployed via Terraform. CI/CD pipeline ready.</p>
  </body>
</html>
EOF

echo ">>> Nginx installed and running."

# ─── Node Exporter ────────────────────────────────────────────────────────────
echo ">>> Installing Node Exporter..."
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
echo ">>> Node Exporter installed and running."

# ─── Prometheus ───────────────────────────────────────────────────────────────
echo ">>> Installing Prometheus..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.51.0/prometheus-2.51.0.linux-amd64.tar.gz
tar xvf prometheus-2.51.0.linux-amd64.tar.gz
mv prometheus-2.51.0.linux-amd64/prometheus /usr/local/bin/
mv prometheus-2.51.0.linux-amd64/promtool /usr/local/bin/
rm -rf prometheus-2.51.0.linux-amd64*

mkdir -p /etc/prometheus /var/lib/prometheus

cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
EOF

cat > /etc/systemd/system/prometheus.service <<EOF
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
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
echo ">>> Prometheus installed and running."

# ─── Grafana ──────────────────────────────────────────────────────────────────
echo ">>> Installing Grafana..."
apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y grafana
systemctl enable grafana-server
systemctl start grafana-server
echo ">>> Grafana installed and running."

# ─── Done ─────────────────────────────────────────────────────────────────────
echo "=========================================="
echo " Setup complete - $(date)"
echo "=========================================="
echo ""
echo " Services running:"
echo "  - Nginx        → port 80"
echo "  - Node Exporter → port 9100"
echo "  - Prometheus   → port 9090"
echo "  - Grafana      → port 3000"