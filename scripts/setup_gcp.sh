#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  printf 'Set GCP_PROJECT_ID before running this script.\n' >&2
  exit 1
fi

GCP_REGION="${GCP_REGION:-us-central1}"
GCS_BUCKET="${DUCKLAKE_GCS_BUCKET:-${GCP_PROJECT_ID}-ducklake}"
GCS_PREFIX="${DUCKLAKE_GCS_PREFIX:-ducklake}"
CLOUD_SQL_INSTANCE="${CLOUD_SQL_INSTANCE:-ducklake-postgres}"
CLOUD_SQL_TIER="${CLOUD_SQL_TIER:-db-f1-micro}"
CLOUD_SQL_STORAGE_SIZE_GB="${CLOUD_SQL_STORAGE_SIZE_GB:-10}"
DUCKLAKE_PG_DATABASE="${DUCKLAKE_PG_DATABASE:-ducklake_catalog}"
DUCKLAKE_PG_USER="${DUCKLAKE_PG_USER:-postgres}"
DUCKLAKE_CATALOG_NAME="${DUCKLAKE_CATALOG_NAME:-ducklake}"
DUCKLAKE_METADATA_SCHEMA="${DUCKLAKE_METADATA_SCHEMA:-${DUCKLAKE_CATALOG_NAME}}"
DUCKLAKE_SERVICE_ACCOUNT="${DUCKLAKE_SERVICE_ACCOUNT:-ducklake-storage}"
SERVICE_ACCOUNT_EMAIL="${DUCKLAKE_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
SERVICE_ACCOUNT_KEY_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-config/keys/ducklake-service-account.json}"

if [[ "${DUCKLAKE_PG_USER}" != "postgres" ]]; then
  printf 'This setup script currently manages the default Cloud SQL postgres user only.\n' >&2
  printf 'Set DUCKLAKE_PG_USER=postgres or create/grant a custom user separately.\n' >&2
  exit 1
fi

if [[ -z "${DUCKLAKE_PG_PASSWORD:-}" ]]; then
  GENERATED_PG_PASSWORD="1"
  DUCKLAKE_PG_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
else
  GENERATED_PG_PASSWORD="0"
fi

if [[ -n "${DUCKLAKE_GCS_HMAC_KEY_ID:-}" && -n "${DUCKLAKE_GCS_HMAC_SECRET:-}" ]]; then
  CREATE_HMAC="0"
else
  CREATE_HMAC="1"
fi

run() {
  printf -- '-> %s\n' "$*"
  "$@"
}

run gcloud config set project "${GCP_PROJECT_ID}"

run gcloud services enable \
  iam.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  --project "${GCP_PROJECT_ID}"

if gcloud sql instances describe "${CLOUD_SQL_INSTANCE}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1 && [[ "${GENERATED_PG_PASSWORD}" == "1" ]]; then
  printf 'Existing Cloud SQL instance found and DUCKLAKE_PG_PASSWORD was not provided.\n' >&2
  printf 'Set DUCKLAKE_PG_PASSWORD to the current password and re-run this script.\n' >&2
  exit 1
fi

if ! gcloud storage buckets describe "gs://${GCS_BUCKET}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
  run gcloud storage buckets create "gs://${GCS_BUCKET}" \
    --project "${GCP_PROJECT_ID}" \
    --location "${GCP_REGION}" \
    --uniform-bucket-level-access
else
  printf -- '-> GCS bucket gs://%s already exists\n' "${GCS_BUCKET}"
fi

if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
  run gcloud iam service-accounts create "${DUCKLAKE_SERVICE_ACCOUNT}" \
    --project "${GCP_PROJECT_ID}" \
    --display-name "DuckLake storage service account"
else
  printf -- '-> Service account %s already exists\n' "${SERVICE_ACCOUNT_EMAIL}"
fi

run gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
  --project "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role "roles/storage.objectAdmin" >/dev/null

run gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
  --project "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role "roles/storage.legacyBucketReader" >/dev/null

if [[ ! -f "${SERVICE_ACCOUNT_KEY_FILE}" ]]; then
  mkdir -p "$(dirname "${SERVICE_ACCOUNT_KEY_FILE}")"
  run gcloud iam service-accounts keys create "${SERVICE_ACCOUNT_KEY_FILE}" \
    --project "${GCP_PROJECT_ID}" \
    --iam-account "${SERVICE_ACCOUNT_EMAIL}"
else
  printf -- '-> Service account key file %s already exists\n' "${SERVICE_ACCOUNT_KEY_FILE}"
fi

INSTANCE_CREATED="0"
if ! gcloud sql instances describe "${CLOUD_SQL_INSTANCE}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
  INSTANCE_CREATED="1"
  run gcloud sql instances create "${CLOUD_SQL_INSTANCE}" \
    --project "${GCP_PROJECT_ID}" \
    --database-version POSTGRES_15 \
    --region "${GCP_REGION}" \
    --tier "${CLOUD_SQL_TIER}" \
    --storage-size "${CLOUD_SQL_STORAGE_SIZE_GB}" \
    --availability-type ZONAL \
    --root-password "${DUCKLAKE_PG_PASSWORD}"
else
  printf -- '-> Cloud SQL instance %s already exists\n' "${CLOUD_SQL_INSTANCE}"
fi

if [[ "${INSTANCE_CREATED}" == "0" && "${RESET_CLOUD_SQL_PASSWORD:-0}" == "1" ]]; then
  run gcloud sql users set-password "${DUCKLAKE_PG_USER}" \
    --project "${GCP_PROJECT_ID}" \
    --instance "${CLOUD_SQL_INSTANCE}" \
    --password "${DUCKLAKE_PG_PASSWORD}"
fi

if ! gcloud sql databases describe "${DUCKLAKE_PG_DATABASE}" \
  --project "${GCP_PROJECT_ID}" \
  --instance "${CLOUD_SQL_INSTANCE}" >/dev/null 2>&1; then
  run gcloud sql databases create "${DUCKLAKE_PG_DATABASE}" \
    --project "${GCP_PROJECT_ID}" \
    --instance "${CLOUD_SQL_INSTANCE}"
else
  printf -- '-> Cloud SQL database %s already exists\n' "${DUCKLAKE_PG_DATABASE}"
fi

if [[ "${CREATE_HMAC}" == "1" ]]; then
  printf -- '-> Creating GCS HMAC key for %s\n' "${SERVICE_ACCOUNT_EMAIL}"
  HMAC_JSON="$(gcloud storage hmac create "${SERVICE_ACCOUNT_EMAIL}" \
    --project "${GCP_PROJECT_ID}" \
    --format json)"
  DUCKLAKE_GCS_HMAC_KEY_ID="$(python3 -c 'import json, sys; data=json.load(sys.stdin); metadata=data.get("metadata", data); print(metadata.get("accessId") or metadata.get("id"))' <<<"${HMAC_JSON}")"
  DUCKLAKE_GCS_HMAC_SECRET="$(python3 -c 'import json, sys; data=json.load(sys.stdin); print(data.get("secret") or data.get("secretKey"))' <<<"${HMAC_JSON}")"
  if [[ -z "${DUCKLAKE_GCS_HMAC_KEY_ID}" || "${DUCKLAKE_GCS_HMAC_KEY_ID}" == "None" || -z "${DUCKLAKE_GCS_HMAC_SECRET}" || "${DUCKLAKE_GCS_HMAC_SECRET}" == "None" ]]; then
    printf 'Could not parse HMAC key details from gcloud output.\n' >&2
    exit 1
  fi
fi

DUCKLAKE_GCS_PATH="gs://${GCS_BUCKET}/${GCS_PREFIX}"
CONNECTION_NAME="${GCP_PROJECT_ID}:${GCP_REGION}:${CLOUD_SQL_INSTANCE}"

ENV_BLOCK="GCP_PROJECT_ID=${GCP_PROJECT_ID}
GCP_REGION=${GCP_REGION}
CLOUD_SQL_INSTANCE=${CLOUD_SQL_INSTANCE}
CLOUD_SQL_CONNECTION_NAME=${CONNECTION_NAME}
GOOGLE_APPLICATION_CREDENTIALS=${SERVICE_ACCOUNT_KEY_FILE}
DUCKLAKE_CATALOG_NAME=${DUCKLAKE_CATALOG_NAME}
DUCKLAKE_METADATA_SCHEMA=${DUCKLAKE_METADATA_SCHEMA}
DUCKLAKE_GCS_BUCKET=${GCS_BUCKET}
DUCKLAKE_GCS_PREFIX=${GCS_PREFIX}
DUCKLAKE_GCS_PATH=${DUCKLAKE_GCS_PATH}
DUCKLAKE_GCS_HMAC_KEY_ID=${DUCKLAKE_GCS_HMAC_KEY_ID}
DUCKLAKE_GCS_HMAC_SECRET=${DUCKLAKE_GCS_HMAC_SECRET}
DUCKLAKE_PG_HOST=127.0.0.1
DUCKLAKE_PG_PORT=5432
DUCKLAKE_PG_DATABASE=${DUCKLAKE_PG_DATABASE}
DUCKLAKE_PG_USER=${DUCKLAKE_PG_USER}
DUCKLAKE_PG_PASSWORD=${DUCKLAKE_PG_PASSWORD}"

printf '\nDuckLake environment values:\n%s\n' "${ENV_BLOCK}"

if [[ "${WRITE_ENV_FILE:-0}" == "1" ]]; then
  ENV_FILE="${ENV_FILE:-.env}"
  if [[ -e "${ENV_FILE}" && "${OVERWRITE_ENV_FILE:-0}" != "1" ]]; then
    printf 'Refusing to overwrite existing %s. Set OVERWRITE_ENV_FILE=1 to replace it.\n' "${ENV_FILE}" >&2
    exit 1
  fi
  umask 077
  printf '%s\n' "${ENV_BLOCK}" > "${ENV_FILE}"
  printf -- '-> Wrote %s\n' "${ENV_FILE}"
fi

printf '\nStart the Cloud SQL Auth Proxy with scripts/start_cloud_sql_proxy.sh before running DuckLake workloads.\n'
