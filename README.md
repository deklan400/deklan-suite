# ⚡ DEKLAN-SUITE — RL-Swarm + Telegram Bot Fusion
### ✅ One-Command Install • Auto Systemd • Telegram Control • Auto-Heal • Full Integration

<p align="center">
  <img src="https://i.ibb.co/3zxGBM4/GENSYN-BANNER.png" width="90%">
</p>

<p align="center">
  RL-Swarm Node • Telegram Control • Auto Monitor • Danger Zone • Swap Manager
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Gensyn-Testnet-navy?style=for-the-badge">
  <img src="https://img.shields.io/badge/Telegram-Bot-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/Systemd-Full-orange?style=for-the-badge">
  <img src="https://img.shields.io/badge/AutoHeal-Enabled-purple?style=for-the-badge">
  <img src="https://img.shields.io/badge/Linux-Ubuntu%2022.04-red?style=for-the-badge">
</p>

---

# 🚀 ONE-COMMAND INSTALL
```bash
bash <(curl -s https://raw.githubusercontent.com/deklan400/deklan-suite/main/install.sh)
```
> ✅ Satu perintah langsung setup:
> - RL-Swarm Node (CPU mode)
> - Telegram Bot Panel (bot.py)
> - Systemd Service (gensyn, bot, monitor)
> - Auto-Monitor & Auto-Heal
> - Symlink Keys & Identity

---

# ⚙️ FITUR UTAMA
✅ Install / Update / Reinstall / Uninstall Node  
✅ Start / Stop / Restart langsung via Telegram  
✅ View Status, Logs, CPU, RAM, Disk, Round  
✅ Safe-Clean System  
✅ Auto-Monitor (Restart → Reinstall → Notify)  
✅ Multi-Admin Support  
✅ Danger Zone (Password Protected)  
✅ Anti-Spam / Fail-Safe Mode  
✅ Semua service otomatis aktif dengan Systemd  

---

# 📂 STRUKTUR FOLDER
```
/root/deklan-suite/
│── install.sh
│── update.sh
│── uninstall.sh
│── bot.py
│── monitor.py
│── requirements.txt
│── .env.example
│── systemd/
│   ├── bot.service
│   ├── monitor.service
│   ├── monitor.timer
│   └── gensyn.service

/root/deklan/
│── swarm.pem
│── userApiKey.json
└── userData.json
```

---

# 🔧 .ENV CONFIG
```
BOT_TOKEN=123456789:ABCDEF...
CHAT_ID=123456789
ALLOWED_USER_IDS=123456789,987654321

SERVICE_NAME=gensyn
NODE_NAME=deklan-suite
RL_DIR=/root/rl-swarm
KEY_DIR=/root/deklan

LOG_LINES=80
LOG_MAX_CHARS=3500
MONITOR_EVERY_MINUTES=180
ENABLE_DANGER_ZONE=1
DANGER_PASS=dekpass123
```

---

# 🤖 TELEGRAM PANEL MENU
📊 Status  
🟢 Start Node  
🔴 Stop Node  
🔁 Restart  
📜 Logs  
🧩 Smart Installer  
🧹 Safe Clean  
⚠️ Danger Zone  

| Command | Fungsi |
|----------|--------|
| `/start` | Menu utama |
| `/status` | Cek CPU, RAM, Disk, Round |
| `/logs` | Lihat log terakhir |
| `/restart` | Restart node |
| `/help` | Bantuan |

---

# 🧩 INSTALLER MENU
Tombol dalam Telegram:  
- 📦 Install  
- 🔄 Reinstall  
- ♻ Update  
- 🧹 Uninstall  

Flow:
1️⃣ Klik tombol  
2️⃣ Bot konfirmasi  
3️⃣ Balas “YES”  
4️⃣ Script jalan otomatis  

---

# ♻ AUTO-MONITOR & SELF-HEAL
Systemd Timer: `monitor.timer`  

Flow:
1️⃣ Cek status node tiap X menit  
2️⃣ Jika node down → restart otomatis  
3️⃣ Jika gagal → reinstall otomatis  
4️⃣ Jika gagal total → kirim log via Telegram  

---

# ⚙️ SYSTEMD FILES
```
/etc/systemd/system/gensyn.service
/etc/systemd/system/bot.service
/etc/systemd/system/monitor.service
/etc/systemd/system/monitor.timer
```

Aktifkan semua:
```bash
systemctl daemon-reload
systemctl enable --now gensyn
systemctl enable --now bot
systemctl enable --now monitor.timer
```

---

# 🧹 UNINSTALL MANUAL
```bash
systemctl stop gensyn bot monitor.service monitor.timer
systemctl disable gensyn bot monitor.service monitor.timer
rm -f /etc/systemd/system/{gensyn,bot,monitor.*}
rm -rf /root/rl-swarm /root/deklan-suite
systemctl daemon-reload
```

Identity tetap aman di:
```
/root/deklan/
```

---

# 🧠 TROUBLESHOOTING
| Masalah | Solusi |
|----------|--------|
| Node tidak jalan | `systemctl restart gensyn` |
| Bot tidak respon | `systemctl restart bot` |
| Log kosong | `journalctl -u gensyn -f` |
| Identity hilang | Cek `/root/deklan` |
| Disk penuh | Gunakan tombol *Safe Clean* |
| Docker error | `docker system prune -af` |
| Repo error | Jalankan ulang `install.sh` |

---

# 🔐 BACKUP FILES
```
/root/deklan/swarm.pem
/root/deklan/userApiKey.json
/root/deklan/userData.json
```
> Jangan pernah membagikan file ini — simpan offline.

---

# 🌐 NEXT FEATURE ROADMAP
- Multi-Node Dashboard  
- Web UI Panel  
- Auto-Bot Updater  
- Remote Deploy Manager  
- Node Discovery System  

---

# ❤️ Credits
Built with ❤️ by **Deklan × GPT-5**  
_Cinematic • Unified • Stable • Future-Ready_
