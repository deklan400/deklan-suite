#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# ♻️  DEKLAN-SUITE UPDATE — v6 (Fusion)
#     Smart updater for RL-Swarm Node (CPU)
#     by Deklan × GPT-5
###############################################################################

SERVICE_NAME="gensyn"
RL_DIR="/root/rl-swarm"
KEY_DIR="/root/deklan"
REPO_URL="https://github.com/gensyn-ai/rl-swarm"
REQ_KEYS=("swarm.pem" "userApiKey.json" "userData.json")

# ── Colors ────────────────────────────────────────────────────────────────
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
say()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
note() { echo -e "${CYAN}$1${NC}"; }

note "
=====================================================
 ♻️  DEKLAN-SUITE UPDATE — v6 (Fusion)
=====================================================
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"


###############################################################################
# [1] Stop node
###############################################################################
note "[1/6] Stopping node service…"
systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || warn "Not running"
say "Service stopped"


###############################################################################
# [2] Validate RL-Swarm repo
###############################################################################
note "[2/6] Checking RL-Swarm repo…"

if [[ ! -d "$RL_DIR/.git" ]]; then
    warn "Repo missing → cloning fresh"
    rm -rf "$RL_DIR"
    git clone "$REPO_URL" "$RL_DIR" >/dev/null 2>&1 || fail "Clone failed"
    say "Repo cloned ✅"
else
    say "Repo exists ✅"
fi


###############################################################################
# [3] Update repo
###############################################################################
note "[3/6] Updating source…"
pushd "$RL_DIR" >/dev/null
git fetch --all >/dev/null 2>&1 || true
git reset --hard origin/main >/dev/null 2>&1 || warn "git reset failed"
popd >/dev/null
say "Repo synced ✅"


###############################################################################
# [4] Validate identity
###############################################################################
note "[4/6] Checking identity files…"
for f in "${REQ_KEYS[@]}"; do
    [[ -f "$KEY_DIR/$f" ]] || fail "Missing → $KEY_DIR/$f"
done
say "Identity OK ✅"

rm -rf "$RL_DIR/keys" 2>/dev/null || true
ln -s "$KEY_DIR" "$RL_DIR/keys"
say "Symlink OK → $RL_DIR/keys → $KEY_DIR"


###############################################################################
# [5] Rebuild Docker image
###############################################################################
note "[5/6] Pulling + building Docker image…"
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
say "Docker image updated ✅"


###############################################################################
# [6] Restart node
###############################################################################
note "[6/6] Restarting service…"
systemctl daemon-reload
systemctl restart "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    say "Node running ✅"
else
    fail "Node failed to start ❌"
fi


###############################################################################
# DONE
###############################################################################
echo -e "
${GREEN}=====================================================
 ✅ UPDATE COMPLETE — DEKLAN-SUITE v6
=====================================================
Logs:
  journalctl -u $SERVICE_NAME -n 20 --no-pager
Follow live:
  journalctl -u $SERVICE_NAME -f
=====================================================
${NC}
"
