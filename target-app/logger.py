import json
import logging
import os
from datetime import datetime, timezone


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "service": "backend-app",
            # Injected by OpenTelemetryLoggingInstrumentor — empty string outside a trace span
            "trace_id": getattr(record, "otelTraceID", ""),
            "span_id": getattr(record, "otelSpanID", ""),
        }
        if record.exc_info:
            log["exception"] = self.formatException(record.exc_info)
        return json.dumps(log)


def setup_logger() -> logging.Logger:
    logger = logging.getLogger("app")
    logger.setLevel(logging.INFO)

    if logger.handlers:
        return logger

    formatter = JsonFormatter()

    os.makedirs("/app/logs", exist_ok=True)
    file_handler = logging.FileHandler("/app/logs/app.log")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    # Also stream to stdout so `docker compose logs` works
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    return logger
