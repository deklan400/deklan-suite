#!/usr/bin/env bash
set -euo pipefail

####################################################################################
#  DEKLAN-SUITE INSTALLER v6 (Unified)
#  by Deklan & GPT-5 — merges autoinstall + bot installer with full smart logic
####################################################################################

# --- Colors ---
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${CYAN}$1${NC}"; }

echo -e "
${CYAN}=================================================================
🚀  DEKLAN-SUITE — UNIFIED INSTALLER (Node + Telegram Bot)
=================================================================${NC}
"

[[ $EUID -ne 0 ]] && err "Run as ROOT!" && exit 1

# --- Paths ---
IDENTITY_DIR="/root/deklan"
RL_DIR="/root/rl-swarm"
BOT_DIR="/opt/deklan-node-bot"
SERVICE_NODE="gensyn"
SERVICE_BOT="bot"
REPO_NODE="https://github.com/gensyn-ai/rl-swarm"
REPO_BOT="https://github.com/deklan400/deklan-node-bot"
REQUIRED_FILES=("swarm.pem" "userapikey.json" "userData.json")

####################################################################################
# STEP 1 — Check Starter Files
####################################################################################
info "[1/12] Checking starter files..."
mkdir -p "$IDENTITY_DIR"
MISSING=()
for f in "${REQUIRED_FILES[@]}"; do
  [[ -f "$IDENTITY_DIR/$f" ]] || MISSING+=("$f")
done
if [ ${#MISSING[@]} -ne 0 ]; then
  err "Missing starter files in $IDENTITY_DIR:"
  for m in "${MISSING[@]}"; do echo " - $m"; done
  echo ""
  echo "Upload these files to $IDENTITY_DIR then rerun installer."
  exit 1
fi
msg "All starter files found ✅"

####################################################################################
# STEP 2 — Install Dependencies
####################################################################################
info "[2/12] Installing base dependencies..."
apt update -y >/dev/null
apt install -y python3 python3-venv python3-pip curl git jq ca-certificates gnupg build-essential >/dev/null
msg "Dependencies installed ✅"

####################################################################################
# STEP 3 — Install Docker & Compose
####################################################################################
info "[3/12] Installing Docker & Compose..."
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  msg "Docker installed ✅"
else
  msg "Docker already installed ✅"
fi

####################################################################################
# STEP 4 — Clone or Update RL-Swarm
####################################################################################
info "[4/12] Setting up RL-Swarm repository..."
if [[ ! -d "$RL_DIR" ]]; then
  git clone "$REPO_NODE" "$RL_DIR"
  msg "RL-Swarm cloned → $RL_DIR"
else
  warn "RL-Swarm repo exists → updating..."
  pushd "$RL_DIR" >/dev/null
  git fetch --all || true
  git reset --hard origin/main || true
  popd >/dev/null
  msg "RL-Swarm updated ✅"
fi

####################################################################################
# STEP 5 — Symlink Keys
####################################################################################
info "[5/12] Linking identity keys..."
rm -rf "$RL_DIR/keys" >/dev/null 2>&1 || true
ln -sfn "$IDENTITY_DIR" "$RL_DIR/keys"
msg "keys → $IDENTITY_DIR ✅"

####################################################################################
# STEP 6 — Pull/Build Docker
####################################################################################
info "[6/12] Pulling & building RL-Swarm container..."
pushd "$RL_DIR" >/dev/null
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi
set +e
$COMPOSE pull
$COMPOSE build swarm-cpu
set -e
popd >/dev/null
msg "Docker image ready ✅"

####################################################################################
# STEP 7 — Install gensyn.service
####################################################################################
info "[7/12] Creating gensyn.service..."
cat > /etc/systemd/system/${SERVICE_NODE}.service <<EOF
[Unit]
Description=Gensyn RL-Swarm Node
After=network-online.target docker.service
Wants=network-online.target docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=$RL_DIR
ExecStartPre=/bin/bash -c 'rm -rf $RL_DIR/keys && ln -s $IDENTITY_DIR $RL_DIR/keys'
ExecStart=/usr/bin/$COMPOSE run --rm -Pit swarm-cpu
ExecStop=/usr/bin/$COMPOSE down
Restart=always
RestartSec=5
User=root
LimitNOFILE=65535
Environment="PYTHONUNBUFFERED=1"
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ${SERVICE_NODE}
msg "Node service installed & running ✅"

####################################################################################
# STEP 8 — Clone or Update Deklan Bot Repo
####################################################################################
info "[8/12] Setting up Deklan Node Bot..."
if [[ ! -d "$BOT_DIR" ]]; then
  git clone "$REPO_BOT" "$BOT_DIR"
  msg "Bot cloned → $BOT_DIR"
else
  warn "Bot repo exists → pulling update..."
  git -C "$BOT_DIR" pull --rebase --autostash >/dev/null 2>&1 || warn "Repo update failed"
fi

####################################################################################
# STEP 9 — Python Virtualenv + Requirements
####################################################################################
info "[9/12] Preparing Python environment..."
cd "$BOT_DIR"
if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
  msg "Virtualenv created ✅"
fi
source .venv/bin/activate
pip install --upgrade pip >/dev/null
if [[ -f requirements.txt ]]; then
  pip install -r requirements.txt >/dev/null
  msg "Python requirements installed ✅"
else
  warn "No requirements.txt found → skipping"
fi

####################################################################################
# STEP 10 — Generate .env
####################################################################################
info "[10/12] Configuring environment..."
if [[ ! -f "$BOT_DIR/.env" ]]; then
  echo ""
  read -rp "🔑 BOT TOKEN: " BOT_TOKEN
  read -rp "👤 MAIN ADMIN CHAT ID: " CHAT_ID
  read -rp "➕ Extra users (comma separated, optional): " ALLOWED
  read -rp "⚠ Enable Danger Zone? (y/N): " ENABLE_DZ
  if [[ "$ENABLE_DZ" =~ ^[yY]$ ]]; then
    read -rp "🔐 Danger Password: " DANGER_PASS
    ENABLE_DZ="1"
  else
    ENABLE_DZ="0"
    DANGER_PASS=""
  fi
  cat > "$BOT_DIR/.env" <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
ALLOWED_USER_IDS=$ALLOWED
SERVICE_NAME=$SERVICE_NODE
NODE_NAME=Deklan-Node
LOG_LINES=80
ROUND_GREP_PATTERN=Joining round:
ENABLE_DANGER_ZONE=$ENABLE_DZ
DANGER_PASS=$DANGER_PASS
AUTO_INSTALLER_GITHUB=https://raw.githubusercontent.com/deklan400/deklan-suite/main/
RL_DIR=$RL_DIR
KEY_DIR=$IDENTITY_DIR
EOF
  chmod 600 "$BOT_DIR/.env"
  msg ".env generated ✅"
else
  msg ".env already exists — skipping ✅"
fi

####################################################################################
# STEP 11 — Install bot.service + monitor.timer
####################################################################################
info "[11/12] Installing services..."
cat > /etc/systemd/system/${SERVICE_BOT}.service <<EOF
[Unit]
Description=Deklan Node Bot (Telegram Control)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
EnvironmentFile=-$BOT_DIR/.env
ExecStart=$BOT_DIR/.venv/bin/python3 $BOT_DIR/bot.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/monitor.service <<EOF
[Unit]
Description=Deklan Node Monitor (oneshot)
After=network-online.target
Wants=network-online.target
ConditionPathExists=$BOT_DIR/monitor.py

[Service]
Type=oneshot
WorkingDirectory=$BOT_DIR
EnvironmentFile=-$BOT_DIR/.env
ExecStart=$BOT_DIR/.venv/bin/python3 monitor.py
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/monitor.timer <<EOF
[Unit]
Description=Run Deklan Node Monitor periodically
After=network-online.target

[Timer]
OnBootSec=2m
OnUnitActiveSec=3h
RandomizedDelaySec=45
Persistent=true
Unit=monitor.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ${SERVICE_BOT}.service monitor.timer
msg "Bot & Monitor services installed ✅"

####################################################################################
# STEP 12 — Finish
####################################################################################
echo -e "
${GREEN}✅ INSTALL COMPLETE — DEKLAN-SUITE READY
─────────────────────────────────────────────
➜ Node:      systemctl status ${SERVICE_NODE} --no-pager
➜ Bot:       systemctl status ${SERVICE_BOT} --no-pager
➜ Monitor:   systemctl status monitor.timer --no-pager
─────────────────────────────────────────────
${CYAN}To check logs:
  journalctl -u ${SERVICE_NODE} -f
  journalctl -u ${SERVICE_BOT} -f
${NC}
"
