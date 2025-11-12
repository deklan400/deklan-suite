#!/usr/bin/env bash
set -euo pipefail
# DEKLAN-SUITE INSTALLER v1
BASE_DIR="/root/deklan-suite"
KEY_DIR="/root/deklan"
SERVICE_NAME="deklan-bot"
IDENTITY_FILES=("swarm.pem" "userapikey.json" "userData.json")

info(){ echo -e "\e[36m[INFO]\e[0m $*"; }
ok(){ echo -e "\e[32m[OK]\e[0m $*"; }
err(){ echo -e "\e[31m[ERR]\e[0m $*"; }

if [[ $EUID -ne 0 ]]; then
  err "Run this script as root!"
  exit 1
fi

mkdir -p "$BASE_DIR"
mkdir -p "$KEY_DIR"

# --- Step A: Basic deps (safe, minimal)
info "Updating packages..."
apt update -y && apt upgrade -y

info "Installing general utilities..."
apt install -y screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip python3 python3-pip python3-venv python3-dev

# --- Step B: Node + yarn (optional)
info "Installing NodeJS & Yarn (22.x)..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
# yarn
curl -o- -L https://yarnpkg.com/install.sh | bash || true
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# --- Step C: Docker
info "Installing Docker & Compose plugin..."
apt-get install -y ca-certificates gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || true
chmod a+r /etc/apt/keyrings/docker.gpg || true

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y && apt upgrade -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true

# Test docker
if command -v docker >/dev/null 2>&1; then
  docker run --rm hello-world >/dev/null 2>&1 || true
  ok "Docker appears installed."
else
  err "Docker not available. Please check logs."
fi

# --- Step D: Populate repo files if missing (safe create)
info "Creating repo skeleton in $BASE_DIR..."
# Use just placeholders if files don't exist (user will replace bot.py later or we will include)
cat > "$BASE_DIR/docker-compose.yml" <<'YAML'
version: "3.8"
services:
  swarm-cpu:
    image: gensyn/rl-swarm:latest
    container_name: swarm-cpu
    restart: unless-stopped
    volumes:
      - /root/deklan:/root/deklan:ro
    environment:
      - SOME_ENV=1
YAML

# copy bot/monitor unless exists (we expect user to push real files)
if [ ! -f "$BASE_DIR/bot.py" ]; then
  cp /dev/null "$BASE_DIR/bot.py"
fi
if [ ! -f "$BASE_DIR/monitor.py" ]; then
  cp /dev/null "$BASE_DIR/monitor.py"
fi

# --- Step E: Starter files check
info "Checking starter files in $KEY_DIR..."
MISSING=()
for f in "${IDENTITY_FILES[@]}"; do
  if [ ! -f "$KEY_DIR/$f" ]; then
    MISSING+=("$f")
  fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
  err "Starter files missing:"
  for m in "${MISSING[@]}"; do echo " - $m"; done
  echo ""
  echo "Please upload the missing files to $KEY_DIR and re-run installer."
  exit 1
fi
ok "All starter files present."

# --- Step F: systemd service for bot
info "Writing systemd unit for $SERVICE_NAME..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Deklan Suite Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${BASE_DIR}
ExecStart=/usr/bin/python3 ${BASE_DIR}/bot.py
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}.service || true

ok "Installer finished. Repo skeleton created at $BASE_DIR"
echo "Next steps:"
echo " - Put your bot.py and monitor.py into $BASE_DIR (we will provide templates)."
echo " - Ensure /root/deklan contains swarm.pem, userapikey.json, userData.json"
echo " - Start bot service: systemctl start ${SERVICE_NAME}.service"
