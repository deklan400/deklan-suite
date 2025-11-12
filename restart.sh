#!/usr/bin/env bash
set -euo pipefail
#######################################################################################
# 🔄 DEKLAN-SUITE  RESTART — v6  (Node + Bot + Monitor)
#######################################################################################

SERVICES=("gensyn" "bot" "monitor.timer")
RL_DIR="/root/rl-swarm"
KEY_DIR="/root/deklan"
REQ_KEYS=("swarm.pem" "userApiKey.json" "userData.json")

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
say(){ echo -e "${GREEN}✅ $1${NC}"; }; warn(){ echo -e "${YELLOW}⚠ $1${NC}"; }
fail(){ echo -e "${RED}❌ $1${NC}"; exit 1; }; note(){ echo -e "${CYAN}$1${NC}"; }

echo -e "
========================================================
🔄  DEKLAN-SUITE — RESTART ALL SERVICES (v6)
========================================================
Time: $(date)
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ── Check identity
for f in "${REQ_KEYS[@]}"; do [[ -f "$KEY_DIR/$f" ]] || fail "Missing → $KEY_DIR/$f"; done
say "Identity OK ✅"

# ── Fix keys
rm -rf "$RL_DIR/keys" 2>/dev/null || true
ln -s "$KEY_DIR" "$RL_DIR/keys"
say "Symlink OK ✅"

# ── Clean Docker zombies
note "[*] Cleaning Docker containers…"
docker ps -aq | xargs -r docker rm -f >/dev/null 2>&1 || true
say "Docker cleanup OK ✅"

# ── Restart all
for svc in "${SERVICES[@]}"; do
  note "[*] Restarting $svc ..."
  systemctl daemon-reload
  systemctl restart "$svc" || warn "$svc failed restart"
  sleep 2
  systemctl is-active --quiet "$svc" && say "$svc running ✅" || warn "$svc inactive ⚠"
done

# ── Optional tail
if [[ "${1:-}" == "-f" ]]; then
  note "[*] Tailing all logs (Ctrl+C exit)…"
  journalctl -u gensyn -u bot -u monitor.timer -f
fi

say "All services restarted ✅"
echo "➡ To follow logs: journalctl -u bot -f"
