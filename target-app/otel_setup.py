import os

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def setup_otel(app) -> None:
    resource = Resource.create({"service.name": "backend-app"})
    provider = TracerProvider(resource=resource)

    # Gửi traces đến Grafana Alloy (OTLP gRPC), Alloy forward tiếp đến Tempo
    endpoint = os.getenv("OTLP_ENDPOINT", "alloy:4317")
    exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))

    trace.set_tracer_provider(provider)

    FastAPIInstrumentor.instrument_app(app)

    # Patch log record factory để mỗi log record có otelTraceID và otelSpanID
    # Cho phép Grafana tạo liên kết Log → Trace
    LoggingInstrumentor().instrument(set_logging_format=True)
