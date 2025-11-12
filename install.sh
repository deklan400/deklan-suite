#!/usr/bin/env bash
set -euo pipefail

########################################################################################
# 🚀 DEKLAN-SUITE INSTALLER — v6.2 (Fusion Stable)
# Gensyn RL-Swarm (CPU) + Telegram Bot + Monitor (service & timer)
# by Deklan × GPT-5
########################################################################################

IDENTITY_DIR="/root/deklan"
RL_DIR="/root/rl-swarm"
BOT_DIR="/opt/deklan-node-bot"

SERVICE_NODE="gensyn"
SERVICE_BOT="bot"
SERVICE_MONITOR="monitor.service"
TIMER_MONITOR="monitor.timer"

REPO_RLSWARM="https://github.com/gensyn-ai/rl-swarm"
REPO_SUITE="https://github.com/deklan400/deklan-suite"

REQUIRED_FILES=("swarm.pem" "userApiKey.json" "userData.json")

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
msg(){ echo -e "${GREEN}✅ $1${NC}"; }
warn(){ echo -e "${YELLOW}⚠ $1${NC}"; }
fail(){ echo -e "${RED}❌ $1${NC}"; exit 1; }
info(){ echo -e "${CYAN}$1${NC}"; }

info "
=====================================================
🔥  DEKLAN-SUITE INSTALLER — v6.2 (Fusion Stable)
=====================================================
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ──────────────────────────────────────────────────────────────
info "[0/9] Installing base deps…"
apt update -y >/dev/null
apt install -y curl git jq ca-certificates gnupg build-essential lsb-release python3 python3-venv python3-pip >/dev/null
msg "Base deps OK"

# ──────────────────────────────────────────────────────────────
info "[1/9] Checking identity files in $IDENTITY_DIR"
mkdir -p "$IDENTITY_DIR"
for f in "${REQUIRED_FILES[@]}"; do
  [[ -f "$IDENTITY_DIR/$f" ]] || fail "❌ Missing → $f"
done
msg "Identity OK ✅"

# ──────────────────────────────────────────────────────────────
info "[2/9] Installing Docker…"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt update -y >/dev/null
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
  systemctl enable --now docker
  msg "Docker installed ✅"
else
  msg "Docker OK ✅"
  systemctl enable --now docker || true
fi

# ──────────────────────────────────────────────────────────────
info "[3/9] Fetch RL-Swarm repo…"
if [[ ! -d "$RL_DIR/.git" ]]; then
  git clone "$REPO_RLSWARM" "$RL_DIR" >/dev/null 2>&1 || fail "Clone failed"
else
  pushd "$RL_DIR" >/dev/null
  git fetch --all >/dev/null 2>&1 || true
  git reset --hard origin/main >/dev/null 2>&1 || warn "git reset failed"
  popd >/dev/null
fi
msg "RL-Swarm ready ✅"

# ──────────────────────────────────────────────────────────────
rm -rf "$RL_DIR/keys" 2>/dev/null || true
ln -s "$IDENTITY_DIR" "$RL_DIR/keys"
msg "Symlink keys → OK ✅"

# ──────────────────────────────────────────────────────────────
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi
pushd "$RL_DIR" >/dev/null
$COMPOSE pull swarm-cpu || true
$COMPOSE build swarm-cpu || true
popd >/dev/null
msg "Docker images OK ✅"

# ──────────────────────────────────────────────────────────────
info "[6/9] Creating gensyn.service …"
cat >"/etc/systemd/system/${SERVICE_NODE}.service" <<EOF
[Unit]
Description=Gensyn RL-Swarm Node (CPU)
After=network-online.target docker.service
Wants=network-online.target docker.service

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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NODE"
msg "Node service installed ✅"

# ──────────────────────────────────────────────────────────────
info "[7/9] Installing Telegram Bot…"
mkdir -p "$BOT_DIR"
curl -fsSL "$REPO_SUITE/raw/main/bot.py" -o "$BOT_DIR/bot.py" || fail "bot.py fetch failed"
cat >"$BOT_DIR/requirements.txt" <<REQ
python-telegram-bot==21.6
psutil==6.0.0
REQ
python3 -m venv "$BOT_DIR/.venv"
"$BOT_DIR/.venv/bin/pip" install --upgrade pip >/dev/null
"$BOT_DIR/.venv/bin/pip" install -r "$BOT_DIR/requirements.txt" >/dev/null
msg "Bot venv ready ✅"

read -rp "🔑 BOT_TOKEN: " BOT_TOKEN
read -rp "👤 CHAT_ID (admin): " CHAT_ID
read -rp "➕ ALLOWED_USER_IDS (comma, optional): " ALLOWED
read -rp "⚠ Enable Danger Zone? (y/N): " ENABLE_DZ
if [[ "$ENABLE_DZ" =~ ^[yY]$ ]]; then
  read -rp "🔐 DANGER_PASS: " DANGER_PASS
  ENABLE_DZ="1"
else
  DANGER_PASS=""; ENABLE_DZ="0"
fi

cat >"$BOT_DIR/.env" <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
ALLOWED_USER_IDS=$ALLOWED
SERVICE_NAME=$SERVICE_NODE
NODE_NAME=deklan-node
ENABLE_DANGER_ZONE=$ENABLE_DZ
DANGER_PASS=$DANGER_PASS
AUTO_INSTALLER_GITHUB=https://raw.githubusercontent.com/deklan400/deklan-suite/main/
RL_DIR=$RL_DIR
KEY_DIR=$IDENTITY_DIR
EOF
chmod 600 "$BOT_DIR/.env"
msg ".env created ✅"

# ──────────────────────────────────────────────────────────────
info "[7b/9] Installing bot.service (v6.2 fixed paths)…"
cat >"/etc/systemd/system/${SERVICE_BOT}.service" <<EOF
[Unit]
Description=Deklan Suite Bot (Telegram Control)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
EnvironmentFile=-$BOT_DIR/.env
ExecStart=$BOT_DIR/.venv/bin/python $BOT_DIR/bot.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_BOT"
msg "Bot service installed ✅"

# ──────────────────────────────────────────────────────────────
info "[8/9] Installing monitor.timer …"
cat >"/etc/systemd/system/monitor.service" <<EOF
[Unit]
Description=Deklan Suite Monitor
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$BOT_DIR
EnvironmentFile=-$BOT_DIR/.env
ExecStart=$BOT_DIR/.venv/bin/python $BOT_DIR/monitor.py
StandardOutput=journal
StandardError=journal
EOF

cat >"/etc/systemd/system/monitor.timer" <<'EOF'
[Unit]
Description=Run Deklan Suite Monitor periodically
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
systemctl enable --now monitor.timer
msg "Monitor timer installed ✅"

# ──────────────────────────────────────────────────────────────
echo -e "
${GREEN}=====================================================
 ✅ INSTALL COMPLETE — DEKLAN-SUITE v6.2 (Fusion Stable)
=====================================================
✔ RL-Swarm Node
✔ Telegram Control Bot
✔ Auto Monitor Timer
-----------------------------------------------------
systemctl status $SERVICE_NODE --no-pager
systemctl status $SERVICE_BOT --no-pager
journalctl -u $SERVICE_BOT -f
=====================================================${NC}
"
