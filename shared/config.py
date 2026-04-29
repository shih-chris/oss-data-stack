"""Shared configuration utilities."""

import json
import os
from pathlib import Path
from urllib.parse import quote, urlencode

from dotenv import load_dotenv

# Project root directory
PROJECT_ROOT = Path(__file__).parent.parent

# Load environment variables from project-local env files when present.
load_dotenv(PROJECT_ROOT / ".env")
load_dotenv(PROJECT_ROOT / "config" / ".env", override=False)

# GCP infrastructure
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
GCP_REGION = os.getenv("GCP_REGION", "us-central1")
CLOUD_SQL_INSTANCE = os.getenv("CLOUD_SQL_INSTANCE", "ducklake-postgres")
GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

# DuckLake catalog and storage
DUCKLAKE_CATALOG_NAME = os.getenv("DUCKLAKE_CATALOG_NAME", "ducklake")
DUCKLAKE_METADATA_SCHEMA = os.getenv("DUCKLAKE_METADATA_SCHEMA", DUCKLAKE_CATALOG_NAME)
DUCKLAKE_GCS_BUCKET = os.getenv("DUCKLAKE_GCS_BUCKET")
DUCKLAKE_GCS_PREFIX = os.getenv("DUCKLAKE_GCS_PREFIX", "ducklake")
DUCKLAKE_GCS_HMAC_KEY_ID = os.getenv("DUCKLAKE_GCS_HMAC_KEY_ID")
DUCKLAKE_GCS_HMAC_SECRET = os.getenv("DUCKLAKE_GCS_HMAC_SECRET")

# Cloud SQL Auth Proxy defaults to localhost.
DUCKLAKE_PG_HOST = os.getenv("DUCKLAKE_PG_HOST", "127.0.0.1")
DUCKLAKE_PG_PORT = os.getenv("DUCKLAKE_PG_PORT", "5432")
DUCKLAKE_PG_DATABASE = os.getenv("DUCKLAKE_PG_DATABASE", "ducklake_catalog")
DUCKLAKE_PG_USER = os.getenv("DUCKLAKE_PG_USER", "postgres")
DUCKLAKE_PG_PASSWORD = os.getenv("DUCKLAKE_PG_PASSWORD")

# DuckDB secret names used for in-memory sessions.
DUCKLAKE_SECRET_NAME = os.getenv("DUCKLAKE_SECRET_NAME", "ducklake_secret")
DUCKLAKE_POSTGRES_SECRET_NAME = os.getenv("DUCKLAKE_POSTGRES_SECRET_NAME", "ducklake_postgres")
DUCKLAKE_GCS_SECRET_NAME = os.getenv("DUCKLAKE_GCS_SECRET_NAME", "ducklake_gcs")

# dlt configuration
DLT_CONFIG_PATH = PROJECT_ROOT / "config" / "dlt" / "config.toml"


def get_ducklake_gcs_path() -> str:
    """Return the DuckLake data path in GCS."""
    explicit_path = os.getenv("DUCKLAKE_GCS_PATH")
    if explicit_path:
        return explicit_path.rstrip("/")
    if not DUCKLAKE_GCS_BUCKET:
        return ""

    prefix = DUCKLAKE_GCS_PREFIX.strip("/")
    if not prefix:
        return f"gs://{DUCKLAKE_GCS_BUCKET}"
    return f"gs://{DUCKLAKE_GCS_BUCKET}/{prefix}"


DUCKLAKE_GCS_PATH = get_ducklake_gcs_path()


def get_ducklake_catalog_uri() -> str:
    """Return a Postgres URI for dlt's native DuckLake destination."""
    if not DUCKLAKE_PG_PASSWORD:
        return ""

    user = quote(DUCKLAKE_PG_USER, safe="")
    password = quote(DUCKLAKE_PG_PASSWORD, safe="")
    if DUCKLAKE_PG_HOST.startswith("/"):
        params = urlencode(
            {"host": DUCKLAKE_PG_HOST, "port": DUCKLAKE_PG_PORT},
            quote_via=quote,
        )
        return f"postgresql://{user}:{password}@/{DUCKLAKE_PG_DATABASE}?{params}"

    return (
        f"postgresql://{user}:{password}"
        f"@{DUCKLAKE_PG_HOST}:{DUCKLAKE_PG_PORT}/{DUCKLAKE_PG_DATABASE}"
    )


def get_ducklake_storage_config():
    """Return dlt filesystem storage config for DuckLake's GCS data path."""
    from dlt.common.configuration.specs.gcp_credentials import GcpServiceAccountCredentials
    from dlt.common.storages.configuration import FilesystemConfiguration

    credentials = None
    if GOOGLE_APPLICATION_CREDENTIALS:
        key_path = Path(GOOGLE_APPLICATION_CREDENTIALS)
        if not key_path.is_absolute():
            key_path = PROJECT_ROOT / key_path
        if key_path.exists():
            key_info = json.loads(key_path.read_text())
            credentials = GcpServiceAccountCredentials(
                project_id=key_info.get("project_id"),
                private_key=key_info.get("private_key"),
                private_key_id=key_info.get("private_key_id"),
                client_email=key_info.get("client_email"),
            )

    if credentials is None:
        try:
            from google.auth import default as google_auth_default

            adc_credentials, project_id = google_auth_default()
            credentials = GcpServiceAccountCredentials(project_id=project_id)
            credentials.parse_native_representation(adc_credentials)
        except Exception:
            credentials = None

    return FilesystemConfiguration(bucket_url=DUCKLAKE_GCS_PATH, credentials=credentials)


def require_ducklake_config(*, require_hmac: bool = True) -> None:
    """Raise a clear error if required DuckLake environment variables are missing."""
    required_values = {
        "DUCKLAKE_GCS_BUCKET or DUCKLAKE_GCS_PATH": DUCKLAKE_GCS_PATH,
        "DUCKLAKE_PG_PASSWORD": DUCKLAKE_PG_PASSWORD,
    }
    if require_hmac:
        required_values.update(
            {
                "DUCKLAKE_GCS_HMAC_KEY_ID": DUCKLAKE_GCS_HMAC_KEY_ID,
                "DUCKLAKE_GCS_HMAC_SECRET": DUCKLAKE_GCS_HMAC_SECRET,
            }
        )

    missing = [name for name, value in required_values.items() if not value]
    if missing:
        missing_list = ", ".join(missing)
        raise RuntimeError(f"Missing required DuckLake configuration: {missing_list}")
