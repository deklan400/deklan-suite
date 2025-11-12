#!/usr/bin/env bash
set -euo pipefail

###########################################################################################
# ⚙️  DEKLAN-SUITE AUTO-UPDATE CHECKER — v6.2 (Fusion Stable)
# Periodically checks GitHub for new updates, notifies Telegram, and auto-updates if enabled
# by Deklan × GPT-5
###########################################################################################

# ── CONFIG ───────────────────────────────────────────────────────────────
REPO_URL="https://github.com/deklan400/deklan-suite"
RAW_URL="https://raw.githubusercontent.com/deklan400/deklan-suite/main"
CHECK_FILE="/opt/deklan-suite/.last_commit"
LOG_FILE="/var/log/deklan-suite.log"
CHECK_INTERVAL_HOURS=6
AUTO_UPDATE="${AUTO_UPDATE:-0}"   # Set to 1 to auto-run update.sh when new commit detected

# Load ENV (for Telegram notify)
if [[ -f "/opt/deklan-node-bot/.env" ]]; then
  source /opt/deklan-node-bot/.env
elif [[ -f ".env" ]]; then
  source .env
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; exit 1; }
info() { echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"; }

info "
=====================================================
 ⚙️  DEKLAN-SUITE AUTO-UPDATE — v6.2 (Fusion Stable)
=====================================================
"

# ── FETCH LATEST COMMIT ───────────────────────────────────────────────
LATEST_COMMIT="$(curl -fsSL https://api.github.com/repos/deklan400/deklan-suite/commits/main | jq -r .sha 2>/dev/null || echo "none")"
[[ -z "$LATEST_COMMIT" || "$LATEST_COMMIT" == "null" ]] && fail "Cannot fetch latest commit info."

mkdir -p "$(dirname "$CHECK_FILE")"
if [[ -f "$CHECK_FILE" ]]; then
    CURRENT_COMMIT=$(cat "$CHECK_FILE")
else
    CURRENT_COMMIT="none"
fi

# ── COMPARE ───────────────────────────────────────────────────────────────
if [[ "$LATEST_COMMIT" != "$CURRENT_COMMIT" ]]; then
    msg "🚀 New update detected → $LATEST_COMMIT"
    echo "$LATEST_COMMIT" > "$CHECK_FILE"

    CHANGELOG="$(curl -fsSL ${RAW_URL}/README.md | head -n 25 | sed 's/`//g' | sed 's/*//g')"

    # Telegram Notify
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        MSG="⚙️ *Deklan-Suite Update Available!*\n━━━━━━━━━━━━━━\n🕒 $(date)\n🧩 *Commit:* \`$LATEST_COMMIT\`\n📦 *Repo:* [$REPO_URL]($REPO_URL)\n━━━━━━━━━━━━━━\n*Recent Changes:*\n\`\`\`\n${CHANGELOG:0:1000}\n\`\`\`"
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="Markdown" \
            -d text="$MSG" >/dev/null 2>&1 || warn "Telegram send failed"
        msg "Telegram notification sent ✅"
    else
        warn "No Telegram credentials found — skipping notify"
    fi

    # Auto-update trigger (optional)
    if [[ "$AUTO_UPDATE" == "1" ]]; then
        info "Auto-update enabled — running update.sh..."
        bash /root/deklan-suite/update.sh || warn "Auto-update execution failed"
    fi
else
    info "No new updates — current commit still up-to-date."
fi

# ── CLEANUP LOG ───────────────────────────────────────────────────────────────
MAX_LOG_SIZE=500000
if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
    tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
    warn "Log trimmed to last 100 lines"
fi

exit 0
