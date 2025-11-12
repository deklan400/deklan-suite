#!/usr/bin/env bash
set -euo pipefail

########################################################################################
# 🚀 DEKLAN-SUITE INSTALLER — v6 (Fusion)
# Gensyn RL-Swarm (CPU) + Telegram Bot + Monitor (service & timer)
# by Deklan × GPT-5
########################################################################################

# ── Paths & Const ────────────────────────────────────────────────────────────────────
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

# ── Colors ───────────────────────────────────────────────────────────────────────────
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
msg(){ echo -e "${GREEN}✅ $1${NC}"; }
warn(){ echo -e "${YELLOW}⚠ $1${NC}"; }
fail(){ echo -e "${RED}❌ $1${NC}"; exit 1; }
info(){ echo -e "${CYAN}$1${NC}"; }

info "
=====================================================
 🔥  DEKLAN-SUITE INSTALLER — v6 (Fusion)
     RL-Swarm (CPU) + Bot + Monitor
=====================================================
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ─────────────────────────────────────────────────────────────────────────────────────
# 0) Sanity: internet + basic tools
# ─────────────────────────────────────────────────────────────────────────────────────
info "[0/9] Preparing base packages…"
apt update -y >/dev/null
apt install -y curl git jq ca-certificates gnupg build-essential lsb-release >/dev/null
msg "Base deps OK"

# ─────────────────────────────────────────────────────────────────────────────────────
# 1) Validate identity files
# ─────────────────────────────────────────────────────────────────────────────────────
info "[1/9] Checking identity files in $IDENTITY_DIR …"
mkdir -p "$IDENTITY_DIR"
missing=0
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$IDENTITY_DIR/$f" ]]; then
    warn "Missing → $IDENTITY_DIR/$f"
    missing=1
  fi
done
[[ $missing -eq 0 ]] || fail "Upload 3 file starter (swarm.pem, userApiKey.json, userData.json) ke $IDENTITY_DIR lalu jalankan ulang."

msg "Identity OK"

# ─────────────────────────────────────────────────────────────────────────────────────
# 2) Install Docker & Compose
# ─────────────────────────────────────────────────────────────────────────────────────
info "[2/9] Installing Docker…"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

  apt update -y >/dev/null
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
  systemctl enable --now docker
  msg "Docker installed"
else
  msg "Docker already installed"
  systemctl enable --now docker || true
fi

# ─────────────────────────────────────────────────────────────────────────────────────
# 3) Fetch RL-Swarm repo (CPU node)
# ─────────────────────────────────────────────────────────────────────────────────────
info "[3/9] Sync RL-Swarm repo…"
if [[ ! -d "$RL_DIR/.git" ]]; then
  rm -rf "$RL_DIR"
  git clone "$REPO_RLSWARM" "$RL_DIR" >/dev/null 2>&1 || fail "Clone RL-Swarm gagal"
  msg "Cloned → $RL_DIR"
else
  pushd "$RL_DIR" >/dev/null
  git fetch --all >/dev/null 2>&1 || true
  git reset --hard origin/main >/dev/null 2>&1 || warn "git reset failed (non-fatal)"
  popd >/dev/null
  msg "RL-Swarm updated"
fi

# ─────────────────────────────────────────────────────────────────────────────────────
# 4) Keys symlink: /root/rl-swarm/keys → /root/deklan
# ─────────────────────────────────────────────────────────────────────────────────────
info "[4/9] Linking keys → $IDENTITY_DIR"
rm -rf "$RL_DIR/keys" 2>/dev/null || true
ln -s "$IDENTITY_DIR" "$RL_DIR/keys"
msg "Symlink OK"

# ─────────────────────────────────────────────────────────────────────────────────────
# 5) Pull/Build docker image
# ─────────────────────────────────────────────────────────────────────────────────────
info "[5/9] Docker compose pull/build…"
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  fail "docker compose not found"
fi

pushd "$RL_DIR" >/dev/null
$COMPOSE pull swarm-cpu || warn "pull failed"
$COMPOSE build swarm-cpu || warn "build failed"
popd >/dev/null
msg "Docker images ready"

# ─────────────────────────────────────────────────────────────────────────────────────
# 6) Install gensyn.service (systemd)
# ─────────────────────────────────────────────────────────────────────────────────────
info "[6/9] Installing $SERVICE_NODE.service …"
cat >"/etc/systemd/system/${SERVICE_NODE}.service" <<EOF
[Unit]
Description=Gensyn RL-Swarm Node (CPU)
After=network-online.target docker.service
Wants=network-online.target docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=$RL_DIR

# Ensure keys symlink exists on every start
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

chmod 0644 "/etc/systemd/system/${SERVICE_NODE}.service"
systemctl daemon-reload
systemctl enable --now "$SERVICE_NODE"
msg "Node service installed & started"

# ─────────────────────────────────────────────────────────────────────────────────────
# 7) Install Telegram Bot (Python venv + requirements)
# ─────────────────────────────────────────────────────────────────────────────────────
info "[7/9] Installing Telegram Bot…"
apt install -y python3 python3-venv python3-pip >/dev/null
mkdir -p "$BOT_DIR"

# Pull bot.py + requirements.txt terbaru dari repo suite
curl -fsSL "$REPO_SUITE/raw/main/bot.py" -o "$BOT_DIR/bot.py" || fail "Download bot.py gagal"
cat > "$BOT_DIR/requirements.txt" <<'REQS'
python-telegram-bot==21.6
psutil==6.0.0
REQS

# Setup venv
if [[ ! -d "$BOT_DIR/.venv" ]]; then
  python3 -m venv "$BOT_DIR/.venv"
fi
source "$BOT_DIR/.venv/bin/activate"
pip install --upgrade pip >/dev/null
pip install -r "$BOT_DIR/requirements.txt" >/dev/null
deactivate
msg "Bot venv ready"

# Buat .env interaktif
info "Creating .env for bot (interactive)…"
read -rp "🔑 BOT_TOKEN: " BOT_TOKEN
read -rp "👤 CHAT_ID (admin): " CHAT_ID
read -rp "➕ ALLOWED_USER_IDS (comma, optional): " ALLOWED
read -rp "⚠ Enable Danger Zone? (y/N): " ENABLE_DZ
if [[ "$ENABLE_DZ" =~ ^[yY]$ ]]; then
  read -rp "🔐 DANGER_PASS: " DANGER_PASS
  ENABLE_DZ="1"
else
  DANGER_PASS=""
  ENABLE_DZ="0"
fi

cat > "$BOT_DIR/.env" <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
ALLOWED_USER_IDS=$ALLOWED

SERVICE_NAME=$SERVICE_NODE
NODE_NAME=deklan-node

LOG_LINES=80
LOG_MAX_CHARS=3500

ENABLE_DANGER_ZONE=$ENABLE_DZ
DANGER_PASS=$DANGER_PASS

AUTO_INSTALLER_GITHUB=https://raw.githubusercontent.com/deklan400/deklan-suite/main/

RL_DIR=$RL_DIR
KEY_DIR=$IDENTITY_DIR
EOF
chmod 600 "$BOT_DIR/.env"
msg ".env created"

# Pasang bot.service
info "Installing $SERVICE_BOT.service …"
cat >"/etc/systemd/system/${SERVICE_BOT}.service" <<EOF
[Unit]
Description=Deklan Suite Bot (Telegram Control)
After=network-online.target
Wants=network-online.target

StartLimitIntervalSec=60
StartLimitBurst=15

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$BOT_DIR
EnvironmentFile=-$BOT_DIR/.env
Environment="PATH=$BOT_DIR/.venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONIOENCODING=UTF-8"

ExecStart=/bin/bash -c '
  PYBIN="$BOT_DIR/.venv/bin/python"
  [ -x "$PYBIN" ] || PYBIN="$(command -v python3)"
  exec "$PYBIN" "$BOT_DIR/bot.py"
'

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
msg "Bot service installed & started"

# ─────────────────────────────────────────────────────────────────────────────────────
# 8) Install monitor.service + monitor.timer
# ─────────────────────────────────────────────────────────────────────────────────────
info "[8/9] Installing monitor (service+timer)…"

# Ambil monitor.py terbaru jika ada di repo suite; fallback ke payload minimal
if curl -fsSL "$REPO_SUITE/raw/main/monitor.py" -o "$BOT_DIR/monitor.py"; then
  :
else
  cat > "$BOT_DIR/monitor.py" <<'PYMON'
#!/usr/bin/env python3
import os, time, psutil, subprocess
from datetime import timedelta

E=os.getenv
SVC=E("SERVICE_NAME","gensyn")
LOG_LINES=int(E("LOG_LINES","80"))
def sh(c): 
    try: 
        return subprocess.check_output(c,shell=True,stderr=subprocess.STDOUT,text=True).strip()
    except subprocess.CalledProcessError as e:
        return (e.output or "")
def is_up(): return sh(f"systemctl is-active {SVC}")=="active"
def restart(): sh(f"systemctl restart {SVC}")
def stats():
    try:
        cpu=psutil.cpu_percent(0.5); vm=psutil.virtual_memory(); du=psutil.disk_usage("/")
        up=str(timedelta(seconds=int(time.time()-psutil.boot_time())))
        return f"CPU {cpu:.1f}% RAM {vm.percent:.1f}% Disk {du.percent:.1f}% UP {up}"
    except: return "(stats n/a)"
if not is_up():
    restart()
PYMON
  chmod +x "$BOT_DIR/monitor.py"
fi

cat >"/etc/systemd/system/monitor.service" <<EOF
[Unit]
Description=Deklan Suite Monitor (oneshot)
After=network-online.target
Wants=network-online.target
ConditionPathExists=$BOT_DIR/monitor.py

[Service]
Type=oneshot
WorkingDirectory=$BOT_DIR
EnvironmentFile=-$BOT_DIR/.env
ExecStart=/bin/bash -c '
  PYBIN="$BOT_DIR/.venv/bin/python"
  [ -x "$PYBIN" ] || PYBIN="$(command -v python3)"
  exec "$PYBIN" monitor.py
'
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
systemctl enable --now "$TIMER_MONITOR"
msg "Monitor timer installed & started"

# ─────────────────────────────────────────────────────────────────────────────────────
# 9) Done
# ─────────────────────────────────────────────────────────────────────────────────────
echo -e "
${GREEN}=====================================================
 ✅ INSTALL COMPLETE — DEKLAN-SUITE v6 (Fusion)
=====================================================
Services:
  - ${SERVICE_NODE}.service     → RL-Swarm CPU Node
  - ${SERVICE_BOT}.service      → Telegram Control Bot
  - ${TIMER_MONITOR}            → Auto Monitor Timer

Useful:
  systemctl status ${SERVICE_NODE} --no-pager
  journalctl -u ${SERVICE_NODE} -f
  systemctl status ${SERVICE_BOT} --no-pager
  journalctl -u ${SERVICE_BOT} -f
${NC}
"
