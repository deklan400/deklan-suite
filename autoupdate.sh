#!/usr/bin/env bash
set -euo pipefail

###########################################################################################
# ⚙️  DEKLAN-SUITE AUTO-UPDATE CHECKER — v6 Fusion
# Automatically checks GitHub for new updates and notifies Telegram
# by Deklan × GPT-5
###########################################################################################

# --- CONFIG ---
REPO_URL="https://github.com/deklan400/deklan-suite"
RAW_URL="https://raw.githubusercontent.com/deklan400/deklan-suite/main"
CHECK_FILE="/opt/deklan-suite/.last_commit"
CHECK_INTERVAL_HOURS=6

# Load ENV (for Telegram notify)
if [[ -f "/opt/deklan-node-bot/.env" ]]; then
  source /opt/deklan-node-bot/.env
elif [[ -f ".env" ]]; then
  source .env
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"
say() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# --- FETCH LATEST COMMIT ---
LATEST_COMMIT="$(curl -fsSL https://api.github.com/repos/deklan400/deklan-suite/commits/main | jq -r .sha 2>/dev/null || echo "none")"
[[ -z "$LATEST_COMMIT" || "$LATEST_COMMIT" == "null" ]] && fail "Cannot fetch latest commit info."

# --- COMPARE ---
mkdir -p "$(dirname "$CHECK_FILE")"
if [[ -f "$CHECK_FILE" ]]; then
    CURRENT_COMMIT=$(cat "$CHECK_FILE")
else
    CURRENT_COMMIT="none"
fi

if [[ "$LATEST_COMMIT" != "$CURRENT_COMMIT" ]]; then
    say "🚀 New update detected: $LATEST_COMMIT"
    echo "$LATEST_COMMIT" > "$CHECK_FILE"

    CHANGELOG="$(curl -fsSL ${RAW_URL}/README.md | head -n 30 | sed 's/`//g' | sed 's/*//g' | head -n 10)"

    # --- Send Telegram Notification ---
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        MSG="⚙️ *Deklan-Suite Update Available!*\n━━━━━━━━━━━━━━\n🕒 $(date)\n🧩 *Commit:* \`$LATEST_COMMIT\`\n📦 *Repo:* [$REPO_URL]($REPO_URL)\n━━━━━━━━━━━━━━\n*Recent Changes:*\n\`\`\`\n$CHANGELOG\n\`\`\`"
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="Markdown" \
            -d text="$MSG" >/dev/null || warn "Telegram send failed"
    else
        warn "No Telegram credentials found — skipping notify"
    fi
else
    echo -e "${CYAN}No new updates — current commit still up-to-date.${NC}"
fi
