#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  printf 'Set GCP_PROJECT_ID before running this script.\n' >&2
  exit 1
fi

GCP_REGION="${GCP_REGION:-us-central1}"
CLOUD_SQL_INSTANCE="${CLOUD_SQL_INSTANCE:-ducklake-postgres}"
DUCKLAKE_PG_PORT="${DUCKLAKE_PG_PORT:-5432}"
CONNECTION_NAME="${CLOUD_SQL_CONNECTION_NAME:-${GCP_PROJECT_ID}:${GCP_REGION}:${CLOUD_SQL_INSTANCE}}"

if command -v cloud-sql-proxy >/dev/null 2>&1; then
  exec cloud-sql-proxy "${CONNECTION_NAME}" --port "${DUCKLAKE_PG_PORT}"
fi

if command -v cloud_sql_proxy >/dev/null 2>&1; then
  exec cloud_sql_proxy -instances="${CONNECTION_NAME}=tcp:${DUCKLAKE_PG_PORT}"
fi

printf 'Cloud SQL Auth Proxy was not found. Install it from https://cloud.google.com/sql/docs/postgres/connect-auth-proxy.\n' >&2
exit 1
