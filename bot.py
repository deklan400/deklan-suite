#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
  DEKLAN-SUITE BOT v3.6 FUSION STABLE
  Unified Node + Telegram Control System + Auto Notify Integration
  by Deklan × GPT-5
"""

import os, time, subprocess, psutil, traceback
from datetime import timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CallbackQueryHandler, ContextTypes, MessageHandler, filters

# ======================================================
# LOAD ENV (.env fallback)
# ======================================================
def load_env_file(path=".env"):
    if not os.path.exists(path): return
    with open(path) as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v)

load_env_file(os.path.join(os.path.dirname(__file__), ".env"))

env = os.getenv

BOT_TOKEN = env("BOT_TOKEN", "")
CHAT_ID   = str(env("CHAT_ID", ""))
NODE_NAME = env("NODE_NAME", "deklan-node")
SERVICE_NODE = env("SERVICE_NAME", "gensyn")
LOG_LINES = int(env("LOG_LINES", "80"))
RL_DIR    = env("RL_DIR", "/root/rl-swarm")
KEY_DIR   = env("KEY_DIR", "/root/deklan")
AUTO_REPO = env("AUTO_INSTALLER_GITHUB", "https://raw.githubusercontent.com/deklan400/deklan-suite/main/")
LOG_MAX   = int(env("LOG_MAX_CHARS", "3500"))

ALLOWED_USER_IDS = [i.strip() for i in env("ALLOWED_USER_IDS", "").split(",") if i.strip()]
ENABLE_DANGER = env("ENABLE_DANGER_ZONE", "0") == "1"
DANGER_PASS   = env("DANGER_PASS", "")

if not BOT_TOKEN or not CHAT_ID:
    print("❌ Missing BOT_TOKEN / CHAT_ID in .env")
    time.sleep(3)
    exit(1)

# ======================================================
# UTILITIES
# ======================================================
def _shell(cmd: str) -> str:
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True).strip()
    except subprocess.CalledProcessError as e:
        return (e.output or "").strip()

def _authorized(update: Update) -> bool:
    uid = str(update.effective_user.id)
    if str(update.effective_chat.id) != CHAT_ID:
        return False
    if not ALLOWED_USER_IDS:
        return uid == CHAT_ID
    return uid == CHAT_ID or uid in ALLOWED_USER_IDS

async def _send_long(upd_msg, text: str):
    CHUNK = 3500
    parts = [text[i:i+CHUNK] for i in range(0, len(text), CHUNK)]
    first = True
    for p in parts:
        try:
            if first and hasattr(upd_msg, "edit_message_text"):
                await upd_msg.edit_message_text(p, parse_mode="Markdown")
                first = False
            else:
                await upd_msg.message.reply_text(p, parse_mode="Markdown")
        except Exception:
            continue

# ======================================================
# SYSTEM OPS
# ======================================================
def _stats() -> str:
    try:
        cpu = psutil.cpu_percent(interval=0.5)
        vm = psutil.virtual_memory()
        du = psutil.disk_usage("/")
        uptime = str(timedelta(seconds=int(time.time() - psutil.boot_time())))
        return f"CPU: {cpu:.1f}%\nRAM: {vm.percent:.1f}%\nDisk: {du.percent:.1f}%\nUptime: {uptime}"
    except Exception:
        return "(system stats unavailable)"

def _logs() -> str:
    return _shell(f"journalctl -u {SERVICE_NODE} -n {LOG_LINES} --no-pager")[:LOG_MAX]

def _round():
    cmd = f"journalctl -u {SERVICE_NODE} --no-pager | grep -E 'Joining round:' | tail -n1"
    return _shell(cmd) or "(round info not found)"

def _clean():
    cmds = [
        "docker image prune -f",
        "docker container prune -f",
        "apt autoremove -y",
        "apt clean",
        "journalctl --vacuum-size=200M",
        "rm -rf /tmp/*"
    ]
    for c in cmds: _shell(c)
    return "🧹 System cleaned successfully"

def _run_remote(fname: str) -> str:
    url = f"{AUTO_REPO}{fname}"
    tmp = f"/tmp/{fname}"
    try:
        subprocess.check_output(f"curl -s -o {tmp} {url}", shell=True)
        subprocess.check_output(f"chmod +x {tmp}", shell=True)
        return subprocess.check_output(f"bash {tmp}", shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        return e.output or "ERR"

def _notify(title: str, msg: str):
    try:
        text = f"⚙️ *Deklan-Suite Auto Report*\n━━━━━━━━━━━━━━\n🖥 Host: `{os.uname().nodename}`\n🕒 {time.strftime('%Y-%m-%d %H:%M:%S')}\n━━━━━━━━━━━━━━\n*{title}*\n```\n{msg[:1800]}\n```"
        _shell(f"curl -s -X POST 'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage' -d chat_id={CHAT_ID} -d parse_mode=Markdown -d text=\"{text}\" >/dev/null 2>&1 || true")
    except Exception:
        pass

# ======================================================
# PANEL / UI
# ======================================================
def _bar(v: str) -> str:
    try:
        val = float("".join(c for c in v if (c.isdigit() or c == ".")))
        filled = int(round(val / 10))
        return "◼" * filled + "◻" * (10 - filled)
    except:
        return "◻" * 10

def _panel(name: str, service: str, stats: str, rnd: str) -> str:
    d = {}
    for ln in stats.splitlines():
        if ":" in ln:
            k, v = ln.split(":", 1)
            d[k.strip()] = v.strip()
    cpu = d.get("CPU", "0%")
    ram = d.get("RAM", "0%")
    disk = d.get("Disk", "0%")
    up = d.get("Uptime", "--")

    return f"""```
████  DEKLAN-SUITE DASHBOARD  ████

 Node       : {name}
 Service    : {service}
 Status     : ✅ RUNNING
 Round      : {rnd}
 Uptime     : {up}

 CPU  {cpu:<8} {_bar(cpu)}
 RAM  {ram:<8} {_bar(ram)}
 DISK {disk:<8} {_bar(disk)}
```"""

# ======================================================
# MENU BUTTONS
# ======================================================
def _main_menu():
    rows = [
        [InlineKeyboardButton("📊 Status", callback_data="status")],
        [InlineKeyboardButton("🟢 Start", callback_data="start"),
         InlineKeyboardButton("🔴 Stop", callback_data="stop")],
        [InlineKeyboardButton("🔁 Restart", callback_data="restart")],
        [InlineKeyboardButton("📜 Logs", callback_data="logs")],
        [InlineKeyboardButton("🧹 Clean", callback_data="clean")],
        [InlineKeyboardButton("🧩 Installer", callback_data="installer")],
        [InlineKeyboardButton("⚙ Update", callback_data="update_check")]
    ]
    if ENABLE_DANGER:
        rows.append([InlineKeyboardButton("⚠️ Danger Zone", callback_data="danger")])
    return InlineKeyboardMarkup(rows)

# ======================================================
# CALLBACK HANDLER
# ======================================================
async def handle_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    if not _authorized(update):
        return await q.edit_message_text("❌ Unauthorized access.")
    action = q.data

    if action == "status":
        panel = _panel(NODE_NAME, SERVICE_NODE, _stats(), _round())
        return await q.edit_message_text(panel, parse_mode="Markdown", reply_markup=_main_menu())

    if action in ["start", "stop", "restart"]:
        _shell(f"systemctl {action} {SERVICE_NODE}")
        _notify(f"Node {action}", f"{SERVICE_NODE} {action}ed.")
        return await q.edit_message_text(f"✅ Node {action}ed.", reply_markup=_main_menu())

    if action == "logs":
        return await _send_long(q, f"📜 *Logs*\n```\n{_logs()}\n```")

    if action == "clean":
        res = _clean()
        _notify("🧹 Clean Done", res)
        return await q.edit_message_text(res, reply_markup=_main_menu())

    if action == "installer":
        return await q.edit_message_text("🧩 Smart Installer", reply_markup=_main_menu())

    if action == "update_check":
        result = _run_remote("autoupdate.sh")
        return await _send_long(q, f"🔎 *Auto-Update Check*\n```\n{result}\n```")

    if action == "danger":
        context.user_data["awaiting_password"] = "dz_reboot"
        return await q.edit_message_text("⚠️ Enter Danger Password:", parse_mode="Markdown")

# ======================================================
# TEXT HANDLER
# ======================================================
async def text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text.strip()
    if "awaiting_password" in context.user_data:
        if text != DANGER_PASS:
            return await update.message.reply_text("❌ Wrong password.")
        await update.message.reply_text("✅ Verified, rebooting…")
        _shell("reboot")

# ======================================================
# MAIN LOOP
# ======================================================
def main():
    while True:
        try:
            app = ApplicationBuilder().token(BOT_TOKEN).build()
            app.add_handler(CallbackQueryHandler(handle_button))
            app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler))
            print("✅ DEKLAN-SUITE BOT v3.6 FUSION running...")
            app.run_polling()
        except Exception as e:
            print("❌ Error:", e)
            traceback.print_exc()
            time.sleep(10)

if __name__ == "__main__":
    main()
