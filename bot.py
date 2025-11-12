#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
  DEKLAN-SUITE BOT v4.0 FUSION CINEMATIC (FULL)
  Unified Node + Telegram Control + Smart Installer + Danger Zone + Auto Notify
  by Deklan × GPT-5
"""

import os
import time
import subprocess
import psutil
from datetime import timedelta

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    ApplicationBuilder,
    CallbackQueryHandler,
    ContextTypes,
    MessageHandler,
    CommandHandler,
    filters,
)

# ======================================================
# ENV
# ======================================================
env = os.getenv

BOT_TOKEN = env("BOT_TOKEN", "")
CHAT_ID   = str(env("CHAT_ID", ""))              # chat id admin (wajib)
NODE_NAME = env("NODE_NAME", "deklan-node")      # nama node display
SERVICE_NODE = env("SERVICE_NAME", "gensyn")     # systemd service node
RL_DIR    = env("RL_DIR", "/root/rl-swarm")
KEY_DIR   = env("KEY_DIR", "/root/deklan")
AUTO_REPO = env("AUTO_INSTALLER_GITHUB", "https://raw.githubusercontent.com/deklan400/deklan-suite/main/")

LOG_LINES = int(env("LOG_LINES", "80"))
LOG_MAX   = int(env("LOG_MAX_CHARS", "3500"))

ALLOWED_USER_IDS = [i.strip() for i in env("ALLOWED_USER_IDS", "").split(",") if i.strip()]
ENABLE_DANGER = env("ENABLE_DANGER_ZONE", "0") == "1"
DANGER_PASS   = env("DANGER_PASS", "")

REQUIRED_FILES = ["swarm.pem", "userApiKey.json", "userData.json"]

if not BOT_TOKEN or not CHAT_ID:
    raise SystemExit("❌ BOT_TOKEN / CHAT_ID missing — set in .env lalu restart service bot")

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

async def _send_long_from_cb(cb, text: str):
    CHUNK = 3500
    parts = [text[i:i+CHUNK] for i in range(0, len(text), CHUNK)]
    first = True
    for p in parts:
        if first:
            try:
                await cb.edit_message_text(p, parse_mode="Markdown")
            except:
                try:
                    await cb.message.reply_text(p, parse_mode="Markdown")
                except:
                    pass
            first = False
        else:
            try:
                await cb.message.reply_text(p, parse_mode="Markdown")
            except:
                pass

async def _send_long_chat(update: Update, text: str):
    CHUNK = 3500
    parts = [text[i:i+CHUNK] for i in range(0, len(text), CHUNK)]
    for p in parts:
        try:
            await update.message.reply_text(p, parse_mode="Markdown")
        except:
            pass

def _notify(title: str, msg: str):
    if not BOT_TOKEN or not CHAT_ID:
        return
    host = os.uname().nodename
    stamp = time.strftime('%Y-%m-%d %H:%M:%S')
    body = f"⚙️ *Deklan-Suite Auto Report*\n━━━━━━━━━━━━━━\n🖥 Host: `{host}`\n🕒 {stamp}\n━━━━━━━━━━━━━━\n*{title}*\n```\n{(msg or '')[:1800]}\n```"
    _shell(
        f"curl -s -X POST 'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage' "
        f"-d chat_id={CHAT_ID} -d parse_mode=Markdown "
        f"-d text=\"{body}\" >/dev/null 2>&1 || true"
    )

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

def _round() -> str:
    cmd = f"journalctl -u {SERVICE_NODE} --no-pager | grep -E 'Joining round:' | tail -n1"
    return _shell(cmd) or "(round info not found)"

def _clean() -> str:
    cmds = [
        "docker image prune -f",
        "docker container prune -f",
        "apt autoremove -y",
        "apt clean",
        "journalctl --vacuum-size=200M",
        "rm -rf /tmp/*"
    ]
    out = []
    for c in cmds:
        out.append(f"$ {c}\n{_shell(c)}")
    return "🧹 System cleaned.\n\n" + "\n\n".join(out)[:LOG_MAX]

def _run_remote(fname: str) -> str:
    url = f"{AUTO_REPO}{fname}"
    tmp = f"/tmp/{fname}"
    try:
        subprocess.check_output(f"curl -s -o {tmp} {url}", shell=True)
        subprocess.check_output(f"chmod +x {tmp}", shell=True)
        return subprocess.check_output(f"bash {tmp}", shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        return e.output or "ERR"

# ======================================================
# DASHBOARD
# ======================================================
def _bar(v: str) -> str:
    try:
        val = float("".join(c for c in v if (c.isdigit() or c == ".")))
        filled = int(round(val / 10))
        filled = max(0, min(10, filled))
        return "◼" * filled + "◻" * (10 - filled)
    except:
        return "◻" * 10

def _panel(name: str, service: str, stats: str, rnd: str) -> str:
    d = {}
    for ln in stats.splitlines():
        if ":" in ln:
            k, v = ln.split(":", 1)
            d[k.strip()] = v.strip()

    cpu  = d.get("CPU", "0%")
    ram  = d.get("RAM", "0%")
    disk = d.get("Disk", "0%")
    up   = d.get("Uptime", "--")
    ts   = time.strftime("%Y-%m-%d %H:%M:%S")

    return f"""```
████  DEKLAN-SUITE STATUS DASHBOARD  ████

 Node       : {name}
 Service    : {service}
 Status     : ✅ RUNNING
 Round      : {rnd}
 Uptime     : {up}

 ── Resources ───────────────
 CPU        : {cpu:<8} {_bar(cpu)}
 RAM        : {ram:<8} {_bar(ram)}
 Disk       : {disk:<8} {_bar(disk)}

 ── System ─────────────────
 Identity   : {'✅ Valid' if all(os.path.isfile(os.path.join(KEY_DIR, f)) for f in REQUIRED_FILES) else '⚠ Missing'}
 Docker     : {'✅ OK' if 'docker' in _shell('which docker || echo') else '⚠ N/A'}

 Last Sync  : {ts}
```"""

# ======================================================
# MENUS
# ======================================================
def _main_menu():
    rows = [
        [InlineKeyboardButton("📊 Status", callback_data="status")],
        [InlineKeyboardButton("🟢 Start Node", callback_data="start"),
         InlineKeyboardButton("🔴 Stop Node",  callback_data="stop")],
        [InlineKeyboardButton("🔁 Restart", callback_data="restart")],
        [InlineKeyboardButton("📜 Logs", callback_data="logs")],
        [InlineKeyboardButton("🧹 Safe Clean", callback_data="clean")],
        [InlineKeyboardButton("🧩 Smart Installer", callback_data="installer")],
        [InlineKeyboardButton("⚙ Auto-Update Check", callback_data="update_check")],
        [InlineKeyboardButton("❓ Help", callback_data="help")],
    ]
    if ENABLE_DANGER:
        rows.append([InlineKeyboardButton("⚠️ Danger Zone", callback_data="danger")])
    return InlineKeyboardMarkup(rows)

def _installer_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📦 Install",   callback_data="inst_install")],
        [InlineKeyboardButton("🔄 Reinstall", callback_data="inst_reinstall")],
        [InlineKeyboardButton("♻ Update",     callback_data="inst_update")],
        [InlineKeyboardButton("🧹 Uninstall", callback_data="inst_uninstall")],
        [InlineKeyboardButton("⬅ Back",       callback_data="back")],
    ])

def _danger_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🔥 Remove Node",   callback_data="dz_rm_node")],
        [InlineKeyboardButton("🐋 Clean Docker",  callback_data="dz_rm_docker")],
        [InlineKeyboardButton("💾 Remove Swap",   callback_data="dz_rm_swap")],
        [InlineKeyboardButton("🧹 Full Clean",    callback_data="dz_clean_all")],
        [InlineKeyboardButton("💣 Reboot VPS",    callback_data="dz_reboot")],
        [InlineKeyboardButton("⬅ Back",          callback_data="back")],
    ])

# ======================================================
# CALLBACKS (BUTTONS)
# ======================================================
async def handle_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    if not _authorized(update):
        return await q.edit_message_text("❌ Unauthorized.")

    action = q.data

    if action == "status":
        panel = _panel(NODE_NAME, SERVICE_NODE, _stats(), _round())
        return await q.edit_message_text(panel, parse_mode="Markdown", reply_markup=_main_menu())

    if action in ["start", "stop", "restart"]:
        _shell(f"systemctl {action} {SERVICE_NODE}")
        _notify(f"Node {action.title()}", f"{SERVICE_NODE} {action} executed.")
        return await q.edit_message_text(f"✅ Node {action} executed.", reply_markup=_main_menu())

    if action == "logs":
        logs = _logs()
        return await _send_long_from_cb(q, f"📜 *Last logs*\n```\n{logs}\n```")

    if action == "clean":
        res = _clean()
        _notify("🧹 Clean Done", res)
        return await q.edit_message_text(res, reply_markup=_main_menu())

    if action == "installer":
        return await q.edit_message_text("🧩 *Smart Installer*", parse_mode="Markdown", reply_markup=_installer_menu())

    if action.startswith("inst_"):
        mode = action.split("_", 1)[1]
        fname = {
            "install":   "install.sh",
            "reinstall": "reinstall.sh",
            "update":    "update.sh",
            "uninstall": "uninstall.sh",
        }.get(mode, "install.sh")
        result = _run_remote(fname)
        _notify(f"⚙️ {mode.title()} Complete", result[:800] if result else "")
        return await _send_long_from_cb(q, f"✅ Done\n```\n{result}\n```")

    if action == "update_check":
        result = _run_remote("autoupdate.sh")
        return await _send_long_from_cb(q, f"🔎 *Auto-Update Check*\n```\n{result}\n```")

    if action == "help":
        helptext = (
            "*Deklan-Suite Commands*\n"
            "• /status — status + dashboard\n"
            "• /logs —  tail logs service\n"
            "• /restart — restart service node\n"
            "• /help — this help\n\n"
            "Use menu buttons for actions. Danger Zone is password-protected."
        )
        return await q.edit_message_text(helptext, parse_mode="Markdown", reply_markup=_main_menu())

    if action == "danger":
        if not ENABLE_DANGER:
            return await q.edit_message_text("⚠️ Danger Zone disabled.", reply_markup=_main_menu())
        return await q.edit_message_text("⚠️ *Danger Zone*\nKetik password (reply pesan ini):", parse_mode="Markdown", reply_markup=_danger_menu())

    if action.startswith("dz_"):
        context.user_data["awaiting_password"] = action
        return await q.edit_message_text(f"⚠️ `{action.replace('dz_', '').upper()}` — Enter Danger Password:", parse_mode="Markdown")

    if action == "back":
        return await q.edit_message_text("⚡ Main Menu", reply_markup=_main_menu())

# ======================================================
# TEXT HANDLER (Danger Zone password + plain text)
# ======================================================
async def text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update):
        return await update.message.reply_text("❌ Unauthorized.")
    text = (update.message.text or "").strip()

    if "awaiting_password" in context.user_data:
        action = context.user_data.pop("awaiting_password")
        if text != DANGER_PASS:
            return await update.message.reply_text("❌ Wrong password.")
        await update.message.reply_text("✅ Verified! Executing…")
        if action == "dz_rm_node":
            res = _shell(f"systemctl stop {SERVICE_NODE}; rm -rf {RL_DIR}")
        elif action == "dz_rm_docker":
            res = _shell("docker system prune -af")
        elif action == "dz_rm_swap":
            res = _shell("swapoff -a; rm -f /swapfile; sed -i '/swapfile/d' /etc/fstab")
        elif action == "dz_clean_all":
            res = _shell(f"systemctl stop {SERVICE_NODE}; rm -rf {RL_DIR}; docker system prune -af; swapoff -a; rm -f /swapfile")
        elif action == "dz_reboot":
            res = "Rebooting VPS…"
            _notify("💣 Reboot", "Node requested reboot.")
            _shell("reboot")
        else:
            res = "Unknown danger action."
        _notify("⚠️ Danger Executed", res)
        return await _send_long_chat(update, f"✅ Done\n```\n{res}\n```")

# ======================================================
# COMMANDS
# ======================================================
async def start_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update): return
    await update.message.reply_text("⚡ Deklan-Suite Panel", reply_markup=_main_menu())

async def status_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update): return
    panel = _panel(NODE_NAME, SERVICE_NODE, _stats(), _round())
    await update.message.reply_text(panel, parse_mode="Markdown", reply_markup=_main_menu())

async def logs_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update): return
    logs = _logs()
    await _send_long_chat(update, f"📜 *Last logs*\n```\n{logs}\n```")

async def restart_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update): return
    _shell(f"systemctl restart {SERVICE_NODE}")
    _notify("🔁 Restart", f"{SERVICE_NODE} restarted by command.")
    await update.message.reply_text("✅ Node restart executed.", reply_markup=_main_menu())

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update): return
    txt = (
        "*Deklan-Suite Help*\n"
        "• Gunakan tombol untuk aksi cepat.\n"
        "• /status — lihat dashboard\n"
        "• /logs — log service\n"
        "• /restart — restart node\n"
        "• Danger Zone memerlukan password."
    )
    await update.message.reply_text(txt, parse_mode="Markdown", reply_markup=_main_menu())

# ======================================================
# MAIN LOOP
# ======================================================
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    # Buttons
    app.add_handler(CallbackQueryHandler(handle_button))

    # Commands
    app.add_handler(CommandHandler("start", start_cmd))
    app.add_handler(CommandHandler("status", status_cmd))
    app.add_handler(CommandHandler("logs", logs_cmd))
    app.add_handler(CommandHandler("restart", restart_cmd))
    app.add_handler(CommandHandler("help", help_cmd))

    # Text (danger password / plain)
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler))

    print("✅ DEKLAN-SUITE BOT v4.0 FUSION CINEMATIC running...")
    app.run_polling()

if __name__ == "__main__":
    main()
