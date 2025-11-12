#!/usr/bin/env python3
# bot.py — Deklan-Bot v3 FULL BUTTON MODE
import os
import subprocess
import time
from datetime import timedelta
import psutil

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CallbackQueryHandler, MessageHandler, CommandHandler, ContextTypes, filters

# --------------------
# Config (via env or default)
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
CHAT_ID = str(os.getenv("CHAT_ID", ""))
ALLOWED_USER_IDS = [i.strip() for i in os.getenv("ALLOWED_USER_IDS", "").split(",") if i.strip()]
KEY_DIR = os.getenv("KEY_DIR", "/root/deklan")
BASE_DIR = os.getenv("BASE_DIR", "/root/deklan-suite")
SERVICE_NAME = os.getenv("SERVICE_NAME", "deklan-bot")
DOCKER_COMPOSE_CMD = os.getenv("DOCKER_COMPOSE_CMD", "docker compose run --rm --build -Pit swarm-cpu")
LOG_LINES = int(os.getenv("LOG_LINES", "80"))
ENABLE_DANGER = os.getenv("ENABLE_DANGER_ZONE", "0") == "1"
DANGER_PASS = os.getenv("DANGER_PASS", "")

REQUIRED_FILES = ["swarm.pem", "userapikey.json", "userData.json"]

if not BOT_TOKEN or not CHAT_ID:
    raise SystemExit("BOT_TOKEN and CHAT_ID required in env")

def _shell(cmd: str) -> str:
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        return e.output or str(e)

def _authorized(update: Update) -> bool:
    uid = str(update.effective_user.id)
    if str(update.effective_chat.id) != CHAT_ID:
        return False
    if not ALLOWED_USER_IDS:
        return uid == CHAT_ID
    return uid == CHAT_ID or uid in ALLOWED_USER_IDS

def check_starter_files() -> (bool, list):
    missing = []
    for f in REQUIRED_FILES:
        if not os.path.isfile(os.path.join(KEY_DIR, f)):
            missing.append(f)
    return (len(missing) == 0, missing)

def system_stats() -> str:
    try:
        cpu = psutil.cpu_percent(interval=0.4)
        vm = psutil.virtual_memory()
        du = psutil.disk_usage("/")
        up = str(timedelta(seconds=int(time.time() - psutil.boot_time())))
        return f"CPU: {cpu:.1f}%\nRAM: {vm.percent:.1f}% ({vm.used//(1024**3)}G/{vm.total//(1024**3)}G)\nDisk: {du.percent:.1f}%\nUptime: {up}"
    except Exception as e:
        return f"(stats error: {e})"

# --------------------
# Keyboards
def main_menu():
    ok, missing = check_starter_files()
    installer_btn = InlineKeyboardButton("🧩 Smart Installer", callback_data="installer")
    status_btn = InlineKeyboardButton("📊 Status", callback_data="status")
    start_btn = InlineKeyboardButton("🟢 Start", callback_data="start")
    stop_btn = InlineKeyboardButton("🔴 Stop", callback_data="stop")
    restart_btn = InlineKeyboardButton("🔁 Restart", callback_data="restart")
    logs_btn = InlineKeyboardButton("📜 Logs", callback_data="logs")
    round_btn = InlineKeyboardButton("ℹ️ Round", callback_data="round")
    safeclean_btn = InlineKeyboardButton("🧹 Safe Clean", callback_data="safe_clean")
    swap_btn = InlineKeyboardButton("💾 Swap Manager", callback_data="swap")
    danger_btn = InlineKeyboardButton("⚠️ Danger Zone", callback_data="dz") if ENABLE_DANGER else None

    rows = [
        [status_btn],
        [start_btn, stop_btn],
        [restart_btn],
        [logs_btn, round_btn],
        [safeclean_btn],
        [swap_btn],
        [installer_btn]
    ]
    if danger_btn:
        rows.append([danger_btn])

    # If starter missing show helper
    if not ok:
        rows.insert(0, [InlineKeyboardButton("⚠️ Starter Missing", callback_data="starter_missing")])

    return InlineKeyboardMarkup(rows)

def installer_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📦 Install Node", callback_data="inst_install")],
        [InlineKeyboardButton("🔄 Reinstall Node", callback_data="inst_reinstall")],
        [InlineKeyboardButton("♻ Update Node", callback_data="inst_update")],
        [InlineKeyboardButton("🧹 Uninstall Node", callback_data="inst_uninstall")],
        [InlineKeyboardButton("🟢 Auto-Run Swarm", callback_data="inst_autorun")],
        [InlineKeyboardButton("⬅ Back", callback_data="back")]
    ])

def swap_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("16G", callback_data="swap_16")],
        [InlineKeyboardButton("32G", callback_data="swap_32")],
        [InlineKeyboardButton("64G", callback_data="swap_64")],
        [InlineKeyboardButton("Custom", callback_data="swap_custom")],
        [InlineKeyboardButton("⬅ Back", callback_data="back")]
    ])

def danger_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🔥 Remove RL-Swarm", callback_data="dz_rm_node")],
        [InlineKeyboardButton("🐋 Clean Docker", callback_data="dz_rm_docker")],
        [InlineKeyboardButton("💾 Remove Swap", callback_data="dz_rm_swap")],
        [InlineKeyboardButton("🧹 Full Clean", callback_data="dz_clean_all")],
        [InlineKeyboardButton("🔁 Reboot VPS", callback_data="dz_reboot")],
        [InlineKeyboardButton("⬅ Back", callback_data="back")]
    ])

# --------------------
# Handlers
async def start_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not _authorized(update): return await update.message.reply_text("❌ Unauthorized.")
    await update.message.reply_text("⚡ Deklan Suite — Main Menu", reply_markup=main_menu())

async def handle_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    if not _authorized(update):
        return await q.edit_message_text("❌ Unauthorized.")
    action = q.data

    if action == "starter_missing":
        ok, missing = check_starter_files()
        txt = "Starter files missing:\n" + "\n".join(f"- {m}" for m in missing) + "\n\nUpload to /root/deklan and press 🔁 Check Again."
        return await q.edit_message_text(txt, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔁 Check Again", callback_data="check_again"), InlineKeyboardButton("⬅ Back", callback_data="back")]]))

    if action == "check_again":
        return await q.edit_message_text("Checking...", reply_markup=main_menu())

    if action == "status":
        txt = system_stats()
        return await q.edit_message_text(f"📊 System Status\n```\n{txt}\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "start":
        res = _shell(f"systemctl start {SERVICE_NAME} || true")
        return await q.edit_message_text("🟢 Start requested.\n```\n" + res[-1500:] + "\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "stop":
        res = _shell(f"systemctl stop {SERVICE_NAME} || true")
        return await q.edit_message_text("🔴 Stop requested.\n```\n" + res[-1500:] + "\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "restart":
        res = _shell(f"systemctl restart {SERVICE_NAME} || true")
        return await q.edit_message_text("🔁 Restart requested.\n```\n" + res[-1500:] + "\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "logs":
        res = _shell(f"journalctl -u {SERVICE_NAME} -n {LOG_LINES} --no-pager || true")
        return await q.edit_message_text(f"📜 Last {LOG_LINES} lines\n```\n{res[-3500:]}\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "round":
        res = _shell(f"journalctl -u {SERVICE_NAME} --no-pager | grep -E 'Joining round:' | tail -n1 || true")
        return await q.edit_message_text(f"ℹ️ Round\n```\n{res}\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "safe_clean":
        cmds = [
            "docker image prune -f",
            "docker container prune -f",
            "apt autoremove -y",
            "apt clean",
            "journalctl --vacuum-size=200M",
            "rm -rf /tmp/*"
        ]
        out = ""
        for c in cmds:
            out += f"$ {c}\n" + _shell(c) + "\n"
        return await q.edit_message_text(f"✅ Safe clean done\n```\n{out[-3500:]}\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "swap":
        return await q.edit_message_text("💾 Swap Manager", reply_markup=swap_menu())

    if action.startswith("swap_"):
        size = action.split("_",1)[1]
        if size == "custom":
            context.user_data["awaiting_swap_custom"] = True
            return await q.edit_message_text("Enter custom swap size in GB (e.g. 48):")
        try:
            size_int = int(size)
            out = set_swap(size_int)
        except Exception as e:
            out = f"Swap error: {e}"
        return await q.edit_message_text(f"```\n{out}\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "installer":
        return await q.edit_message_text("🧩 Installer", reply_markup=installer_menu())

    if action.startswith("inst_"):
        mode = action.split("_",1)[1]
        if mode == "autorun":
            ok, missing = check_starter_files()
            if not ok:
                return await q.edit_message_text("❌ Starter files missing. Upload them to /root/deklan and try again.", reply_markup=main_menu())
            # run docker compose command
            out = _shell(DOCKER_COMPOSE_CMD)
            return await q.edit_message_text(f"🚀 Auto-Run Swarm\n```\n{out[-3500:]}\n```", parse_mode="Markdown", reply_markup=main_menu())
        else:
            # remote installer actions: install.sh, reinstall.sh, update.sh, uninstall.sh
            mapping = {
                "install": "install.sh",
                "reinstall": "reinstall.sh",
                "update": "update.sh",
                "uninstall": "uninstall.sh"
            }
            fname = mapping.get(mode, "install.sh")
            # download and run
            url = os.getenv("AUTO_INSTALLER_GITHUB", "https://raw.githubusercontent.com/deklan400/deklan-autoinstall/main/") + fname
            tmp = f"/tmp/{fname}"
            try:
                subprocess.check_output(f"curl -s -o {tmp} {url}", shell=True)
                subprocess.check_output(f"chmod +x {tmp}", shell=True)
                out = subprocess.check_output(f"bash {tmp}", shell=True, stderr=subprocess.STDOUT, text=True)
            except subprocess.CalledProcessError as e:
                out = e.output or str(e)
            return await q.edit_message_text(f"📦 Installer result\n```\n{out[-3500:]}\n```", parse_mode="Markdown", reply_markup=main_menu())

    if action == "back":
        return await q.edit_message_text("Main Menu", reply_markup=main_menu())

    if action == "dz":
        return await q.edit_message_text("Danger Zone", reply_markup=danger_menu())

    if action.startswith("dz_"):
        context.user_data["awaiting_danger_pass"] = action
        return await q.edit_message_text("Enter danger password:")

    if action == "inst_autorun":
        # same as autorun
        ok, missing = check_starter_files()
        if not ok:
            return await q.edit_message_text("Starter missing: " + ", ".join(missing))
        out = _shell(DOCKER_COMPOSE_CMD)
        return await q.edit_message_text(f"Auto-Run:\n```\n{out[-3500:]}\n```", parse_mode="Markdown", reply_markup=main_menu())

    return await q.edit_message_text(f"Unknown action: {action}", reply_markup=main_menu())


async def text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    txt = update.message.text.strip()
    # custom swap
    if context.user_data.pop("awaiting_swap_custom", None):
        try:
            gbs = int(txt)
            out = set_swap(gbs)
        except:
            out = "Invalid number"
        return await update.message.reply_text(f"```\n{out}\n```", parse_mode="Markdown")
    if context.user_data.get("awaiting_danger_pass"):
        action = context.user_data.pop("awaiting_danger_pass")
        if txt != DANGER_PASS:
            return await update.message.reply_text("❌ Wrong password")
        act = action.replace("dz_","")
        if act == "rm_node":
            _shell("systemctl stop gensyn || true; rm -rf /root/rl-swarm || true")
            return await update.message.reply_text("Node removed")
        if act == "rm_docker":
            out = _shell("docker ps -aq | xargs -r docker rm -f; docker system prune -af")
            return await update.message.reply_text(f"```\n{out}\n```", parse_mode="Markdown")
        if act == "rm_swap":
            out = _shell("swapoff -a; rm -f /swapfile; sed -i '/swapfile/d' /etc/fstab")
            return await update.message.reply_text("Swap removed")
        if act == "clean_all":
            out = _shell("systemctl stop gensyn || true; rm -rf /root/rl-swarm || true; docker system prune -af; swapoff -a; rm -f /swapfile")
            return await update.message.reply_text("Full clean done")
        if act == "reboot":
            _shell("reboot")
            return await update.message.reply_text("Rebooting...")

    return

# --------------------
# Helpers: swap
def set_swap(size_gb: int) -> str:
    try:
        size_mb = size_gb * 1024
        cmds = [
            "swapoff -a",
            "sed -i '/swapfile/d' /etc/fstab || true",
            "rm -f /swapfile || true",
            f"fallocate -l {size_gb}G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count={size_mb}",
            "chmod 600 /swapfile",
            "mkswap /swapfile",
            "swapon /swapfile",
            "echo '/swapfile none swap sw 0 0' >> /etc/fstab"
        ]
        out = ""
        for c in cmds:
            out += f"$ {c}\n"
            out += _shell(c) + "\n"
        return out
    except Exception as e:
        return f"Swap error: {e}"

# --------------------
# Main
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start_cmd))
    app.add_handler(CallbackQueryHandler(handle_button))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, text_message))
    print("Bot running...")
    app.run_polling()

if __name__ == "__main__":
    main()
