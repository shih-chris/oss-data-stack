#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/log/dagster

exec dagster-webserver \
  -h 0.0.0.0 \
  -p "${PORT:-8080}" \
  -m orchestration.definitions \
  --log-format json \
  > >(tee -a /var/log/dagster/webserver.log) \
  2>&1
