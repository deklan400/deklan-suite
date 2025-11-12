#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
  DEKLAN-SUITE MONITOR v3.6 FUSION AUTO-HEAL
  Node watchdog + auto restart + Telegram alert system
  by Deklan × GPT-5
"""

import os, time, subprocess, psutil
from datetime import datetime

# ======================================================
# LOAD ENVIRONMENT
# ======================================================
def load_env(path="/opt/deklan-node-bot/.env"):
    if not os.path.exists(path):
        return
    with open(path) as f:
        for line in f:
            if "=" in line and not line.startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v)

load_env()

# ======================================================
# CONFIG
# ======================================================
SERVICE = os.getenv("SERVICE_NAME", "gensyn")
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
CHAT_ID = os.getenv("CHAT_ID", "")
KEY_DIR = os.getenv("KEY_DIR", "/root/deklan")
REQUIRED = ["swarm.pem", "userApiKey.json", "userData.json"]
INTERVAL = int(os.getenv("MONITOR_INTERVAL", "300"))  # default 5 minutes
LOG_FILE = "/tmp/deklan-monitor.log"

# ======================================================
# UTILS
# ======================================================
def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

def sh(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True).strip()
    except subprocess.CalledProcessError as e:
        return e.output or ""

def notify(title, message):
    if not BOT_TOKEN or not CHAT_ID:
        return
    text = f"⚠️ *Deklan-Suite Monitor*\n━━━━━━━━━━━━━━\n🖥 Host: `{os.uname().nodename}`\n🕒 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n━━━━━━━━━━━━━━\n*{title}*\n```\n{message[:1800]}\n```"
    sh(f"curl -s -X POST 'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage' -d chat_id={CHAT_ID} -d parse_mode=Markdown -d text=\"{text}\" >/dev/null 2>&1 || true")

def check_identity():
    missing = []
    for f in REQUIRED:
        if not os.path.isfile(os.path.join(KEY_DIR, f)):
            missing.append(f)
    return missing

def node_active():
    status = sh(f"systemctl is-active {SERVICE}")
    return "active" in status.lower()

# ======================================================
# MAIN LOGIC
# ======================================================
def main():
    log("🚀 Starting Deklan-Suite Monitor (Auto-Heal v3.6)")
    miss = check_identity()
    if miss:
        msg = f"❌ Missing starter files: {', '.join(miss)}"
        log(msg)
        notify("Identity Missing", msg)
        return

    if not node_active():
        log(f"⚠️ {SERVICE} inactive → restarting…")
        notify("Node Down", f"{SERVICE} inactive — attempting restart.")
        sh(f"systemctl restart {SERVICE}")
        time.sleep(15)
        if node_active():
            log(f"✅ {SERVICE} successfully restarted.")
            notify("Node Restarted", f"{SERVICE} recovered successfully.")
        else:
            log(f"❌ Restart failed — reinstall triggered.")
            notify("Node Restart Failed", "Attempting reinstall…")
            reinstall = sh("bash <(curl -s https://raw.githubusercontent.com/deklan400/deklan-suite/main/install.sh)")
            notify("Reinstall Output", reinstall[:1500])
    else:
        stats = psutil.virtual_memory()
        cpu = psutil.cpu_percent(0.5)
        log(f"✅ {SERVICE} OK | CPU {cpu:.1f}% | RAM {stats.percent:.1f}%")

    log(f"⏱ Next check in {INTERVAL}s…\n")

# ======================================================
# EXECUTION
# ======================================================
if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"❌ Monitor crashed: {e}")
        notify("Monitor Error", str(e))
