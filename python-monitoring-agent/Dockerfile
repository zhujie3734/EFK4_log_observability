FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

ENV UV_PROJECT_ENVIRONMENT=/app/.venv

COPY pyproject.toml uv.lock ./
COPY src ./src

RUN uv sync --frozen

CMD ["/app/.venv/bin/python", "-m", "monitoring_agent.agent"]
