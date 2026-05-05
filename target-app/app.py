import asyncio

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from logger import setup_logger
from otel_setup import setup_otel

app = FastAPI(title="Demo Backend App")

# setup_otel phải gọi trước setup_logger để OpenTelemetryLoggingInstrumentor
# kịp patch log record factory trước khi logger được tạo
setup_otel(app)
logger = setup_logger()


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "error": str(exc)},
    )


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/api/fast")
async def fast():
    logger.info("fast endpoint called")
    return {"message": "fast response", "status": "ok"}


@app.get("/api/slow")
async def slow():
    logger.info("slow endpoint called, sleeping 2s")
    await asyncio.sleep(2)
    logger.info("slow endpoint done")
    return {"message": "slow response after 2s", "status": "ok"}


@app.get("/api/error")
async def error():
    logger.error("error endpoint called — raising intentional exception")
    raise RuntimeError("Intentional server error for observability testing")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
