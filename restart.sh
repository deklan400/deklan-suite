#!/usr/bin/env bash
set -euo pipefail

########################################################################################
# 🔁  DEKLAN-SUITE RESTART — v6.2 (Fusion Stable)
# Restart full stack: RL-Swarm Node + Telegram Bot + Monitor Timer
# by Deklan × GPT-5
########################################################################################

SERVICES=("gensyn" "bot" "monitor.timer")
DOCKER_CLEAN=1   # Set 0 untuk skip Docker cleanup
LOG_FILE="/var/log/deklan-suite.log"
NOTIFY_SCRIPT="/root/deklan-suite/notify.sh"

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; exit 1; }
info() { echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"; }

info "
=====================================================
 🔁  DEKLAN-SUITE RESTART — v6.2 (Fusion Stable)
=====================================================
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ───────────────────────────────────────────────────────────────
# 1️⃣ Stop all services
# ───────────────────────────────────────────────────────────────
info "[1/5] Stopping services…"
for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc"; then
    systemctl stop "$svc" >/dev/null 2>&1 && msg "Stopped → $svc"
  else
    warn "$svc already stopped"
  fi
done

# ───────────────────────────────────────────────────────────────
# 2️⃣ Optional Docker cleanup
# ───────────────────────────────────────────────────────────────
if [[ "$DOCKER_CLEAN" -eq 1 ]]; then
  info "[2/5] Cleaning stale Docker objects…"
  docker container prune -f >/dev/null 2>&1 || true
  docker image prune -f >/dev/null 2>&1 || true
  msg "Docker cleaned ✅"
else
  warn "Docker cleanup skipped"
fi

# ───────────────────────────────────────────────────────────────
# 3️⃣ Reload + start sequentially
# ───────────────────────────────────────────────────────────────
info "[3/5] Reloading systemd daemon…"
systemctl daemon-reload

info "[4/5] Starting services sequentially…"
for svc in "${SERVICES[@]}"; do
  systemctl enable --now "$svc" >/dev/null 2>&1 || warn "$svc enable failed"
  sleep 2
  if systemctl is-active --quiet "$svc"; then
    msg "Running → $svc"
  else
    warn "$svc failed to start"
  fi
done

# ───────────────────────────────────────────────────────────────
# 4️⃣ Status summary
# ───────────────────────────────────────────────────────────────
info "[5/5] Final service status snapshot:"
printf "\n${CYAN}%-20s%-15s${NC}\n" "Service" "Status"
printf "${CYAN}%-20s%-15s${NC}\n" "────────────────────" "─────────────"

for svc in "${SERVICES[@]}"; do
  st=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
  if [[ "$st" == "active" ]]; then
    printf "${GREEN}%-20s%-15s${NC}\n" "$svc" "✅ active"
  else
    printf "${RED}%-20s%-15s${NC}\n" "$svc" "❌ $st"
  fi
done

# ───────────────────────────────────────────────────────────────
# 5️⃣ System stats
# ───────────────────────────────────────────────────────────────
UP=$(uptime -p 2>/dev/null || true)
FREE=$(df -h / | tail -1 | awk '{print $4}')
CPU=$(top -bn1 | awk '/Cpu/ {print 100-$8"%"}' | head -1)
RAM=$(free -m | awk '/Mem:/ {printf "%.1f%%", $3*100/$2}')

echo -e "
──────────────────────────────
🕒  Uptime : ${UP:-unknown}
⚙️  CPU    : ${CPU:-n/a}
💾  RAM    : ${RAM:-n/a}
📂  Free   : $FREE
──────────────────────────────
"

msg "All services refreshed successfully ✅"

# ───────────────────────────────────────────────────────────────
# 🔔 Telegram notification
# ───────────────────────────────────────────────────────────────
if [[ -x "$NOTIFY_SCRIPT" ]]; then
  bash "$NOTIFY_SCRIPT" "🔁 Deklan-Suite Restart Complete" "All services restarted successfully on $(hostname).
CPU: $CPU | RAM: $RAM | Free: $FREE | Uptime: ${UP:-unknown}"
else
  warn "Notify script not found → skipping Telegram notify"
fi

# ───────────────────────────────────────────────────────────────
# ✅ Summary banner
# ───────────────────────────────────────────────────────────────
echo -e "
${GREEN}=====================================================
 ✅ RESTART COMPLETE — DEKLAN-SUITE v6.2 (Fusion Stable)
=====================================================
Check logs:
  journalctl -u gensyn -n 20 --no-pager
  journalctl -u bot -n 20 --no-pager
=====================================================${NC}
"

# Trim log jika terlalu besar
MAX_LOG_SIZE=500000
if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
  tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp"
  mv "$LOG_FILE.tmp" "$LOG_FILE"
  warn "Log trimmed to last 100 lines"
fi
