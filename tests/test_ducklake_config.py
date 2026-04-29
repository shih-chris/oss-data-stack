"""Tests for DuckLake configuration helpers."""

import importlib


def _reload_config():
    import shared.config as config

    return importlib.reload(config)


def test_ducklake_gcs_path_defaults_from_bucket_and_prefix(monkeypatch):
    monkeypatch.setenv("DUCKLAKE_GCS_PATH", "")
    monkeypatch.setenv("DUCKLAKE_GCS_BUCKET", "example-bucket")
    monkeypatch.setenv("DUCKLAKE_GCS_PREFIX", "lake/prefix")

    config = _reload_config()

    assert config.DUCKLAKE_GCS_PATH == "gs://example-bucket/lake/prefix"


def test_ducklake_catalog_uri_url_encodes_credentials(monkeypatch):
    monkeypatch.setenv("DUCKLAKE_PG_HOST", "127.0.0.1")
    monkeypatch.setenv("DUCKLAKE_PG_PORT", "5432")
    monkeypatch.setenv("DUCKLAKE_PG_DATABASE", "ducklake_catalog")
    monkeypatch.setenv("DUCKLAKE_PG_USER", "user@example")
    monkeypatch.setenv("DUCKLAKE_PG_PASSWORD", "p@ss word")

    config = _reload_config()

    assert config.get_ducklake_catalog_uri() == (
        "postgresql://user%40example:p%40ss%20word@127.0.0.1:5432/ducklake_catalog"
    )


def test_ducklake_catalog_uri_supports_cloud_sql_socket(monkeypatch):
    monkeypatch.setenv("DUCKLAKE_PG_HOST", "/cloudsql/project:region:instance")
    monkeypatch.setenv("DUCKLAKE_PG_PORT", "5432")
    monkeypatch.setenv("DUCKLAKE_PG_DATABASE", "ducklake_catalog")
    monkeypatch.setenv("DUCKLAKE_PG_USER", "postgres")
    monkeypatch.setenv("DUCKLAKE_PG_PASSWORD", "secret")

    config = _reload_config()

    assert config.get_ducklake_catalog_uri() == (
        "postgresql://postgres:secret@/ducklake_catalog?"
        "host=%2Fcloudsql%2Fproject%3Aregion%3Ainstance&port=5432"
    )
