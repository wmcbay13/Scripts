##Prometheus Node exporter install for Ubuntu

#Download archive
cd /tmp/
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.0/node_exporter-1.2.0.linux-amd64.tar.gz

#Extract archive
tar -xf node_exporter-1.2.0.linux-amd64.tar.gz

sudo mv node_exporter-1.2.0.linux-amd64/node_exporter /usr/local/bin

#Clean up files
rm -r node_exporter-1.2.0.linux-amd64*

#Create service user
sudo useradd -rs /bin/false node_exporter

#Create config file
cat << 'EOF' >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
--collector.mountstats \
--collector.logind \
--collector.processes \
--collector.ntp \
--collector.systemd \
--collector.tcpstat
Restart=always
RestartSec=10s
[Install]
WantedBy=multi-user.target
EOF

#Enable and restart service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
