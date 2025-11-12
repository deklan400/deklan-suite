#!/usr/bin/env bash
set -euo pipefail
#######################################################################################
# ♻ DEKLAN-SUITE  UPDATE — v6  (CPU Smart)
#   Universal updater for RL-Swarm  + Bot + Monitor
#######################################################################################

SERVICE_NAME="gensyn"
RL_DIR="/root/rl-swarm"
KEY_DIR="/root/deklan"
REPO_URL="https://github.com/gensyn-ai/rl-swarm"

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
say(){ echo -e "${GREEN}✅ $1${NC}"; }; warn(){ echo -e "${YELLOW}⚠ $1${NC}"; }
fail(){ echo -e "${RED}❌ $1${NC}"; exit 1; }; note(){ echo -e "${CYAN}$1${NC}"; }

note "
======================================================
♻  DEKLAN-SUITE — UPDATE NODE (v6)
======================================================
Time: $(date)
"

[[ $EUID -ne 0 ]] && fail "Run as ROOT!"

# ── Stop node first
note "[1/6] Stopping ${SERVICE_NAME}..."
systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || warn "Already stopped"

# ── Ensure repo
note "[2/6] Checking RL-Swarm repository..."
if [[ ! -d "$RL_DIR/.git" ]]; then
  warn "Repo missing → cloning fresh"
  rm -rf "$RL_DIR"
  git clone "$REPO_URL" "$RL_DIR"
  say "Repo cloned ✅"
else
  pushd "$RL_DIR" >/dev/null
  git fetch --all || true
  git reset --hard origin/main || warn "Git reset failed"
  popd >/dev/null
  say "Repo updated ✅"
fi

# ── Identity
note "[3/6] Checking identity..."
REQ=("swarm.pem" "userApiKey.json" "userData.json")
for f in "${REQ[@]}"; do [[ -f "$KEY_DIR/$f" ]] || fail "Missing → $f"; done
say "Identity OK ✅"

rm -rf "$RL_DIR/keys" 2>/dev/null || true
ln -s "$KEY_DIR" "$RL_DIR/keys"
say "Symlink OK ✅"

# ── Build image
note "[4/6] Updating Docker image..."
if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then COMPOSE="docker-compose"
else fail "docker compose not found"; fi

pushd "$RL_DIR" >/dev/null
$COMPOSE pull swarm-cpu || warn "Pull failed"
$COMPOSE build swarm-cpu || warn "Build failed"
popd >/dev/null
say "Docker image ready ✅"

# ── Restart node
note "[5/6] Restarting service..."
systemctl daemon-reload
systemctl restart "$SERVICE_NAME"
sleep 3
systemctl is-active --quiet "$SERVICE_NAME" && say "Node running ✅" || fail "Node NOT running ❌"

# ── Done
note "[6/6] Update complete!"
say "✅  DEKLAN-SUITE UPDATE FINISHED"
echo "➡ Logs: journalctl -u $SERVICE_NAME -f"
