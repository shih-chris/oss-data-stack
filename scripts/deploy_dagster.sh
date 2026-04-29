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
ARTIFACT_REPOSITORY="${ARTIFACT_REPOSITORY:-oss-data-stack}"
DAGSTER_IMAGE_NAME="${DAGSTER_IMAGE_NAME:-dagster}"
IMAGE_TAG="${IMAGE_TAG:-$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD)}"
IMAGE_URI="${IMAGE_URI:-${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REPOSITORY}/${DAGSTER_IMAGE_NAME}:${IMAGE_TAG}}"
DAGSTER_RUNTIME_SERVICE_ACCOUNT="${DAGSTER_RUNTIME_SERVICE_ACCOUNT:-dagster-runtime}"
DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL="${DAGSTER_RUNTIME_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
DAGSTER_WEBSERVER_SERVICE="${DAGSTER_WEBSERVER_SERVICE:-dagster-webserver}"
DAGSTER_DAEMON_SERVICE="${DAGSTER_DAEMON_SERVICE:-dagster-daemon}"
DAGSTER_WEBSERVER_INGRESS="${DAGSTER_WEBSERVER_INGRESS:-all}"
DUCKLAKE_GCS_BUCKET="${DUCKLAKE_GCS_BUCKET:-${GCP_PROJECT_ID}-ducklake}"
DUCKLAKE_GCS_PREFIX="${DUCKLAKE_GCS_PREFIX:-ducklake}"
DUCKLAKE_GCS_PATH="${DUCKLAKE_GCS_PATH:-gs://${DUCKLAKE_GCS_BUCKET}/${DUCKLAKE_GCS_PREFIX}}"
DUCKLAKE_CATALOG_NAME="${DUCKLAKE_CATALOG_NAME:-ducklake}"
DUCKLAKE_METADATA_SCHEMA="${DUCKLAKE_METADATA_SCHEMA:-${DUCKLAKE_CATALOG_NAME}}"
DUCKLAKE_PG_DATABASE="${DUCKLAKE_PG_DATABASE:-ducklake_catalog}"
DUCKLAKE_PG_USER="${DUCKLAKE_PG_USER:-postgres}"
DAGSTER_PG_DATABASE="${DAGSTER_PG_DATABASE:-dagster}"
DAGSTER_PG_USER="${DAGSTER_PG_USER:-${DUCKLAKE_PG_USER}}"

DUCKLAKE_PG_PASSWORD_SECRET="${DUCKLAKE_PG_PASSWORD_SECRET:-ducklake-pg-password}"
DUCKLAKE_GCS_HMAC_KEY_ID_SECRET="${DUCKLAKE_GCS_HMAC_KEY_ID_SECRET:-ducklake-gcs-hmac-key-id}"
DUCKLAKE_GCS_HMAC_SECRET_SECRET="${DUCKLAKE_GCS_HMAC_SECRET_SECRET:-ducklake-gcs-hmac-secret}"
DAGSTER_POSTGRES_URL_SECRET="${DAGSTER_POSTGRES_URL_SECRET:-dagster-postgres-url}"
GRAFANA_LOKI_URL_SECRET="${GRAFANA_LOKI_URL_SECRET:-grafana-cloud-loki-url}"
GRAFANA_LOKI_USER_SECRET="${GRAFANA_LOKI_USER_SECRET:-grafana-cloud-loki-user}"
GRAFANA_LOKI_API_KEY_SECRET="${GRAFANA_LOKI_API_KEY_SECRET:-grafana-cloud-loki-api-key}"
GRAFANA_ALLOY_CONFIG_SECRET="${GRAFANA_ALLOY_CONFIG_SECRET:-grafana-alloy-config}"
GRAFANA_ALLOY_IMAGE="${GRAFANA_ALLOY_IMAGE:-docker.io/grafana/alloy:latest}"
DAGSTER_CONTAINER_MEMORY="${DAGSTER_CONTAINER_MEMORY:-2Gi}"
GRAFANA_ALLOY_CONTAINER_MEMORY="${GRAFANA_ALLOY_CONTAINER_MEMORY:-256Mi}"

run() {
  printf -- '-> %s\n' "$*"
  "$@"
}

write_service_yaml() {
  local service_name="$1"
  local min_scale="$2"
  local max_scale="$3"
  local command="$4"
  local cpu_throttling="$5"
  local ingress="$6"
  local output_path="$7"

  cat >"${output_path}" <<YAML
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${service_name}
  annotations:
    run.googleapis.com/ingress: ${ingress}
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "${min_scale}"
        autoscaling.knative.dev/maxScale: "${max_scale}"
        run.googleapis.com/cloudsql-instances: ${CLOUD_SQL_CONNECTION_NAME}
        run.googleapis.com/cpu-throttling: "${cpu_throttling}"
    spec:
      serviceAccountName: ${DAGSTER_RUNTIME_SERVICE_ACCOUNT_EMAIL}
      containers:
      - name: dagster
        image: ${IMAGE_URI}
        command: ["${command}"]
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "1"
            memory: ${DAGSTER_CONTAINER_MEMORY}
        volumeMounts:
        - name: dagster-logs
          mountPath: /var/log/dagster
        env:
        - name: DAGSTER_HOME
          value: /app/dagster_home
        - name: GCP_PROJECT_ID
          value: ${GCP_PROJECT_ID}
        - name: GCP_REGION
          value: ${GCP_REGION}
        - name: CLOUD_SQL_INSTANCE
          value: ${CLOUD_SQL_INSTANCE}
        - name: CLOUD_SQL_CONNECTION_NAME
          value: ${CLOUD_SQL_CONNECTION_NAME}
        - name: DAGSTER_PG_DATABASE
          value: ${DAGSTER_PG_DATABASE}
        - name: DAGSTER_PG_USER
          value: ${DAGSTER_PG_USER}
        - name: DAGSTER_POSTGRES_URL
          valueFrom:
            secretKeyRef:
              name: ${DAGSTER_POSTGRES_URL_SECRET}
              key: latest
        - name: DUCKLAKE_CATALOG_NAME
          value: ${DUCKLAKE_CATALOG_NAME}
        - name: DUCKLAKE_METADATA_SCHEMA
          value: ${DUCKLAKE_METADATA_SCHEMA}
        - name: DUCKLAKE_GCS_BUCKET
          value: ${DUCKLAKE_GCS_BUCKET}
        - name: DUCKLAKE_GCS_PREFIX
          value: ${DUCKLAKE_GCS_PREFIX}
        - name: DUCKLAKE_GCS_PATH
          value: ${DUCKLAKE_GCS_PATH}
        - name: DUCKLAKE_PG_HOST
          value: /cloudsql/${CLOUD_SQL_CONNECTION_NAME}
        - name: DUCKLAKE_PG_PORT
          value: "5432"
        - name: DUCKLAKE_PG_DATABASE
          value: ${DUCKLAKE_PG_DATABASE}
        - name: DUCKLAKE_PG_USER
          value: ${DUCKLAKE_PG_USER}
        - name: DUCKLAKE_PG_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ${DUCKLAKE_PG_PASSWORD_SECRET}
              key: latest
        - name: DUCKLAKE_GCS_HMAC_KEY_ID
          valueFrom:
            secretKeyRef:
              name: ${DUCKLAKE_GCS_HMAC_KEY_ID_SECRET}
              key: latest
        - name: DUCKLAKE_GCS_HMAC_SECRET
          valueFrom:
            secretKeyRef:
              name: ${DUCKLAKE_GCS_HMAC_SECRET_SECRET}
              key: latest
      - name: alloy
        image: ${GRAFANA_ALLOY_IMAGE}
        args: ["run", "/etc/alloy/config.alloy", "--storage.path=/var/lib/alloy/data"]
        resources:
          limits:
            cpu: "0.25"
            memory: ${GRAFANA_ALLOY_CONTAINER_MEMORY}
        volumeMounts:
        - name: dagster-logs
          mountPath: /var/log/dagster
          readOnly: true
        - name: alloy-config
          mountPath: /etc/alloy
          readOnly: true
        env:
        - name: GCP_PROJECT_ID
          value: ${GCP_PROJECT_ID}
        - name: LOKI_URL
          valueFrom:
            secretKeyRef:
              name: ${GRAFANA_LOKI_URL_SECRET}
              key: latest
        - name: LOKI_USER
          valueFrom:
            secretKeyRef:
              name: ${GRAFANA_LOKI_USER_SECRET}
              key: latest
        - name: LOKI_API_KEY
          valueFrom:
            secretKeyRef:
              name: ${GRAFANA_LOKI_API_KEY_SECRET}
              key: latest
      volumes:
      - name: dagster-logs
        emptyDir:
          sizeLimit: 512Mi
      - name: alloy-config
        secret:
          secretName: ${GRAFANA_ALLOY_CONFIG_SECRET}
          items:
          - key: latest
            path: config.alloy
YAML
}

run gcloud config set project "${GCP_PROJECT_ID}"
run gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet

if ! gcloud artifacts repositories describe "${ARTIFACT_REPOSITORY}" \
  --project "${GCP_PROJECT_ID}" \
  --location "${GCP_REGION}" >/dev/null 2>&1; then
  printf 'Artifact Registry repository %s does not exist in %s/%s.\n' "${ARTIFACT_REPOSITORY}" "${GCP_PROJECT_ID}" "${GCP_REGION}" >&2
  printf 'Run scripts/setup_dagster_gcp.sh first, or create it manually with:\n' >&2
  printf '  gcloud artifacts repositories create %s --project %s --location %s --repository-format docker\n' "${ARTIFACT_REPOSITORY}" "${GCP_PROJECT_ID}" "${GCP_REGION}" >&2
  exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  run docker build --platform linux/amd64 -t "${IMAGE_URI}" "${PROJECT_ROOT}"
  run docker push "${IMAGE_URI}"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dagster-cloudrun.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

write_service_yaml "${DAGSTER_WEBSERVER_SERVICE}" "0" "3" "scripts/entrypoint-webserver.sh" "true" "${DAGSTER_WEBSERVER_INGRESS}" "${TMP_DIR}/webserver.yaml"
write_service_yaml "${DAGSTER_DAEMON_SERVICE}" "1" "1" "scripts/entrypoint-daemon.sh" "false" "internal" "${TMP_DIR}/daemon.yaml"

run gcloud run services replace "${TMP_DIR}/webserver.yaml" --project "${GCP_PROJECT_ID}" --region "${GCP_REGION}"
run gcloud run services replace "${TMP_DIR}/daemon.yaml" --project "${GCP_PROJECT_ID}" --region "${GCP_REGION}"

if [[ "${DAGSTER_WEBSERVER_ALLOW_UNAUTHENTICATED:-0}" == "1" ]]; then
  run gcloud run services add-iam-policy-binding "${DAGSTER_WEBSERVER_SERVICE}" \
    --project "${GCP_PROJECT_ID}" \
    --region "${GCP_REGION}" \
    --member allUsers \
    --role roles/run.invoker >/dev/null
fi

printf '\nDeployed %s to Cloud Run:\n' "${IMAGE_URI}"
run gcloud run services list --project "${GCP_PROJECT_ID}" --region "${GCP_REGION}" --filter "metadata.name~'${DAGSTER_WEBSERVER_SERVICE}|${DAGSTER_DAEMON_SERVICE}'"
