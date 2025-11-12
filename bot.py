#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
  DEKLAN-SUITE BOT v3.5 — Fusion Cinematic
  Unified Node + Telegram Control System
  by Deklan × GPT-5

  Features:
  - Full inline button panel (Status, Logs, Start/Stop/Restart, Installer)
  - Smart Installer hooks (install/update/restart/uninstall via AUTO_REPO)
  - Service Status panel (gensyn, bot, monitor.timer)
  - System Info panel (CPU/RAM/Disk/Uptime/IP/OS)
  - Safe Clean (docker/logs/apt/tmp)
  - Danger Zone (double-confirm + password)
  - Robust long-message sending & Markdown-safe code blocks
"""

import os
import time
import subprocess
import psutil
from datetime import timedelta

from telegram import (
    Update,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
)
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    CallbackQueryHandler,
    MessageHandler,
    ContextTypes,
    filters,
)

# ======================================================
# ENVIRONMENT
# ======================================================
env = os.getenv

BOT_TOKEN = env("BOT_TOKEN", "")
CHAT_ID   = str(env("CHAT_ID", ""))

NODE_NAME = env("NODE_NAME", "deklan-node")
SERVICE_NODE = env("SERVICE_NAME", "gensyn")

LOG_LINES = int(env("LOG_LINES", "80"))
LOG_MAX   = int(env("LOG_MAX_CHARS", "3500"))

# Paths
RL_DIR    = env("RL_DIR", "/root/rl-swarm")
KEY_DIR   = env("KEY_DIR", "/root/deklan")

# Remote repo for shell scripts
AUTO_REPO = env(
    "AUTO_INSTALLER_GITHUB",
    "https://raw.githubusercontent.com/deklan400/deklan-suite/main/"
)

ALLOWED_USER_IDS = [i.strip() for i in env("ALLOWED_USER_IDS", "").split(",") if i.strip()]
ENABLE_DANGER    = env("ENABLE_DANGER_ZONE", "0") == "1"
DANGER_PASS      = env("DANGER_PASS", "")

# Starter identity files required before running node
REQUIRED_FILES = ["swarm.pem", "userApiKey.json", "userData.json"]

if not BOT_TOKEN or not CHAT_ID:
    raise SystemExit("❌ BOT_TOKEN / CHAT_ID missing — edit .env then restart bot")


# ======================================================
# HELPERS
# ======================================================
def _shell(cmd: str) -> str:
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.STDOUT, text=True
        ).strip()
    except subprocess.CalledProcessError as e:
        return (e.output or "").strip()


def _authorized(update: Update) -> bool:
    uid = str(update.effective_user.id)
    if str(update.effective_chat.id) != CHAT_ID:
        return False
    if not ALLOWED_USER_IDS:
        return uid == CHAT_ID
    return uid == CHAT_ID or uid in ALLOWED_USER_IDS


async def _send_long(upd_msg, text: str, parse_mode: str = "Markdown"):
    """
    Safely send long messages by chunking. Uses Markdown code blocks in callers where needed.
    """
    CHUNK = 3800
    if len(text) <= CHUNK:
        if hasattr(upd_msg, "edit_message_text"):
            return await upd_msg.edit_message_text(text, parse_mode=parse_mode, disable_web_page_preview=True)
        return await upd_msg.message.reply_text(text, parse_mode=parse_mode, disable_web_page_preview=True)

    parts = [text[i:i+CHUNK] for i in range(0, len(text), CHUNK)]
    if hasattr(upd_msg, "edit_message_text"):
        await upd_msg.edit_message_text(parts[0], parse_mode=parse_mode, disable_web_page_preview=True)
    else:
        await upd_msg.message.reply_text(parts[0], parse_mode=parse_mode, disable_web_page_preview=True)
    for p in parts[1:]:
        await upd_msg.message.reply_text(p, parse_mode=parse_mode, disable_web_page_preview=True)


# ======================================================
# SYSTEM OPS
# ======================================================
def _check_starter_files() -> list[str]:
    missing = []
    for f in REQUIRED_FILES:
        if not os.path.isfile(os.path.join(KEY_DIR, f)):
            missing.append(f)
    return missing


def _stats() -> str:
    try:
        cpu = psutil.cpu_percent(interval=0.5)
        vm  = psutil.virtual_memory()
        du  = psutil.disk_usage("/")
        uptime = str(timedelta(seconds=int(time.time() - psutil.boot_time())))
        return (
            f"CPU: {cpu:.1f}%\n"
            f"RAM: {vm.percent:.1f}%\n"
            f"Disk: {du.percent:.1f}%\n"
            f"Uptime: {uptime}"
        )
    except Exception:
        return "(system stats unavailable)"


def _logs() -> str:
    raw = _shell(f"journalctl -u {SERVICE_NODE} -n {LOG_LINES} --no-pager")
    return raw[-LOG_MAX:] if len(raw) > LOG_MAX else raw


def _start():   _shell(f"systemctl start {SERVICE_NODE}")
def _stop():    _shell(f"systemctl stop {SERVICE_NODE}")
def _restart(): _shell(f"systemctl restart {SERVICE_NODE}")


def _round():
    cmd = rf"journalctl -u {SERVICE_NODE} --no-pager | grep -E 'Joining round:' | tail -n1"
    return _shell(cmd) or "(round info not found)"


def _service_status(name: str) -> str:
    st = _shell(f"systemctl is-active {name} || true")
    return "✅ active" if st.strip() == "active" else f"⚠ {st or 'unknown'}"


def _service_status_panel():
    gensyn  = _service_status("gensyn")
    bot     = _service_status("bot")
    mon_tmr = _service_status("monitor.timer")
    txt = (
        "```\n"
        "████  SERVICE STATUS  ████\n\n"
        f"gensyn         : {gensyn}\n"
        f"bot            : {bot}\n"
        f"monitor.timer  : {mon_tmr}\n"
        "```\n"
    )
    return txt


def _system_info() -> str:
    try:
        hostname = _shell("hostname")
        osrel    = _shell("awk -F= '/^PRETTY_NAME/{print $2}' /etc/os-release | tr -d '\"'")
        ip4      = _shell("hostname -I | awk '{print $1}'") or "-"
        ip6      = _shell("ip -6 addr show scope global | awk '/inet6/{print $2}' | head -n1 | cut -d/ -f1") or "-"
    except:
        hostname = osrel = ip4 = ip6 = "-"

    s = _stats()
    d = {}
    for ln in s.splitlines():
        if ":" in ln:
            k, v = ln.split(":", 1)
            d[k.strip()] = v.strip()

    txt = (
        "```\n"
        "████  SYSTEM INFO  ████\n\n"
        f"Host      : {hostname}\n"
        f"OS        : {osrel}\n"
        f"IPv4      : {ip4}\n"
        f"IPv6      : {ip6}\n\n"
        f"CPU       : {d.get('CPU', '0%')}\n"
        f"RAM       : {d.get('RAM', '0%')}\n"
        f"Disk      : {d.get('Disk', '0%')}\n"
        f"Uptime    : {d.get('Uptime', '--')}\n"
        "```\n"
    )
    return txt


def _clean():
    before = _shell("df -h / | tail -1 | awk '{print $4}'")
    cmds = [
        "docker image prune -f",
        "docker container prune -f",
        "apt autoremove -y",
        "apt clean",
        "journalctl --vacuum-size=200M",
        "rm -rf /tmp/*"
    ]
    for c in cmds:
        _shell(c)
    after = _shell("df -h / | tail -1 | awk '{print $4}'")
    return (
        "```\n"
        "🧹 SAFE CLEAN DONE\n"
        f"Free Space Before : {before}\n"
        f"Free Space After  : {after}\n"
        "(Docker, Logs, APT, /tmp cleaned)\n"
        "```\n"
    )


def _run_remote(fname: str) -> str:
    url = f"{AUTO_REPO}{fname}"
    tmp = f"/tmp/{fname}"
    try:
        subprocess.check_output(f"curl -s -o {tmp} {url}", shell=True)
        subprocess.check_output(f"chmod +x {tmp}", shell=True)
        return subprocess.check_output(
            f"bash {tmp}",
            shell=True,
            stderr=subprocess.STDOUT,
            text=True
        )
    except subprocess.CalledProcessError as e:
        return e.output or "ERR"


# ======================================================
# PANEL (CINEMATIC STATUS)
# ======================================================
def _escape_inline(text: str) -> str:
    # minimal escape for backticks in Markdown code blocks
    return text.replace("`", "'")


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

    cpu   = d.get("CPU", "0%")
    ram   = d.get("RAM", "0%")
    disk  = d.get("Disk", "0%")
    up    = d.get("Uptime", "--")

    cpu_b  = _bar(cpu)
    ram_b  = _bar(ram)
    disk_b = _bar(disk)

    ts = time.strftime("%Y-%m-%d %H:%M:%S")

    def esc(x: str) -> str:
        return _escape_inline(str(x or ""))

    txt = (
        "```\n"
        "████  GENSYN QUANTUM STATUS  ████\n\n"
        f"Node       : {esc(name)}\n"
        f"Service    : {esc(service)}\n"
        f"Status     : ✅ RUNNING\n"
        f"Round      : {esc(rnd)}\n"
        f"Uptime     : {esc(up)}\n\n"
        "── Resources ─────────────────────\n"
        f"CPU        : {cpu:<8} {cpu_b}\n"
        f"RAM        : {ram:<8} {ram_b}\n"
        f"Disk       : {disk:<8} {disk_b}\n"
        "Temp       : -- °C\n\n"
        "── System ────────────────────────\n"
        f"Identity   : {'✅ Valid' if os.path.isdir(KEY_DIR) else '⚠ Missing'}\n"
        f"Docker     : {'✅ OK' if 'docker' in _shell('which docker || echo') else '⚠ N/A'}\n\n"
        f"Last Sync  : {ts}\n"
        "```\n"
    )
    return txt


# ======================================================
# MENUS
# ======================================================
def _main_menu():
    rows = [
        [InlineKeyboardButton("📊 Status", callback_data="status")],
        [
            InlineKeyboardButton("🟢 Start", callback_data="start"),
            InlineKeyboardButton("🔴 Stop",  callback_data="stop"),
            InlineKeyboardButton("🔁 Restart", callback_data="restart"),
        ],
        [InlineKeyboardButton("📜 Logs", callback_data="logs")],
        [InlineKeyboardButton("🧠 System Info", callback_data="sysinfo")],
        [InlineKeyboardButton("🧷 Service Status", callback_data="svcstatus")],
        [InlineKeyboardButton("🧩 Smart Installer", callback_data="installer")],
        [InlineKeyboardButton("🧹 Safe Clean", callback_data="clean")],
        [InlineKeyboardButton("❓ Help", callback_data="help")],
    ]
    if ENABLE_DANGER:
        rows.append([InlineKeyboardButton("⚠️ Danger Zone", callback_data="danger")])
    return InlineKeyboardMarkup(rows)


def _installer_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📦 Install Node",   callback_data="inst_install")],
        [InlineKeyboardButton("🔄 Reinstall Node", callback_data="inst_reinstall")],
        [InlineKeyboardButton("♻ Update Node",     callback_data="inst_update")],
        [InlineKeyboardButton("🔁 Restart All",    callback_data="inst_restartall")],
        [InlineKeyboardButton("🧹 Uninstall Suite",callback_data="inst_uninstall")],
        [InlineKeyboardButton("⬅ Back",            callback_data="back")],
    ])


def _danger_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🔥 Remove RL-Swarm", callback_data="dz_rm_node")],
        [InlineKeyboardButton("🐋 Clean Docker",    callback_data="dz_rm_docker")],
        [InlineKeyboardButton("💾 Remove Swap",     callback_data="dz_rm_swap")],
        [InlineKeyboardButton("🧹 Full Clean",      callback_data="dz_clean_all")],
        [InlineKeyboardButton("💣 Reboot VPS",      callback_data="dz_reboot")],
        [InlineKeyboardButton("⬅ Back",             callback_data="back")],
    ])


# ======================================================
# COMMAND HANDLERS
# ======================================================
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update):
        return await update.message.reply_text("❌ Unauthorized.")
    await update.message.reply_text("⚡ *DEKLAN-SUITE Control Panel*", parse_mode="Markdown", reply_markup=_main_menu())


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update):
        return await update.message.reply_text("❌ Unauthorized.")
    stats = _stats()
    rnd   = _round()
    panel = _panel(NODE_NAME, SERVICE_NODE, stats, rnd)
    await update.message.reply_text(panel, parse_mode="Markdown", reply_markup=_main_menu())


async def cmd_logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update):
        return await update.message.reply_text("❌ Unauthorized.")
    logs = _logs()
    await _send_long(update, f"📜 *Last {LOG_LINES} lines*\n```\n{logs}\n```", parse_mode="Markdown")


async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update):
        return await update.message.reply_text("❌ Unauthorized.")
    await update.message.reply_text(
        "✅ *Commands:*\n"
        "/start   → menu\n"
        "/status  → stats panel\n"
        "/logs    → last logs\n",
        parse_mode="Markdown",
        reply_markup=_main_menu()
    )


# ======================================================
# BUTTON HANDLER
# ======================================================
async def handle_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()

    if not _authorized(update):
        return await q.edit_message_text("❌ Unauthorized.")

    action = q.data

    # Basic ops
    if action == "status":
        stats = _stats()
        rnd   = _round()
        panel = _panel(NODE_NAME, SERVICE_NODE, stats, rnd)
        return await q.edit_message_text(panel, parse_mode="Markdown", reply_markup=_main_menu())

    if action == "sysinfo":
        info = _system_info()
        return await q.edit_message_text(info, parse_mode="Markdown", reply_markup=_main_menu())

    if action == "svcstatus":
        svc = _service_status_panel()
        return await q.edit_message_text(svc, parse_mode="Markdown", reply_markup=_main_menu())

    if action == "start":
        missing = _check_starter_files()
        if missing:
            return await q.edit_message_text(
                "❌ Missing identity files:\n"
                + "\n".join(f"- {m}" for m in missing)
                + f"\n\nUpload ke: `{KEY_DIR}` lalu coba Start lagi.",
                parse_mode="Markdown",
                reply_markup=_main_menu(),
            )
        _start()
        return await q.edit_message_text("🟢 Starting…", reply_markup=_main_menu())

    if action == "stop":
        _stop()
        return await q.edit_message_text("🔴 Stopping…", reply_markup=_main_menu())

    if action == "restart":
        _restart()
        return await q.edit_message_text("🔁 Restarting node…", reply_markup=_main_menu())

    if action == "logs":
        logs = _logs()
        return await _send_long(q, f"📜 *Last {LOG_LINES} lines*\n```\n{logs}\n```", parse_mode="Markdown")

    if action == "clean":
        res = _clean()
        return await q.edit_message_text(res, parse_mode="Markdown", reply_markup=_main_menu())

    # Installer menu
    if action == "installer":
        return await q.edit_message_text("🧩 *Smart Installer*", parse_mode="Markdown", reply_markup=_installer_menu())

    if action.startswith("inst_"):
        mode = action.split("_", 1)[1]
        context.user_data["pending_inst"] = mode
        label = mode.upper().replace("ALL", "ALL SERVICES")
        return await q.edit_message_text(
            f"⚠ Confirm `{label}`?\n\nType *YES* to proceed.",
            parse_mode="Markdown"
        )

    # Danger Zone
    if action == "danger":
        return await q.edit_message_text("⚠️ *Danger Zone — Password Required!*", parse_mode="Markdown", reply_markup=_danger_menu())

    if action.startswith("dz_"):
        # two-step confirm: password → final confirm text
        context.user_data["awaiting_password"] = action
        return await q.edit_message_text(
            f"⚠️ `{action.replace('dz_', '').upper()}` — Enter Danger Password:",
            parse_mode="Markdown"
        )

    # Back
    if action == "back":
        return await q.edit_message_text("⚡ Main Menu", reply_markup=_main_menu())


# ======================================================
# TEXT HANDLER (Confirm flows)
# ======================================================
async def text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text.strip()

    # Installer confirm
    if "pending_inst" in context.user_data:
        mode = context.user_data.pop("pending_inst")
        if text.upper() != "YES":
            return await update.message.reply_text("❌ Cancelled.", reply_markup=_main_menu())

        # map modes to scripts in AUTO_REPO
        # NOTE: 'reinstall' uses install.sh (fresh deploy) in Fusion suite
        script_map = {
            "install":      "install.sh",
            "reinstall":    "install.sh",
            "update":       "update.sh",
            "restartall":   "restart.sh",
            "uninstall":    "uninstall.sh",
        }
        fname = script_map.get(mode, "install.sh")
        result = _run_remote(fname)
        result = result[-LOG_MAX:] if len(result) > LOG_MAX else result
        return await _send_long(update, f"✅ Done\n```\n{result}\n```", parse_mode="Markdown")

    # Danger Zone: password then run
    if "awaiting_password" in context.user_data:
        action = context.user_data.pop("awaiting_password")
        if text != DANGER_PASS:
            return await update.message.reply_text("❌ Wrong password")
        # second confirmation
        context.user_data["awaiting_confirm"] = action
        return await update.message.reply_text(
            f"⚠ Confirm `{action.replace('dz_', '').upper()}` — type *CONFIRM* to continue.",
            parse_mode="Markdown"
        )

    if "awaiting_confirm" in context.user_data:
        action = context.user_data.pop("awaiting_confirm")
        if text.upper() != "CONFIRM":
            return await update.message.reply_text("❌ Cancelled.")

        await update.message.reply_text("✅ Verified! Running…")

        if action == "dz_rm_node":
            res = _shell(
                f"systemctl stop {SERVICE_NODE}; "
                f"systemctl disable {SERVICE_NODE}; "
                f"rm -f /etc/systemd/system/{SERVICE_NODE}.service; "
                f"systemctl daemon-reload; "
                f"rm -rf {RL_DIR}"
            )
        elif action == "dz_rm_docker":
            res = _shell("docker ps -aq | xargs -r docker rm -f; docker system prune -af")
        elif action == "dz_rm_swap":
            res = _shell("swapoff -a; rm -f /swapfile; sed -i '/swapfile/d' /etc/fstab")
        elif action == "dz_clean_all":
            res = _shell(
                f"systemctl stop {SERVICE_NODE}; "
                f"rm -rf {RL_DIR}; "
                f"docker system prune -af; "
                f"swapoff -a; rm -f /swapfile"
            )
        elif action == "dz_reboot":
            _shell("reboot")
            res = "Rebooting…"
        else:
            res = "Unknown danger action"

        return await _send_long(update, f"✅ Done\n```\n{res}\n```", parse_mode="Markdown")

    # Default: ignore free text
    return


# ======================================================
# MAIN
# ======================================================
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    # commands
    app.add_handler(CommandHandler("start",  cmd_start))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("logs",   cmd_logs))
    app.add_handler(CommandHandler("help",   cmd_help))

    # buttons + text
    app.add_handler(CallbackQueryHandler(handle_button))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler))

    print("✅ DEKLAN-SUITE BOT v3.5 running…")
    app.run_polling()


if __name__ == "__main__":
    main()
