#!/usr/bin/env bash
set -euo pipefail

#######################################################################################
# 📡  DEKLAN-SUITE TELEGRAM NOTIFY — v6 (Fusion)
# Send instant status updates to your Telegram after script actions
# by Deklan × GPT-5
#######################################################################################

# Load .env from Deklan-Bot if available
if [[ -f "/opt/deklan-node-bot/.env" ]]; then
  source /opt/deklan-node-bot/.env
elif [[ -f ".env" ]]; then
  source .env
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "❌ Missing BOT_TOKEN or CHAT_ID. Cannot send Telegram message."
  exit 0
fi

# ────────────────────────────────────────────────
# FUNCTION: send_telegram "<title>" "<body>"
# ────────────────────────────────────────────────
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
    -d text="$text" >/dev/null || true
}

# Example usage:
# send_telegram "✅ Installation Complete" "Deklan-Suite node installed successfully."

# ────────────────────────────────────────────────
# If this script is called directly with args:
# ./notify.sh "Title" "Body"
# ────────────────────────────────────────────────
if [[ "${1:-}" != "" ]]; then
  TITLE="$1"
  BODY="${2:-(no message body provided)}"
  send_telegram "$TITLE" "$BODY"
fi
