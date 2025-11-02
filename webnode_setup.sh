#!/bin/bash
#=============================================================
#  Node Setup Script for Monitoring Lecture Environment
#-------------------------------------------------------------
#  This script installs and configures:
#   1. Node Exporter (for Prometheus)
#   2. Apache2 with demo website
#   3. Load generation scripts
#   4. Promtail (for Loki log collection)
#
#  Author: HKH Admin
#  Version: 2.0
#  Tested on: Ubuntu 22.04 LTS
#=============================================================

set -e  # Exit immediately if a command fails

#-------------------------------------------------------------
# 1. Basic System Setup
#-------------------------------------------------------------
echo "===== [1/6] Setting up basic system configuration ====="
echo "Setting hostname to web01..."
echo "web01" > /etc/hostname
hostname web01

echo "Updating and upgrading system packages..."
apt update -y && apt upgrade -y

echo "Installing essential utilities (zip, unzip, stress)..."
apt install -y zip unzip stress

#-------------------------------------------------------------
# 2. Install and Configure Node Exporter
#-------------------------------------------------------------
echo "===== [2/6] Installing Prometheus Node Exporter ====="

mkdir -p /tmp/exporter
cd /tmp/exporter

NODE_VERSION="1.10.2"
echo "Downloading Node Exporter v${NODE_VERSION}..."
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

echo "Extracting Node Exporter..."
tar xzf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

echo "Moving binary to /var/lib/node..."
mkdir -p /var/lib/node
mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /var/lib/node/

echo "Creating prometheus system user..."
groupadd --system prometheus || true
useradd -s /sbin/nologin --system -g prometheus prometheus || true

chown -R prometheus:prometheus /var/lib/node/
chmod -R 775 /var/lib/node

echo "Creating Node Exporter systemd service..."
cat <<EOF > /etc/systemd/system/node.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/var/lib/node/node_exporter
SyslogIdentifier=prometheus_node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting Node Exporter..."
systemctl daemon-reload
systemctl enable --now node
systemctl status node --no-pager

echo "✅ Node Exporter setup completed."

#-------------------------------------------------------------
# 3. Setup Apache Web Server and Demo Website
#-------------------------------------------------------------
echo "===== [3/6] Setting up Apache web server ====="
apt install -y apache2

cd /tmp/exporter
echo "Downloading sample website template..."
wget -q https://www.tooplate.com/zip-templates/2147_titan_folio.zip
unzip -q 2147_titan_folio.zip

echo "Deploying website to /var/www/html..."
cp -r 2147_titan_folio/* /var/www/html/

echo "Setting up payment page..."
mkdir -p /var/www/html/payment
wget -q -P /var/www/html/payment https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/index.html

systemctl restart apache2
echo "✅ Apache web server setup completed."

#-------------------------------------------------------------
# 4. Load Generation Scripts
#-------------------------------------------------------------
echo "===== [4/6] Setting up load generation scripts ====="
apt install -y stress

echo "Downloading load scripts..."
wget -q -P /usr/local/bin/ https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/load.sh
wget -q -P /usr/local/bin/ https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/generate_multi_logs.sh

chmod +x /usr/local/bin/load.sh /usr/local/bin/generate_multi_logs.sh

echo "Starting load generation in background..."
nohup /usr/local/bin/load.sh > /dev/null 2>&1 &
nohup /usr/local/bin/generate_multi_logs.sh > /dev/null 2>&1 &

echo "✅ Load generation setup completed."

#-------------------------------------------------------------
# 5. Install and Configure Promtail (Loki Agent)
#-------------------------------------------------------------
echo "===== [5/6] Installing Promtail (Loki log collector) ====="
cd /tmp/exporter

PROMTAIL_VERSION="3.5.7"
echo "Downloading Promtail v${PROMTAIL_VERSION}..."
wget -q https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip

echo "Extracting Promtail..."
unzip -q promtail-linux-amd64.zip

echo "Moving Promtail binary to /usr/local/bin..."
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

echo "Creating Promtail config directory and config.yml..."
mkdir -p /etc/promtail
cat <<EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://172.31.26.231:3100/loki/api/v1/push

scrape_configs:
  - job_name: varlogs
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: node1
          env: Prod
          __path__: /var/log/apache2/*.log
EOF

echo "Creating Promtail systemd service..."
cat <<EOF > /etc/systemd/system/promtail.service
[Unit]
Description=Loki Promtail
After=network.target

[Service]
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always

[Install]
WantedBy=default.target
EOF

echo "Enabling and starting Promtail service..."
systemctl daemon-reload
systemctl enable --now promtail
systemctl status promtail --no-pager

echo "✅ Promtail setup completed."

#-------------------------------------------------------------
# 6. Final Summary
#-------------------------------------------------------------
echo "============================================================="
echo "🎉  Setup completed successfully!"
echo "-------------------------------------------------------------"
echo " Node Exporter  : Running on port 9100"
echo " Apache Website : Available at http://$(hostname -I | awk '{print $1}')"
echo " Promtail Logs  : Forwarding to Loki at 172.31.26.231:3100"
echo "============================================================="
