from fastapi import FastAPI, status
from src.schemas import AlertmanagerPayload
from src.notifier import send_telegram_notification
import os
from dotenv import load_dotenv

load_dotenv()
app = FastAPI(title="Alertmanager Telegram Adapter")

# Only accept Post method
@app.post("/alertmanager/webhook", status_code=status.HTTP_200_OK)
async def webhook_receiver(payload: AlertmanagerPayload):
    for alert in payload.alerts:
        status_symbol = "🔴" if alert.status == "firing" else "🟢"
        formatted_msg = (
            f"{status_symbol} <b>Alert: {alert.labels.get('alertname')}</b>\n"
            f"Severity: {alert.labels.get('severity')}\n"
            f"Instance: {alert.labels.get('instance')}\n"
            f"Summary: {alert.annotations.get('summary')}\n"
        )
        await send_telegram_notification(formatted_msg)
    
    return {"status": "success", "processed_at": payload.receiver}