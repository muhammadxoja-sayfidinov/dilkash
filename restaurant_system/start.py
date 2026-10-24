#!/usr/bin/env python3
"""
Restoran Tizimi - Birlashtirilgan ishga tushirish skripti (2026/2027)
Django Web Server, Toza HTTPS Tunnel (Cloudflare / ngrok) va Telegram Botni bitta buyruq bilan ishga tushiradi.
To'xtatish uchun: Ctrl + C bosing.
"""

import subprocess
import sys
import time
import os
import shutil
import urllib.request
import json
import threading
import re

def start_cloudflared_tunnel():
    """Cloudflare Tunnelni ishga tushirish (Ogohlantirish oynasisiz, toza HTTPS)"""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    cloudflared_bin = os.path.join(base_dir, "cloudflared")
    if not (os.path.isfile(cloudflared_bin) and os.access(cloudflared_bin, os.X_OK)):
        return None, None

    cmd = [cloudflared_bin, "tunnel", "--url", "http://127.0.0.1:8000"]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    url_holder = []
    def monitor_output():
        for line in iter(proc.stdout.readline, ''):
            if not line:
                break
            match = re.search(r'https://[a-zA-Z0-9.-]+\.trycloudflare\.com', line)
            if match and not url_holder:
                url_holder.append(match.group(0))

    t = threading.Thread(target=monitor_output, daemon=True)
    t.start()

    for _ in range(25):
        time.sleep(0.5)
        if url_holder:
            return proc, url_holder[0]
        if proc.poll() is not None:
            break

    return proc, (url_holder[0] if url_holder else None)

def find_ngrok():
    custom_paths = ["/opt/homebrew/bin/ngrok", "/usr/local/bin/ngrok"]
    for p in custom_paths:
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return shutil.which("ngrok")

def get_ngrok_url():
    for _ in range(12):
        time.sleep(0.5)
        try:
            req = urllib.request.urlopen("http://127.0.0.1:4040/api/tunnels", timeout=2)
            data = json.loads(req.read().decode('utf-8'))
            for t in data.get('tunnels', []):
                url = t.get('public_url', '')
                if url.startswith('https://'):
                    return url
        except Exception:
            pass
    return None

def free_port_8000():
    """8000-portda eski qolib ketgan jarayonlarni tozalash"""
    try:
        res = subprocess.run(["lsof", "-ti", ":8000"], capture_output=True, text=True)
        if res.stdout.strip():
            pids = res.stdout.strip().split()
            current_pid = str(os.getpid())
            for pid_str in pids:
                if pid_str != current_pid:
                    try:
                        os.kill(int(pid_str), 9)
                    except Exception:
                        pass
            time.sleep(0.5)
    except Exception:
        pass

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(base_dir)

    # Eski cloudflared va bot jarayonlarini tozalash
    try:
        subprocess.run(["pkill", "-f", "cloudflared tunnel"], capture_output=True)
        subprocess.run(["pkill", "-f", "telegram_bot.py"], capture_output=True)
        subprocess.run(["pkill", "-f", "waiter_bot.py"], capture_output=True)
    except Exception:
        pass

    # Port 8000 ni tozalash
    free_port_8000()

    print("=" * 65)
    print("🍽️  RESTORAN BOSHQARUV TIZIMI & TELEGRAM MINI APP (2026/2027)")
    print("=" * 65)

    # 1. Django Web Serverni ishga tushirish (0.0.0.0:8000 Wi-Fi va USB orqali ulanish uchun)
    print("🚀 1. Django veb server ishga tushirilmoqda...")
    django_cmd = [sys.executable, "manage.py", "runserver", "0.0.0.0:8000"]
    django_process = subprocess.Popen(
        django_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    # Android telefonlar uchun ADB port forwarding
    try:
        adb_path = os.path.expanduser("~/Library/Android/sdk/platform-tools/adb")
        if os.path.exists(adb_path):
            subprocess.run([adb_path, "reverse", "tcp:8000", "tcp:8000"], capture_output=True)
            print("📱 Android ADB reverse port 8000 muvaffaqiyatli yo'naltirildi")
    except Exception:
        pass

    # 2. Toza HTTPS Tunnel ochish (Avval Cloudflare, keyin ngrok)
    tunnel_process = None
    https_url = None

    print("🔒 2. Telegram Mini App uchun toza HTTPS Tunnel ochilmoqda...")
    tunnel_process, https_url = start_cloudflared_tunnel()

    if https_url:
        print(f"   ✅ Toza Cloudflare HTTPS: {https_url}/menu/")
    else:
        # Fallback to ngrok if cloudflared fails
        ngrok_bin = find_ngrok()
        if ngrok_bin:
            ngrok_cmd = [ngrok_bin, "http", "8000", "--log=stdout"]
            tunnel_process = subprocess.Popen(
                ngrok_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            https_url = get_ngrok_url()
            if https_url:
                print(f"   ✅ ngrok HTTPS: {https_url}/menu/")

    if not https_url:
        print("   ℹ️  Tunnel ochilmadi. Bot lokal rejimda ishga tushadi.")

    # 3. Telegram Botni ishga tushirish
    print("🤖 3. Asosiy Telegram Boti ishga tushirilmoqda...")
    bot_env = os.environ.copy()
    if https_url:
        bot_env["WEB_APP_URL"] = f"{https_url}/menu/"

    bot_cmd = [sys.executable, "telegram_bot.py"]
    bot_process = subprocess.Popen(
        bot_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=bot_env
    )

    print("-" * 65)
    print("🌐 Oshpaz KDS Paneli:  http://127.0.0.1:8000/chef_panel/")
    print("🍽️ Stollar QR kodlari: http://127.0.0.1:8000/chef_panel/tables/qrs/")
    if https_url:
        print(f"📱 Mehmon QR Hisobi:  {https_url}/table/1/")
    else:
        print("📱 Mehmon QR Hisobi:   http://127.0.0.1:8000/table/1/")
    print("-" * 65)
    print("Tizim to'liq ishlamoqda! To'xtatish uchun: [Ctrl + C] bosing.\n")

    def stream_output(process, prefix):
        for line in iter(process.stdout.readline, ''):
            if line:
                print(f"[{prefix}] {line.rstrip()}")

    t_django = threading.Thread(target=stream_output, args=(django_process, "WEB/DJANGO"), daemon=True)
    t_bot = threading.Thread(target=stream_output, args=(bot_process, "TELEGRAM BOT"), daemon=True)

    t_django.start()
    t_bot.start()

    try:
        while True:
            time.sleep(1)
            if django_process.poll() is not None:
                print("\n[OGOHLANTIRISH] Django server to'xtadi!")
                break
            if bot_process.poll() is not None:
                print("\n[OGOHLANTIRISH] Telegram Bot to'xtadi!")
                break
    except KeyboardInterrupt:
        print("\n\n🛑 Tizim to'xtatilmoqda...")
    finally:
        for p in [tunnel_process, bot_process, django_process]:
            if p and p.poll() is None:
                try:
                    p.terminate()
                    p.wait(timeout=3)
                except Exception:
                    p.kill()
        print("✅ Barcha jarayonlar xavfsiz to'xtatildi.")


if __name__ == '__main__':
    main()
