import requests
import json
import logging
from django.conf import settings

logger = logging.getLogger(__name__)

def send_telegram_message(chat_id, text, reply_markup=None, message_id=None, parse_mode="Markdown"):
    """Telegram Bot API orqali xabar yuborish/tahrirlash"""
    if not settings.TELEGRAM_BOT_TOKEN or not chat_id:
        return None

    url = f"{settings.TELEGRAM_API_BASE_URL}{settings.TELEGRAM_BOT_TOKEN}/"
    payload = {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': parse_mode
    }
    if reply_markup:
        payload['reply_markup'] = reply_markup

    try:
        endpoint = "editMessageText" if message_id else "sendMessage"
        if message_id:
            payload['message_id'] = message_id

        response = requests.post(f"{url}{endpoint}", json=payload, timeout=4)
        if response.status_code == 200:
            return response.json()
        
        # Agar Markdown format xatosi bo'lsa (400), oddiy matn sifatida qayta urinish
        if response.status_code == 400 and 'parse_mode' in payload:
            payload.pop('parse_mode', None)
            res_retry = requests.post(f"{url}{endpoint}", json=payload, timeout=4)
            if res_retry.status_code == 200:
                return res_retry.json()

        logger.warning(f"Telegram API javobi ({response.status_code}): {response.text}")
        return None
    except Exception as e:
        logger.error(f"Telegram xabar yuborishda xato: {e}")
        return None

def send_telegram_location(chat_id, latitude, longitude):
    """Telegram Bot API orqali lokatsiya yuborish"""
    if not settings.TELEGRAM_BOT_TOKEN or not chat_id:
        return None

    url = f"{settings.TELEGRAM_API_BASE_URL}{settings.TELEGRAM_BOT_TOKEN}/sendLocation"
    payload = {
        'chat_id': chat_id,
        'latitude': latitude,
        'longitude': longitude
    }
    try:
        response = requests.post(url, json=payload, timeout=4)
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        logger.error(f"Telegram lokatsiya yuborishda xato: {e}")
        return None
