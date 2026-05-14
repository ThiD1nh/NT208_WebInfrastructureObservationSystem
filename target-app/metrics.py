import time
from typing import Tuple

from opentelemetry import trace
from prometheus_client import REGISTRY, Counter, Gauge, Histogram
from prometheus_client.openmetrics.exposition import CONTENT_TYPE_LATEST, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response
from starlette.routing import Match
from starlette.status import HTTP_500_INTERNAL_SERVER_ERROR
from starlette.types import ASGIApp

APP_NAME = "backend-app"

REQUESTS = Counter(
    "fastapi_requests_total",
    "Total count of requests by method and path.",
    ["method", "path", "app_name"],
)
RESPONSES = Counter(
    "fastapi_responses_total",
    "Total count of responses by method, path and status code.",
    ["method", "path", "status_code", "app_name"],
)
REQUESTS_DURATION = Histogram(
    "fastapi_requests_duration_seconds",
    "Histogram of request duration by path (in seconds).",
    ["method", "path", "app_name"],
)
EXCEPTIONS = Counter(
    "fastapi_exceptions_total",
    "Total count of exceptions by path and exception type.",
    ["method", "path", "exception_type", "app_name"],
)
REQUESTS_IN_PROGRESS = Gauge(
    "fastapi_requests_in_progress",
    "Number of requests currently being processed.",
    ["method", "path", "app_name"],
)


class PrometheusMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        method = request.method
        path, is_handled = self._get_path(request)

        if not is_handled:
            return await call_next(request)

        REQUESTS.labels(method=method, path=path, app_name=APP_NAME).inc()
        REQUESTS_IN_PROGRESS.labels(method=method, path=path, app_name=APP_NAME).inc()
        start = time.perf_counter()

        try:
            response = await call_next(request)
        except BaseException as e:
            status_code = HTTP_500_INTERNAL_SERVER_ERROR
            EXCEPTIONS.labels(method=method, path=path, exception_type=type(e).__name__, app_name=APP_NAME).inc()
            raise
        else:
            status_code = response.status_code
            duration = time.perf_counter() - start
            span = trace.get_current_span()
            trace_id = trace.format_trace_id(span.get_span_context().trace_id)
            REQUESTS_DURATION.labels(method=method, path=path, app_name=APP_NAME).observe(
                duration, exemplar={"TraceID": trace_id}
            )
        finally:
            RESPONSES.labels(method=method, path=path, status_code=status_code, app_name=APP_NAME).inc()
            REQUESTS_IN_PROGRESS.labels(method=method, path=path, app_name=APP_NAME).dec()

        return response

    @staticmethod
    def _get_path(request: Request) -> Tuple[str, bool]:
        for route in request.app.routes:
            match, _ = route.matches(request.scope)
            if match == Match.FULL:
                return route.path, True
        return request.url.path, False


def metrics_endpoint(request: Request) -> Response:
    return Response(generate_latest(REGISTRY), headers={"Content-Type": CONTENT_TYPE_LATEST})
