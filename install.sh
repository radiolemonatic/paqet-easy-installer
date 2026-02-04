#!/usr/bin/env bash
set -e

###############################################################################
# COLORS & HELPERS
###############################################################################

BOLD="\e[1m"
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

header() {
  echo -e "\n${BOLD}${BLUE}=============================="
  echo -e "$1"
  echo -e "==============================${NC}\n"
}

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "This script must be run as root"


###############################################################################
# STEP 1 - NETWORK DISCOVERY
###############################################################################

header "STEP 1 - NETWORK DISCOVERY"

DEFAULT_ROUTE=$(ip route show default | head -n1)
INTERFACE=$(echo "$DEFAULT_ROUTE" | awk '{print $5}')
GATEWAY_IP=$(echo "$DEFAULT_ROUTE" | awk '{print $3}')

[[ -z "$INTERFACE" || -z "$GATEWAY_IP" ]] && error "Unable to detect default route"

info "Network interface : $INTERFACE"
info "Gateway IP        : $GATEWAY_IP"

ping -c 2 "$GATEWAY_IP" >/dev/null 2>&1 || warn "Gateway ping failed"

GATEWAY_MAC=$(ip neigh show "$GATEWAY_IP" | awk '{print $5}')
[[ -z "$GATEWAY_MAC" ]] && error "Unable to resolve gateway MAC address"

info "Gateway MAC       : $GATEWAY_MAC"


###############################################################################
# STEP 2 - SERVER IP DETECTION
###############################################################################

header "STEP 2 - SERVER IP DETECTION"

SERVER_IP=$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
[[ -z "$SERVER_IP" ]] && error "Unable to detect server IPv4 address"

info "Server IP         : $SERVER_IP"


###############################################################################
# STEP 3 - DOWNLOAD PAQET (LATEST RELEASE)
###############################################################################

header "STEP 3 - DOWNLOAD PAQET"

OS="linux"
ARCH="amd64"

API_URL="https://api.github.com/repos/hanselime/paqet/releases/latest"

ASSET_URL=$(curl -s "$API_URL" \
  | grep browser_download_url \
  | grep "$OS-$ARCH" \
  | cut -d '"' -f 4)

[[ -z "$ASSET_URL" ]] && error "No matching release asset found"

info "Release asset     : $ASSET_URL"

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

curl -L -o paqet.tar.gz "$ASSET_URL"
tar -xzf paqet.tar.gz

BIN_FILE=$(ls | grep paqet | head -n1)
[[ -z "$BIN_FILE" ]] && error "Paqet binary not found in archive"

mkdir -p /opt
mv "$BIN_FILE" /opt/paqet
chmod +x /opt/paqet

info "Paqet installed   : /opt/paqet"


###############################################################################
# STEP 4 - CONFIGURATION FILE
###############################################################################

header "STEP 4 - CONFIGURATION"

read -p "Listening port [443]: " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-443}

read -p "Encryption key [Ramze_Ghavi]: " SECRET_KEY
SECRET_KEY=${SECRET_KEY:-Ramze_Ghavi}

CONFIG_PATH="/opt/config.yaml"

cat > "$CONFIG_PATH" <<EOF
role: "server"

log:
  level: "info"

listen:
  addr: ":$SERVER_PORT"

network:
  interface: "$INTERFACE"

  ipv4:
    addr: "$SERVER_IP:$SERVER_PORT"
    router_mac: "$GATEWAY_MAC"

  tcp:
    local_flag: ["SA"]

transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "manual"
    nodelay: 0
    interval: 30
    resend: 0
    nocongestion: 0
    acknodelay: false
    wdelay: true

    mtu: 1350
    rcvwnd: 1024
    sndwnd: 1024

    block: "aes"
    key: "$SECRET_KEY"

    smuxbuf: 8388608
    streambuf: 4194304
EOF

info "Config written    : $CONFIG_PATH"


###############################################################################
# STEP 5 - KERNEL INTERFERENCE PREVENTION
###############################################################################

header "STEP 5 - IPTABLES & KERNEL BYPASS"

iptables -t raw    -A PREROUTING -p tcp --dport "$SERVER_PORT" -j NOTRACK
iptables -t raw    -A OUTPUT     -p tcp --sport "$SERVER_PORT" -j NOTRACK
iptables -t mangle -A OUTPUT     -p tcp --sport "$SERVER_PORT" --tcp-flags RST RST -j DROP

info "iptables rules applied"

apt update -y
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y

info "iptables rules persisted"


###############################################################################
# STEP 6 - NIC OFFLOADING DISABLE
###############################################################################

header "STEP 6 - NIC OFFLOADING"

ethtool -K "$INTERFACE" gro off gso off tso off \
  && info "Offloading disabled" \
  || warn "Offloading not supported on this interface"


###############################################################################
# STEP 7 - SYSTEMD SERVICE
###############################################################################

header "STEP 7 - SYSTEMD SERVICE"

cat > /etc/systemd/system/paqet.service <<EOF
[Unit]
Description=Paqet Tunnel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt
ExecStart=/opt/paqet run -c /opt/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now paqet

info "Service started"


###############################################################################
# DONE
###############################################################################

header "INSTALLATION COMPLETE"

systemctl --no-pager status paqet || true
