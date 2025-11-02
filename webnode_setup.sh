#!/bin/bash
echo web01 > /etc/hostname
hostname web01
apt update && apt upgrade -y
apt install zip unzip stress -y
mkdir -p /tmp/exporter
cd /tmp/exporter

wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz

tar xzvf node_exporter-1.10.2.linux-amd64.tar.gz

mkdir /var/lib/node

mv /tmp/exporter/node_exporter-1.10.2.linux-amd64/node_exporter /var/lib/node/

groupadd --system prometheus
useradd -s /sbin/nologin --system -g prometheus prometheus

chown -R prometheus:prometheus /var/lib/node/
chmod -R 775 /var/lib/node

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
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/var/lib/node/node_exporter

SyslogIdentifier=prometheus_node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable node
systemctl start node
systemctl status node --no-pager
echo "##############################"
echo "Node exporter setup completed."
echo "##############################"


## Setup website.
apt install apache2 -y
cd /tmp/exporter
wget https://www.tooplate.com/zip-templates/2147_titan_folio.zip
unzip 2147_titan_folio.zip
cp -r 2147_titan_folio/* /var/www/html/
mkdir /var/www/html/payment
wget -P /var/www/html/payment https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/monitoring/index.html

systemctl restart apache2

