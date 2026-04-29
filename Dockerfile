FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    PATH="/app/.venv/bin:${PATH}" \
    DAGSTER_HOME=/app/dagster_home

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates gcc g++ \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock .python-version README.md ./
RUN uv sync --frozen --no-dev --no-install-project

COPY pipelines/ pipelines/
COPY orchestration/ orchestration/
COPY shared/ shared/
COPY transformations/ transformations/
COPY config/dlt/ config/dlt/
COPY scripts/ scripts/

RUN uv sync --frozen --no-dev --no-editable \
    && chmod +x scripts/*.sh \
    && mkdir -p /app/dagster_home \
    && cp orchestration/dagster_cloud.yaml /app/dagster_home/dagster.yaml

RUN DUCKLAKE_GCS_HMAC_KEY_ID=dummy \
    DUCKLAKE_GCS_HMAC_SECRET=dummy \
    DUCKLAKE_GCS_PATH=gs://dummy-ducklake/ducklake \
    DUCKLAKE_PG_PASSWORD=dummy \
    uv run dbt parse --project-dir transformations --profiles-dir transformations

EXPOSE 8080

CMD ["scripts/entrypoint-webserver.sh"]
