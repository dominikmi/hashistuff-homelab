#!/bin/bash

############################################################################
# Installation of Hashicorp Nomad, Consul and Vault single instance server #
# (two nomad, consul and clients will be set up on qemu VMs)               #
# v0.0.1 26/03/2020 Dominik Miklaszewski                                   #
############################################################################

# Versions to be used

NOMAD_VERSION=0.10.5
CONSUL_VERSION=1.7.2
VAULT_VERSION=1.3.4

# Cluster working directory

echo "Creating working folder for the cluster..."
DATA_DIR="/var/devops"

if [ ! -d "$DATA_DIR" ]; then
	sudo mkdir -p "$DATA_DIR"
	echo "cluster data folder created: $DATA_DIR"
fi

# Download directory

echo "Check and/or create download folder..."
DOWNLOAD_DIR="/opt/cluster"

if [ ! -d "$DOWNLOAD_DIR" ]; then
	sudo mkdir -p "$DOWNLOAD_DIR"
	echo "download folder created: $DOWNLOAD_DIR"
fi

cd $DOWNLOAD_DIR

# Download the binaries

echo "fetch consul binary for Linux x64.."
curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -o consul.zip

echo "fetch nomad binary for Linux x64.."
curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip

echo "fetch vault binary for linux x64.."
curl -sSL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip -o vault.zip

# Install the binaries and set up the systemd instances on the host

# Install and set up consul service
echo "Installing consul..."
unzip consul.zip
sudo install consul /usr/local/bin/consul
sudo mkdir -p /etc/consul.d
consul -autocomplete-install
complete -C /usr/local/bin/consul consul
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir -p /var/devops/consul
sudo chown -R consul:consul /var/devops/consul

echo "Installing systemd service..."
sudo touch /etc/systemd/system/consul.service
cat <<'EOF'>/etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Enable the service, but do not start it - the config files are empty and will be filled up during the course of setting up various aspects of the cluster

sudo systemctl daemon-reload
sudo systemctl enable consul.service
echo "Creating basic config file for consul..."
sudo mkdir -p /etc/consul.d
sudo mkdir -p /etc/consul.d/certs
sudo mkdir -p /etc/consul.d/policies
sudo touch /etc/consul.d/agent.hcl
sudo touch /etc/consul.d/consul.json
sudo chown -R consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/agent.hcl
sudo chmod 640 /etc/consul.d/consul.json

# Install and set up nomad service, but do not start it!

echo "Installing nomad..."
unzip nomad.zip
sudo install nomad /usr/local/bin/nomad
sudo mkdir -p /etc/nomad.d
echo "Installing autocomplete..."
nomad -autocomplete-install
complete -C /usr/local/bin/nomad nomad
sudo mkdir -p /var/devops/nomad

echo "Installing systemd service..."
sudo touch /etc/systemd/system/nomad.service
cat <<'EOF' > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable nomad.service
echo "Creating basic config for nomad..."
sudo touch /etc/nomad.d/server.hcl

# Install and set up vault service, but do not start it!

echo "Installing vault..."
unzip vault.zip
sudo install vault /usr/local/bin/vault
sudo mkdir -p /etc/vault.d
echo "Installing autocomplete..."
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
sudo setcap cap_ipc_lock=+ep /usr/bin/vault
sudo useradd --system --home /etc/vault.d --shell /bin/false vault
sudo touch /etc/systemd/system/vault.service
cat <<'EOF'>/etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target

EOF
sudo systemctl daemon-reload
sudo systemctl enable vault.service

sudo mkdir -p /etc/vault.d
sudo mkdir -p /etc/vault.d/certs
sudo touch /etc/vault.d/vault.hcl
chown -R vault:vault /etc/vault.d

echo $(consul version) |awk '{print $1, $2}'
echo $(nomad version) |awk '{print $1, $2}'
echo $(vault version) |awk '{print $1, $2}'
echo "Already installed in /usr/local/bin.."
echo "Done.."
