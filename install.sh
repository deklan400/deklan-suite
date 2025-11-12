#!/usr/bin/env bash
set -euo pipefail

###########################################################################
# ⚡ DEKLAN SUITE INSTALLER — v4.0 FINAL
# All-in-One installer for Telegram Bot + Auto Monitor + RL-Swarm
###########################################################################

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; CYAN="\e[36m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; }

clear
echo -e "
${CYAN}===========================================
⚡ INSTALLING DEKLAN SUITE (v4.0)
===========================================${NC}
"

# Paths
BOT_DIR="/opt/deklan-suite"
REPO="https://github.com/deklan400/deklan-suite"
RL_DIR="/root/rl-swarm"
KEY_DIR="/root/deklan"

# -------------------------------------------------------------------------
msg "[1/7] Installing dependencies..."
apt update -y >/dev/null
apt install -y python3 python3-venv python3-pip git curl jq >/dev/null
msg "Deps OK ✅"

# -------------------------------------------------------------------------
msg "[2/7] Fetching repository..."
if [[ ! -d "$BOT_DIR" ]]; then
    git clone "$REPO" "$BOT_DIR"
    msg "Repo cloned → $BOT_DIR"
else
    warn "Repo exists → pulling update..."
    git -C "$BOT_DIR" pull --rebase --autostash >/dev/null 2>&1 || warn "Repo update failed"
fi

# -------------------------------------------------------------------------
msg "[3/7] Preparing Python venv..."
cd "$BOT_DIR"
if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
    msg "Virtualenv created ✅"
fi

"$BOT_DIR/.venv/bin/pip" install --upgrade pip >/dev/null
"$BOT_DIR/.venv/bin/pip" install -r "$BOT_DIR/requirements.txt" >/dev/null
msg "Python requirements OK ✅"

# -------------------------------------------------------------------------
msg "[4/7] Creating .env..."
echo ""
read -rp "🔑 Enter BOT TOKEN: " BOT_TOKEN
read -rp "👤 Enter Main Admin CHAT ID: " CHAT_ID
read -rp "➕ Extra allowed users? (comma separated) [optional]: " ALLOWED
read -rp "⚠ Enable Danger Zone? (y/N): " ENABLE_DZ

if [[ "$ENABLE_DZ" =~ ^[yY]$ ]]; then
    read -rp "🔐 Set Danger Password: " DANGER_PASS
    ENABLE_DZ="1"
else
    DANGER_PASS=""
    ENABLE_DZ="0"
fi

cat > "$BOT_DIR/.env" <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
ALLOWED_USER_IDS=$ALLOWED

SERVICE_NAME=gensyn
NODE_NAME=deklan-node
RL_DIR=$RL_DIR
KEY_DIR=$KEY_DIR

LOG_LINES=80
ROUND_GREP_PATTERN=Joining round:
MONITOR_TRY_REINSTALL=1
MONITOR_EVERY_MINUTES=180
LOG_MAX_CHARS=3500

AUTO_INSTALLER_GITHUB=https://raw.githubusercontent.com/deklan400/deklan-autoinstall/main/
FORCE_GIT_PULL=1
DOCKER_REBUILD=1

ENABLE_DANGER_ZONE=$ENABLE_DZ
DANGER_PASS=$DANGER_PASS
EOF
chmod 600 "$BOT_DIR/.env"
msg ".env generated ✅"

# -------------------------------------------------------------------------
msg "[5/7] Checking RL-Swarm folder..."
if [[ -d "$RL_DIR" ]]; then
    msg "RL-Swarm found → $RL_DIR"
    if [[ ! -L "$RL_DIR/keys" ]]; then
        warn "Missing keys symlink → fixing..."
        rm -rf "$RL_DIR/keys"
        ln -s "$KEY_DIR" "$RL_DIR/keys"
        msg "keys → symlinked ✅"
    else
        msg "keys → OK ✅"
    fi
else
    warn "RL-Swarm NOT found — skipping symlink"
fi

# -------------------------------------------------------------------------
msg "[6/7] Installing bot.service..."
cat > /etc/systemd/system/bot.service <<'EOF'
[Unit]
Description=Deklan Node Bot (Telegram Control)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/deklan-suite
EnvironmentFile=-/opt/deklan-suite/.env
Environment="PATH=/opt/deklan-suite/.venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/opt/deklan-suite/.venv/bin/python /opt/deklan-suite/bot.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bot
msg "bot.service installed ✅"

# -------------------------------------------------------------------------
msg "[7/7] Installing monitor.service + timer..."
cat > /etc/systemd/system/monitor.service <<'EOF'
[Unit]
Description=Deklan Node Monitor (oneshot)
After=network-online.target
Wants=network-online.target
ConditionPathExists=/opt/deklan-suite/monitor.py

[Service]
Type=oneshot
User=root
WorkingDirectory=/opt/deklan-suite
EnvironmentFile=-/opt/deklan-suite/.env
ExecStart=/opt/deklan-suite/.venv/bin/python /opt/deklan-suite/monitor.py
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/monitor.timer <<'EOF'
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
systemctl enable --now monitor.timer
msg "monitor.timer installed ✅"

# -------------------------------------------------------------------------
echo "
${GREEN}✅ INSTALL COMPLETE
-------------------------------------
Check bot:         systemctl status bot
Monitor timer:     systemctl status monitor.timer
Force monitor:     systemctl start monitor.service
Logs:              journalctl -u bot -f
-------------------------------------${NC}
"
