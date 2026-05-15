import httpx
import os
import logging

logger = logging.getLogger(__name__)

async def send_telegram_notification(content: str):
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    chat_id = os.getenv("TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        logger.error("Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID; cannot send Telegram notification")
        return None
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    
    payload = {
        "chat_id": chat_id,
        "text": content,
        "parse_mode": "HTML"
    }
    
    timeout = httpx.Timeout(10.0, connect=5.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        try:
            response = await client.post(url, json=payload)
            response.raise_for_status()
            return response.json()
        except httpx.RequestError as e:
            logger.error(f"Telegram API request failed: {e}")
            return None
        except httpx.HTTPStatusError as e:
            logger.error(f"Telegram API Integration Failure: {e.response.text}")
            return None
