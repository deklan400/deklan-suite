# ⚡ DEKLAN-SUITE — RL-Swarm + Telegram Bot Fusion v6.2 (Fusion Stable)
### ✅ One-Command Install • Auto Systemd • Telegram Control • Auto-Heal • Full Integration
<p align="center">
  <img src="https://i.ibb.co/3zxGBM4/GENSYN-BANNER.png" width="90%">
</p>
<p align="center">
  RL-Swarm Node • Telegram Control • Auto-Monitor • Danger Zone • Swap Manager
</p>
<p align="center">
  <img src="https://img.shields.io/badge/Gensyn-Testnet-navy?style=for-the-badge">
  <img src="https://img.shields.io/badge/Telegram-Bot-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/Systemd-Full-orange?style=for-the-badge">
  <img src="https://img.shields.io/badge/AutoHeal-Enabled-purple?style=for-the-badge">
  <img src="https://img.shields.io/badge/Linux-Ubuntu%2022.04-red?style=for-the-badge">
</p>
---
## 🚀 ONE-COMMAND INSTALL
bash <(curl -s https://raw.githubusercontent.com/deklan400/deklan-suite/main/install.sh)
✅ Satu perintah langsung setup otomatis:
- RL-Swarm Node (CPU-only)
- Telegram Bot Panel (bot.py)
- Systemd Services (gensyn, bot, monitor.timer)
- Auto-Monitor & Auto-Heal System
- Symlink Identity Files (keys)
---
## ⚙️ FITUR UTAMA
✅ Install / Update / Reinstall / Uninstall Node  
✅ Start / Stop / Restart langsung dari Telegram  
✅ View Status, Logs, CPU, RAM, Disk, Round  
✅ Safe-Clean System (otomatis via Telegram)  
✅ Auto-Monitor & Self-Heal Timer  
✅ Multi-Admin Support  
✅ Danger Zone (Password Protected)  
✅ Full Logging ke /var/log/deklan-suite.log  
✅ Telegram Auto-Notify (notify.sh)  
✅ Restart All Stack (restart.sh)  
✅ Fail-Safe Error Handling  
---
## 🧩 STRUKTUR FOLDER
/root/deklan-suite/
│── install.sh
│── update.sh
│── reinstall.sh
│── uninstall.sh
│── restart.sh
│── notify.sh
│── autoupdate.sh
│── bot.py
│── monitor.py
│── monitor.service
│── monitor.timer
│── deklan-bot.service
│── docker-compose.yml
│── README.md
│── LICENSE
│── .gitignore
/root/deklan/
│── swarm.pem
│── userApiKey.json
└── userData.json
---
## 🔧 .ENV CONFIG
BOT_TOKEN=123456789:ABCDEF...
CHAT_ID=123456789
ALLOWED_USER_IDS=123456789,987654321
SERVICE_NAME=gensyn
NODE_NAME=deklan-suite
RL_DIR=/root/rl-swarm
KEY_DIR=/root/deklan
LOG_LINES=80
LOG_MAX_CHARS=3500
ENABLE_DANGER_ZONE=1
DANGER_PASS=dekpass123
---
## 🤖 TELEGRAM PANEL MENU
📊 Status  
🟢 Start Node  
🔴 Stop Node  
🔁 Restart  
📜 Logs  
🧩 Smart Installer  
🧹 Safe Clean  
⚠️ Danger Zone  
/start — Menu utama  
/status — Cek CPU, RAM, Disk, Round  
/logs — Lihat log terakhir  
/restart — Restart node  
/help — Bantuan  
---
## 🧩 INSTALLER MENU (Smart Panel)
Klik langsung dari Telegram:
📦 Install  
🔄 Reinstall  
♻ Update  
🧹 Uninstall  
Flow:
1️⃣ Klik tombol  
2️⃣ Bot konfirmasi  
3️⃣ Balas “YES”  
4️⃣ Script otomatis berjalan  
---
## ♻ AUTO-MONITOR & SELF-HEAL
Service: monitor.service  
Timer: monitor.timer  
Flow:
1️⃣ Cek status node tiap beberapa jam  
2️⃣ Jika down → restart otomatis  
3️⃣ Jika gagal → reinstall otomatis  
4️⃣ Jika gagal total → kirim log ke Telegram  
---
## ⚙️ SYSTEMD FILES
/etc/systemd/system/gensyn.service  
/etc/systemd/system/bot.service  
/etc/systemd/system/monitor.service  
/etc/systemd/system/monitor.timer  
Aktifkan manual bila perlu:
systemctl daemon-reload  
systemctl enable --now gensyn  
systemctl enable --now bot  
systemctl enable --now monitor.timer  
---
## 🧹 UNINSTALL MANUAL
systemctl stop gensyn bot monitor.service monitor.timer  
systemctl disable gensyn bot monitor.service monitor.timer  
rm -f /etc/systemd/system/{gensyn,bot,monitor.*}  
rm -rf /root/rl-swarm /root/deklan-suite  
systemctl daemon-reload  
Identity tetap aman di: /root/deklan/
---
## 🧠 TROUBLESHOOTING
Node tidak jalan → systemctl restart gensyn  
Bot tidak respon → systemctl restart bot  
Log kosong → journalctl -u gensyn -f  
Identity hilang → Cek /root/deklan  
Disk penuh → Gunakan tombol Safe Clean  
Docker error → docker system prune -af  
Bot mati → bash /root/deklan-suite/restart.sh  
Repo error → bash install.sh ulang  
---
## 🔔 TELEGRAM NOTIFY SYSTEM
bash /root/deklan-suite/notify.sh "🔁 Node Restarted" "RL-Swarm & Bot stack restarted successfully."
Semua notifikasi otomatis dikirim ke Telegram saat install, update, uninstall, restart, atau auto-heal.
---
## 🔐 BACKUP FILES
/root/deklan/swarm.pem  
/root/deklan/userApiKey.json  
/root/deklan/userData.json  
Jangan pernah membagikan file ini — simpan offline (air-gapped).
---
## 🧩 CHANGELOG — v6.2 (Fusion Stable)
v6.2
🚀 Integrasi penuh notify.sh untuk auto Telegram message  
🧩 Penambahan restart.sh dengan CPU/RAM stats + log trim  
🧹 Penataan log ke /var/log/deklan-suite.log  
🛡️ Perbaikan systemd quoting & error handler  
⚙️ Sinkronisasi semua script ke Fusion format  
💬 README baru dengan struktur profesional  
v6.1
Implementasi auto-monitor dan Smart Installer  
v6.0
Integrasi Telegram Bot dan RL-Swarm CPU Node  
---
## 🌐 NEXT FEATURE ROADMAP
🌍 Multi-Node Dashboard  
🧭 Web UI Panel (Status & Log)  
🧩 Auto-Bot Updater  
🛰️ Remote Deploy Manager  
⚡ Node Discovery System  
---
## ❤️ Credits
Built with ❤️ by Deklan × GPT-5  
Cinematic • Unified • Stable • Future-Ready
