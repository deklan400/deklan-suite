#!/usr/bin/env bash
set -euo pipefail

########################################################################################
# 📡  DEKLAN-SUITE TELEGRAM NOTIFY — v6.2 (Fusion Stable)
# Send system notifications to Telegram for Deklan-Suite
# by Deklan × GPT-5
########################################################################################

LOG_FILE="/var/log/deklan-suite.log"

# ── Load ENV ───────────────────────────────────────────────
if [[ -f "/opt/deklan-node-bot/.env" ]]; then
  source /opt/deklan-node-bot/.env
elif [[ -f ".env" ]]; then
  source .env
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

# ── Colors ───────────────────────────────────────────────
GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"
msg()  { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; exit 1; }

# ── Check Credentials ─────────────────────────────────────
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  warn "BOT_TOKEN or CHAT_ID missing. Skipping Telegram notify."
  exit 0
fi

# ── Function: send_telegram "<title>" "<body>" ─────────────
send_telegram() {
  local title="$1"
  local message="$2"
  local host="$(hostname)"
  local time_now="$(date '+%Y-%m-%d %H:%M:%S')"

  local text="⚙️ *Deklan-Suite Report*
━━━━━━━━━━━━━━
🖥 *Host:* \`$host\`
🕒 *Time:* $time_now

$title
━━━━━━━━━━━━━━
\`\`\`
$message
\`\`\`
"

  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="$text" >/dev/null 2>&1 \
    && msg "Telegram message sent: $title" \
    || warn "Failed to send Telegram message."
}

# ── Direct Call Mode ──────────────────────────────────────
if [[ "${1:-}" != "" ]]; then
  TITLE="$1"
  BODY="${2:-(no message body provided)}"
  send_telegram "$TITLE" "$BODY"
else
  warn "Usage: ./notify.sh \"Title\" \"Message body\""
fi

# ── Log Trim ──────────────────────────────────────────────
MAX_LOG_SIZE=500000
if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
  tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp"
  mv "$LOG_FILE.tmp" "$LOG_FILE"
  warn "Log trimmed to last 100 lines."
fi
