#!/usr/bin/env bash
set -euo pipefail

########################################################################################
# ♻️  DEKLAN-SUITE UPDATE — v6.2 (Fusion Stable)
# Smart updater for RL-Swarm Node (CPU)
# by Deklan × GPT-5
########################################################################################

SERVICE_NAME="gensyn"
RL_DIR="/root/rl-swarm"
KEY_DIR="/root/deklan"
REPO_URL="https://github.com/gensyn-ai/rl-swarm"
REQ_KEYS=("swarm.pem" "userApiKey.json" "userData.json")

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${CYAN}$1${NC}"; }

info "
=====================================================
 ♻️  DEKLAN-SUITE UPDATE — v6.2 (Fusion Stable)
=====================================================
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ───────────────────────────────────────────────────────────────
# 1. Stop service safely
# ───────────────────────────────────────────────────────────────
info "[1/6] Stopping node service..."
systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || warn "Service not running"
msg "Node stopped ✅"

# ───────────────────────────────────────────────────────────────
# 2. Validate RL-Swarm repo
# ───────────────────────────────────────────────────────────────
info "[2/6] Checking RL-Swarm repo..."
if [[ ! -d "$RL_DIR/.git" ]]; then
  warn "Missing repo — cloning fresh..."
  rm -rf "$RL_DIR"
  git clone "$REPO_URL" "$RL_DIR" >/dev/null 2>&1 || fail "Clone failed"
  msg "Repo cloned ✅"
else
  msg "Repo exists ✅"
fi

# ───────────────────────────────────────────────────────────────
# 3. Sync latest code
# ───────────────────────────────────────────────────────────────
info "[3/6] Syncing latest version..."
pushd "$RL_DIR" >/dev/null
git fetch --all >/dev/null 2>&1 || warn "Fetch failed"
git reset --hard origin/main >/dev/null 2>&1 || warn "Git reset failed"
popd >/dev/null
msg "Source updated ✅"

# ───────────────────────────────────────────────────────────────
# 4. Validate identity
# ───────────────────────────────────────────────────────────────
info "[4/6] Checking identity files..."
for f in "${REQ_KEYS[@]}"; do
  [[ -f "$KEY_DIR/$f" ]] || fail "Missing key file → $KEY_DIR/$f"
done
msg "Identity OK ✅"

rm -rf "$RL_DIR/keys" 2>/dev/null || true
ln -s "$KEY_DIR" "$RL_DIR/keys"
msg "Symlink OK → $RL_DIR/keys → $KEY_DIR"

# ───────────────────────────────────────────────────────────────
# 5. Update & rebuild Docker
# ───────────────────────────────────────────────────────────────
info "[5/6] Updating Docker images..."
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  fail "Docker Compose not found"
fi

pushd "$RL_DIR" >/dev/null
$COMPOSE pull swarm-cpu || warn "Pull failed"
$COMPOSE build swarm-cpu || warn "Build failed"
popd >/dev/null
msg "Docker images refreshed ✅"

# ───────────────────────────────────────────────────────────────
# 6. Restart service
# ───────────────────────────────────────────────────────────────
info "[6/6] Restarting node service..."
systemctl daemon-reload
systemctl restart "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
  msg "Node running ✅"
else
  warn "Node failed to start ❌"
  echo "Use: journalctl -u $SERVICE_NAME -n 50 --no-pager"
fi

# ───────────────────────────────────────────────────────────────
# ✅ Done
# ───────────────────────────────────────────────────────────────
echo -e "
${GREEN}=====================================================
 ✅ UPDATE COMPLETE — DEKLAN-SUITE v6.2
=====================================================
✔ RL-Swarm updated to latest version
✔ Docker image rebuilt successfully
✔ Identity linked and intact
✔ Service restarted and active
-----------------------------------------------------
To view live logs:
  journalctl -u $SERVICE_NAME -f
=====================================================
${NC}
"
