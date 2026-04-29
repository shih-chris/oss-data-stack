#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
  set +a
elif [[ -f "${PROJECT_ROOT}/config/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/config/.env"
  set +a
else
  printf 'Missing .env. Run WRITE_ENV_FILE=1 scripts/setup_gcp.sh first.\n' >&2
  exit 1
fi

DUCKLAKE_CATALOG_NAME="${DUCKLAKE_CATALOG_NAME:-ducklake}"
DUCKLAKE_METADATA_SCHEMA="${DUCKLAKE_METADATA_SCHEMA:-${DUCKLAKE_CATALOG_NAME}}"
DUCKLAKE_GCS_PREFIX="${DUCKLAKE_GCS_PREFIX:-ducklake}"
DUCKLAKE_PG_HOST="${DUCKLAKE_PG_HOST:-127.0.0.1}"
DUCKLAKE_PG_PORT="${DUCKLAKE_PG_PORT:-5432}"
DUCKLAKE_PG_DATABASE="${DUCKLAKE_PG_DATABASE:-ducklake_catalog}"
DUCKLAKE_PG_USER="${DUCKLAKE_PG_USER:-postgres}"
DUCKLAKE_SECRET_NAME="${DUCKLAKE_SECRET_NAME:-ducklake_secret}"
DUCKLAKE_POSTGRES_SECRET_NAME="${DUCKLAKE_POSTGRES_SECRET_NAME:-ducklake_postgres}"
DUCKLAKE_GCS_SECRET_NAME="${DUCKLAKE_GCS_SECRET_NAME:-ducklake_gcs}"

if [[ -z "${DUCKLAKE_GCS_PATH:-}" && -n "${DUCKLAKE_GCS_BUCKET:-}" ]]; then
  gcs_prefix="${DUCKLAKE_GCS_PREFIX#/}"
  gcs_prefix="${gcs_prefix%/}"
  if [[ -n "${gcs_prefix}" ]]; then
    DUCKLAKE_GCS_PATH="gs://${DUCKLAKE_GCS_BUCKET}/${gcs_prefix}"
  else
    DUCKLAKE_GCS_PATH="gs://${DUCKLAKE_GCS_BUCKET}"
  fi
fi

require_value() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required environment value: %s\n' "${name}" >&2
    exit 1
  fi
}

require_identifier() {
  local name="$1"
  local value="${!name:-}"
  if [[ ! "${value}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    printf 'Invalid DuckDB identifier in %s: %s\n' "${name}" "${value}" >&2
    exit 1
  fi
}

sql_literal() {
  local escaped
  escaped="$(printf '%s' "$1" | sed "s/'/''/g")"
  printf "'%s'" "${escaped}"
}

for name in \
  DUCKLAKE_CATALOG_NAME \
  DUCKLAKE_METADATA_SCHEMA \
  DUCKLAKE_GCS_PATH \
  DUCKLAKE_GCS_HMAC_KEY_ID \
  DUCKLAKE_GCS_HMAC_SECRET \
  DUCKLAKE_PG_HOST \
  DUCKLAKE_PG_PORT \
  DUCKLAKE_PG_DATABASE \
  DUCKLAKE_PG_USER \
  DUCKLAKE_PG_PASSWORD \
  DUCKLAKE_SECRET_NAME \
  DUCKLAKE_POSTGRES_SECRET_NAME \
  DUCKLAKE_GCS_SECRET_NAME; do
  require_value "${name}"
done

for name in \
  DUCKLAKE_CATALOG_NAME \
  DUCKLAKE_METADATA_SCHEMA \
  DUCKLAKE_SECRET_NAME \
  DUCKLAKE_POSTGRES_SECRET_NAME \
  DUCKLAKE_GCS_SECRET_NAME; do
  require_identifier "${name}"
done

if [[ ! "${DUCKLAKE_PG_PORT}" =~ ^[0-9]+$ ]]; then
  printf 'DUCKLAKE_PG_PORT must be numeric: %s\n' "${DUCKLAKE_PG_PORT}" >&2
  exit 1
fi

INIT_SQL="$(mktemp "${TMPDIR:-/tmp}/duckdb-cli.XXXXXX.sql")"
trap 'rm -f "${INIT_SQL}"' EXIT

cat >"${INIT_SQL}" <<SQL
.bail on

INSTALL httpfs;
INSTALL postgres;
INSTALL ducklake;

LOAD httpfs;
LOAD postgres;
LOAD ducklake;

CREATE OR REPLACE TEMPORARY SECRET ${DUCKLAKE_GCS_SECRET_NAME} (
    TYPE gcs,
    KEY_ID $(sql_literal "${DUCKLAKE_GCS_HMAC_KEY_ID}"),
    SECRET $(sql_literal "${DUCKLAKE_GCS_HMAC_SECRET}"),
    SCOPE $(sql_literal "${DUCKLAKE_GCS_PATH}")
);

CREATE OR REPLACE TEMPORARY SECRET ${DUCKLAKE_POSTGRES_SECRET_NAME} (
    TYPE postgres,
    HOST $(sql_literal "${DUCKLAKE_PG_HOST}"),
    PORT ${DUCKLAKE_PG_PORT},
    DATABASE $(sql_literal "${DUCKLAKE_PG_DATABASE}"),
    USER $(sql_literal "${DUCKLAKE_PG_USER}"),
    PASSWORD $(sql_literal "${DUCKLAKE_PG_PASSWORD}")
);

CREATE OR REPLACE TEMPORARY SECRET ${DUCKLAKE_SECRET_NAME} (
    TYPE ducklake,
    METADATA_PATH '',
    DATA_PATH $(sql_literal "${DUCKLAKE_GCS_PATH}"),
    METADATA_SCHEMA $(sql_literal "${DUCKLAKE_METADATA_SCHEMA}"),
    METADATA_PARAMETERS MAP {'TYPE': 'postgres', 'SECRET': $(sql_literal "${DUCKLAKE_POSTGRES_SECRET_NAME}")}
);

ATTACH IF NOT EXISTS 'ducklake:${DUCKLAKE_SECRET_NAME}' AS ${DUCKLAKE_CATALOG_NAME};
USE ${DUCKLAKE_CATALOG_NAME};

.print 'DuckLake CLI ready. Run ".read scripts/duckdb_sample_queries.sql" for sample queries.'
SQL

cd "${PROJECT_ROOT}"
duckdb :memory: -init "${INIT_SQL}"
