#!/usr/bin/env bash
set -euo pipefail

########################################################################################
# 💣  DEKLAN-SUITE UNINSTALL — v6.2 (Fusion Stable)
# Cleanly remove RL-Swarm Node + Telegram Bot + Monitor + Docker (safe identity handling)
# by Deklan × GPT-5
########################################################################################

SERVICE_NODE="gensyn"
SERVICE_BOT="bot"
SERVICE_MONITOR="monitor.service"
SERVICE_TIMER="monitor.timer"

RL_DIR="/root/rl-swarm"
BOT_DIR="/opt/deklan-node-bot"
KEY_DIR="/root/deklan"

REMOVE_KEYS="${REMOVE_KEYS:-0}"   # set REMOVE_KEYS=1 untuk hapus identity juga

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${CYAN}$1${NC}"; }

info "
=====================================================
 💣  DEKLAN-SUITE UNINSTALL — v6.2 (Fusion Stable)
=====================================================
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ───────────────────────────────────────────────────────────────
# 1. Stop & disable all services
# ───────────────────────────────────────────────────────────────
info "[1/6] Stopping and disabling services…"
for svc in "$SERVICE_NODE" "$SERVICE_BOT" "$SERVICE_MONITOR" "$SERVICE_TIMER"; do
  if systemctl list-unit-files | grep -q "^${svc}"; then
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    msg "Service disabled → $svc"
  else
    warn "Service not found → $svc"
  fi
done

# Remove systemd units
rm -f /etc/systemd/system/{gensyn.service,bot.service,monitor.service,monitor.timer} 2>/dev/null || true
systemctl daemon-reload
msg "Systemd entries cleaned ✅"

# ───────────────────────────────────────────────────────────────
# 2. Remove RL-Swarm
# ───────────────────────────────────────────────────────────────
info "[2/6] Removing RL-Swarm directory…"
if [[ -d "$RL_DIR" ]]; then
  rm -rf "$RL_DIR"
  msg "Removed → $RL_DIR"
else
  warn "RL-Swarm not found → skip"
fi

# ───────────────────────────────────────────────────────────────
# 3. Remove Bot directory
# ───────────────────────────────────────────────────────────────
info "[3/6] Removing Telegram bot directory…"
if [[ -d "$BOT_DIR" ]]; then
  rm -rf "$BOT_DIR"
  msg "Removed → $BOT_DIR"
else
  warn "Bot folder not found → skip"
fi

# ───────────────────────────────────────────────────────────────
# 4. Optional: Remove identity
# ───────────────────────────────────────────────────────────────
info "[4/6] Identity folder → $KEY_DIR"
if [[ "$REMOVE_KEYS" == "1" ]]; then
  if [[ -d "$KEY_DIR" ]]; then
    rm -rf "$KEY_DIR"
    msg "Identity removed ✅"
  else
    warn "Identity missing → skip"
  fi
else
  warn "Identity retained (set REMOVE_KEYS=1 to delete)"
fi

# ───────────────────────────────────────────────────────────────
# 5. Docker Cleanup
# ───────────────────────────────────────────────────────────────
info "[5/6] Cleaning Docker resources…"
if command -v docker >/dev/null 2>&1; then
  docker ps -a --filter "name=swarm-cpu" -q | xargs -r docker rm -f >/dev/null 2>&1 || true
  docker system prune -af --volumes >/dev/null 2>&1 || true
  msg "Docker cleaned ✅"
else
  warn "Docker not installed → skip"
fi

# ───────────────────────────────────────────────────────────────
# 6. System & Cache Cleanup
# ───────────────────────────────────────────────────────────────
info "[6/6] Cleaning system junk…"
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
apt autoremove -y >/dev/null 2>&1 || true
apt clean >/dev/null 2>&1 || true
journalctl --vacuum-size=150M >/dev/null 2>&1 || true
msg "System cache cleaned ✅"

# ───────────────────────────────────────────────────────────────
# 🎯 Summary
# ───────────────────────────────────────────────────────────────
echo -e "
${GREEN}=====================================================
 ✅ UNINSTALL COMPLETE — DEKLAN-SUITE v6.2
=====================================================
✔ Node, Bot, and Monitor removed
✔ Docker fully cleaned
✔ System junk purged
✔ Identity kept (unless REMOVE_KEYS=1)
-----------------------------------------------------
🧭 To reinstall later:
  bash <(curl -fsSL https://raw.githubusercontent.com/deklan400/deklan-suite/main/install.sh)
=====================================================
${NC}
"
