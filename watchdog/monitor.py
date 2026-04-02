import os, time, requests, psutil

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")
MONIKER = os.getenv("MONIKER", "Monad-Node")

def send_alert(message):
    print(f"🚨 {message}")
    if TELEGRAM_TOKEN and CHAT_ID:
        try:
            requests.post(f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage", 
                          json={"chat_id": CHAT_ID, "text": f"🔔 [{MONIKER}] {message}"})
        except: pass

def check_system():
    if psutil.cpu_percent(interval=1) > 90: send_alert("CPU %90'ın üzerinde!")
    if psutil.disk_usage('/').percent > 85: send_alert("Disk %85 dolu!")

while True:
    try:
        check_system()
        time.sleep(60)
    except:
        time.sleep(10)
