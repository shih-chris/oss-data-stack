#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
  set +a
fi

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  printf 'Set GCP_PROJECT_ID before running this script.\n' >&2
  exit 1
fi

GCP_REGION="${GCP_REGION:-us-central1}"
CLOUD_SQL_INSTANCE="${CLOUD_SQL_INSTANCE:-ducklake-postgres}"
CLOUD_SQL_CONNECTION_NAME="${CLOUD_SQL_CONNECTION_NAME:-${GCP_PROJECT_ID}:${GCP_REGION}:${CLOUD_SQL_INSTANCE}}"
DUCKLAKE_GCS_BUCKET="${DUCKLAKE_GCS_BUCKET:-${GCP_PROJECT_ID}-ducklake}"
DUCKLAKE_GCS_PREFIX="${DUCKLAKE_GCS_PREFIX:-ducklake}"
DUCKLAKE_GCS_PATH="${DUCKLAKE_GCS_PATH:-gs://${DUCKLAKE_GCS_BUCKET}/${DUCKLAKE_GCS_PREFIX}}"
DUCKLAKE_PG_DATABASE="${DUCKLAKE_PG_DATABASE:-ducklake_catalog}"
DUCKLAKE_PG_USER="${DUCKLAKE_PG_USER:-postgres}"
DAGSTER_PG_DATABASE="${DAGSTER_PG_DATABASE:-dagster}"
DAGSTER_PG_USER="${DAGSTER_PG_USER:-${DUCKLAKE_PG_USER}}"
DAGSTER_PG_PASSWORD="${DAGSTER_PG_PASSWORD:-${DUCKLAKE_PG_PASSWORD:-}}"
ARTIFACT_REPOSITORY="${ARTIFACT_REPOSITORY:-oss-data-stack}"
DAGSTER_RUNTIME_SERVICE_ACCOUNT="${DAGSTER_RUNTIME_SERVICE_ACCOUNT:-dagster-runtime}"
DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL="${DAGSTER_RUNTIME_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
GITHUB_DEPLOY_SERVICE_ACCOUNT="${GITHUB_DEPLOY_SERVICE_ACCOUNT:-github-dagster-deployer}"
GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL="${GITHUB_DEPLOY_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
GITHUB_WIF_POOL="${GITHUB_WIF_POOL:-github-actions}"
GITHUB_WIF_PROVIDER="${GITHUB_WIF_PROVIDER:-github}"

DUCKLAKE_PG_PASSWORD_SECRET="${DUCKLAKE_PG_PASSWORD_SECRET:-ducklake-pg-password}"
DUCKLAKE_GCS_HMAC_KEY_ID_SECRET="${DUCKLAKE_GCS_HMAC_KEY_ID_SECRET:-ducklake-gcs-hmac-key-id}"
DUCKLAKE_GCS_HMAC_SECRET_SECRET="${DUCKLAKE_GCS_HMAC_SECRET_SECRET:-ducklake-gcs-hmac-secret}"
DAGSTER_POSTGRES_URL_SECRET="${DAGSTER_POSTGRES_URL_SECRET:-dagster-postgres-url}"
GRAFANA_LOKI_URL_SECRET="${GRAFANA_LOKI_URL_SECRET:-grafana-cloud-loki-url}"
GRAFANA_LOKI_USER_SECRET="${GRAFANA_LOKI_USER_SECRET:-grafana-cloud-loki-user}"
GRAFANA_LOKI_API_KEY_SECRET="${GRAFANA_LOKI_API_KEY_SECRET:-grafana-cloud-loki-api-key}"
GRAFANA_ALLOY_CONFIG_SECRET="${GRAFANA_ALLOY_CONFIG_SECRET:-grafana-alloy-config}"

run() {
  printf -- '-> %s\n' "$*"
  "$@"
}

require_value() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required environment value: %s\n' "${name}" >&2
    exit 1
  fi
}

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

ensure_secret() {
  local name="$1"
  local value="$2"

  if ! gcloud secrets describe "${name}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
    run gcloud secrets create "${name}" --project "${GCP_PROJECT_ID}" --replication-policy automatic
  else
    printf -- '-> Secret %s already exists\n' "${name}"
  fi

  printf '%s' "${value}" | gcloud secrets versions add "${name}" \
    --project "${GCP_PROJECT_ID}" \
    --data-file=- >/dev/null
}

ensure_secret_file() {
  local name="$1"
  local path="$2"

  if ! gcloud secrets describe "${name}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
    run gcloud secrets create "${name}" --project "${GCP_PROJECT_ID}" --replication-policy automatic
  else
    printf -- '-> Secret %s already exists\n' "${name}"
  fi

  gcloud secrets versions add "${name}" \
    --project "${GCP_PROJECT_ID}" \
    --data-file="${path}" >/dev/null
}

require_value DUCKLAKE_PG_PASSWORD
require_value DUCKLAKE_GCS_HMAC_KEY_ID
require_value DUCKLAKE_GCS_HMAC_SECRET

run gcloud config set project "${GCP_PROJECT_ID}"

run gcloud services enable \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  --project "${GCP_PROJECT_ID}"

if ! gcloud artifacts repositories describe "${ARTIFACT_REPOSITORY}" \
  --project "${GCP_PROJECT_ID}" \
  --location "${GCP_REGION}" >/dev/null 2>&1; then
  run gcloud artifacts repositories create "${ARTIFACT_REPOSITORY}" \
    --project "${GCP_PROJECT_ID}" \
    --location "${GCP_REGION}" \
    --repository-format docker \
    --description "OSS data stack container images"
else
  printf -- '-> Artifact Registry repository %s already exists\n' "${ARTIFACT_REPOSITORY}"
fi

if ! gcloud sql databases describe "${DAGSTER_PG_DATABASE}" \
  --project "${GCP_PROJECT_ID}" \
  --instance "${CLOUD_SQL_INSTANCE}" >/dev/null 2>&1; then
  run gcloud sql databases create "${DAGSTER_PG_DATABASE}" \
    --project "${GCP_PROJECT_ID}" \
    --instance "${CLOUD_SQL_INSTANCE}"
else
  printf -- '-> Cloud SQL database %s already exists\n' "${DAGSTER_PG_DATABASE}"
fi

if ! gcloud iam service-accounts describe "${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
  --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
  run gcloud iam service-accounts create "${DAGSTER_RUNTIME_SERVICE_ACCOUNT}" \
    --project "${GCP_PROJECT_ID}" \
    --display-name "Dagster Cloud Run runtime"
else
  printf -- '-> Service account %s already exists\n' "${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}"
fi

run gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
  --role roles/cloudsql.client >/dev/null
run gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
  --role roles/secretmanager.secretAccessor >/dev/null
run gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
  --role roles/artifactregistry.reader >/dev/null

run gcloud storage buckets add-iam-policy-binding "gs://${DUCKLAKE_GCS_BUCKET}" \
  --project "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
  --role roles/storage.objectAdmin >/dev/null
run gcloud storage buckets add-iam-policy-binding "gs://${DUCKLAKE_GCS_BUCKET}" \
  --project "${GCP_PROJECT_ID}" \
  --member "serviceAccount:${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
  --role roles/storage.legacyBucketReader >/dev/null

encoded_pg_user="$(urlencode "${DAGSTER_PG_USER}")"
encoded_pg_password="$(urlencode "${DAGSTER_PG_PASSWORD}")"
encoded_socket_path="$(urlencode "/cloudsql/${CLOUD_SQL_CONNECTION_NAME}")"
DAGSTER_POSTGRES_URL="postgresql://${encoded_pg_user}:${encoded_pg_password}@/${DAGSTER_PG_DATABASE}?host=${encoded_socket_path}"

ensure_secret "${DUCKLAKE_PG_PASSWORD_SECRET}" "${DUCKLAKE_PG_PASSWORD}"
ensure_secret "${DUCKLAKE_GCS_HMAC_KEY_ID_SECRET}" "${DUCKLAKE_GCS_HMAC_KEY_ID}"
ensure_secret "${DUCKLAKE_GCS_HMAC_SECRET_SECRET}" "${DUCKLAKE_GCS_HMAC_SECRET}"
ensure_secret "${DAGSTER_POSTGRES_URL_SECRET}" "${DAGSTER_POSTGRES_URL}"
ensure_secret_file "${GRAFANA_ALLOY_CONFIG_SECRET}" "${PROJECT_ROOT}/config/alloy/config.alloy"

if [[ -n "${LOKI_URL:-}" ]]; then
  ensure_secret "${GRAFANA_LOKI_URL_SECRET}" "${LOKI_URL}"
else
  printf -- '-> Skipping %s; set LOKI_URL to create it\n' "${GRAFANA_LOKI_URL_SECRET}"
fi
if [[ -n "${LOKI_USER:-}" ]]; then
  ensure_secret "${GRAFANA_LOKI_USER_SECRET}" "${LOKI_USER}"
else
  printf -- '-> Skipping %s; set LOKI_USER to create it\n' "${GRAFANA_LOKI_USER_SECRET}"
fi
if [[ -n "${LOKI_API_KEY:-}" ]]; then
  ensure_secret "${GRAFANA_LOKI_API_KEY_SECRET}" "${LOKI_API_KEY}"
else
  printf -- '-> Skipping %s; set LOKI_API_KEY to create it\n' "${GRAFANA_LOKI_API_KEY_SECRET}"
fi

if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT_ID}" --format 'value(projectNumber)')"

  if ! gcloud iam workload-identity-pools describe "${GITHUB_WIF_POOL}" \
    --project "${GCP_PROJECT_ID}" \
    --location global >/dev/null 2>&1; then
    run gcloud iam workload-identity-pools create "${GITHUB_WIF_POOL}" \
      --project "${GCP_PROJECT_ID}" \
      --location global \
      --display-name "GitHub Actions"
  else
    printf -- '-> Workload Identity Pool %s already exists\n' "${GITHUB_WIF_POOL}"
  fi

  if ! gcloud iam workload-identity-pools providers describe "${GITHUB_WIF_PROVIDER}" \
    --project "${GCP_PROJECT_ID}" \
    --location global \
    --workload-identity-pool "${GITHUB_WIF_POOL}" >/dev/null 2>&1; then
    run gcloud iam workload-identity-pools providers create-oidc "${GITHUB_WIF_PROVIDER}" \
      --project "${GCP_PROJECT_ID}" \
      --location global \
      --workload-identity-pool "${GITHUB_WIF_POOL}" \
      --display-name "GitHub ${GITHUB_REPOSITORY}" \
      --issuer-uri "https://token.actions.githubusercontent.com" \
      --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
      --attribute-condition "assertion.repository=='${GITHUB_REPOSITORY}'"
  else
    printf -- '-> Workload Identity Provider %s already exists\n' "${GITHUB_WIF_PROVIDER}"
  fi

  if ! gcloud iam service-accounts describe "${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}" \
    --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
    run gcloud iam service-accounts create "${GITHUB_DEPLOY_SERVICE_ACCOUNT}" \
      --project "${GCP_PROJECT_ID}" \
      --display-name "GitHub Dagster deployer"
  else
    printf -- '-> Service account %s already exists\n' "${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}"
  fi

  run gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
    --member "serviceAccount:${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}" \
    --role roles/run.admin >/dev/null
  run gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
    --member "serviceAccount:${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}" \
    --role roles/artifactregistry.writer >/dev/null
  run gcloud iam service-accounts add-iam-policy-binding "${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}" \
    --project "${GCP_PROJECT_ID}" \
    --member "serviceAccount:${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}" \
    --role roles/iam.serviceAccountUser >/dev/null

  principal="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${GITHUB_WIF_POOL}/attribute.repository/${GITHUB_REPOSITORY}"
  run gcloud iam service-accounts add-iam-policy-binding "${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}" \
    --project "${GCP_PROJECT_ID}" \
    --member "${principal}" \
    --role roles/iam.workloadIdentityUser >/dev/null

  printf '\nGitHub Actions variables:\n'
  printf 'GCP_PROJECT_ID=%s\n' "${GCP_PROJECT_ID}"
  printf 'GCP_REGION=%s\n' "${GCP_REGION}"
  printf 'GCP_WORKLOAD_IDENTITY_PROVIDER=projects/%s/locations/global/workloadIdentityPools/%s/providers/%s\n' "${PROJECT_NUMBER}" "${GITHUB_WIF_POOL}" "${GITHUB_WIF_PROVIDER}"
  printf 'GCP_DEPLOY_SERVICE_ACCOUNT=%s\n' "${GITHUB_DEPLOY_SERVICE_ACCOUNT_EMAIL}"
fi

printf '\nDagster GCP infrastructure is ready. Build and deploy with scripts/deploy_dagster.sh.\n'
