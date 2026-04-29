"""DuckDB connection utilities for the GCP-backed DuckLake."""

import re

import duckdb

from shared.config import (
    DUCKLAKE_CATALOG_NAME,
    DUCKLAKE_GCS_HMAC_KEY_ID,
    DUCKLAKE_GCS_HMAC_SECRET,
    DUCKLAKE_GCS_PATH,
    DUCKLAKE_GCS_SECRET_NAME,
    DUCKLAKE_METADATA_SCHEMA,
    DUCKLAKE_PG_DATABASE,
    DUCKLAKE_PG_HOST,
    DUCKLAKE_PG_PASSWORD,
    DUCKLAKE_PG_PORT,
    DUCKLAKE_PG_USER,
    DUCKLAKE_POSTGRES_SECRET_NAME,
    DUCKLAKE_SECRET_NAME,
    require_ducklake_config,
)

_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _identifier(value: str) -> str:
    if not _IDENTIFIER_RE.match(value):
        raise ValueError(f"Invalid DuckDB identifier: {value}")
    return value


def _install_and_load_extensions(conn: duckdb.DuckDBPyConnection) -> None:
    for extension in ("httpfs", "postgres", "ducklake"):
        conn.execute(f"INSTALL {extension}")
        conn.execute(f"LOAD {extension}")


def _configure_secrets(conn: duckdb.DuckDBPyConnection) -> None:
    gcs_secret_name = _identifier(DUCKLAKE_GCS_SECRET_NAME)
    postgres_secret_name = _identifier(DUCKLAKE_POSTGRES_SECRET_NAME)
    ducklake_secret_name = _identifier(DUCKLAKE_SECRET_NAME)

    conn.execute(
        f"""
        CREATE OR REPLACE SECRET {gcs_secret_name} (
            TYPE gcs,
            KEY_ID {_sql_literal(DUCKLAKE_GCS_HMAC_KEY_ID)},
            SECRET {_sql_literal(DUCKLAKE_GCS_HMAC_SECRET)},
            SCOPE {_sql_literal(DUCKLAKE_GCS_PATH)}
        )
        """
    )
    conn.execute(
        f"""
        CREATE OR REPLACE SECRET {postgres_secret_name} (
            TYPE postgres,
            HOST {_sql_literal(DUCKLAKE_PG_HOST)},
            PORT {int(DUCKLAKE_PG_PORT)},
            DATABASE {_sql_literal(DUCKLAKE_PG_DATABASE)},
            USER {_sql_literal(DUCKLAKE_PG_USER)},
            PASSWORD {_sql_literal(DUCKLAKE_PG_PASSWORD)}
        )
        """
    )
    conn.execute(
        f"""
        CREATE OR REPLACE SECRET {ducklake_secret_name} (
            TYPE ducklake,
            METADATA_PATH '',
            DATA_PATH {_sql_literal(DUCKLAKE_GCS_PATH)},
            METADATA_SCHEMA {_sql_literal(DUCKLAKE_METADATA_SCHEMA)},
            METADATA_PARAMETERS MAP {{'TYPE': 'postgres', 'SECRET': {_sql_literal(postgres_secret_name)}}}
        )
        """
    )


def get_ducklake_connection() -> duckdb.DuckDBPyConnection:
    """
    Get an in-memory DuckDB connection attached to the shared DuckLake.

    DuckDB remains the query engine. Persistent table metadata lives in Cloud SQL
    Postgres and persistent table files live in GCS.
    """
    require_ducklake_config(require_hmac=True)

    catalog_name = _identifier(DUCKLAKE_CATALOG_NAME)
    ducklake_secret_name = _identifier(DUCKLAKE_SECRET_NAME)

    conn = duckdb.connect(":memory:")
    _install_and_load_extensions(conn)
    _configure_secrets(conn)
    conn.execute(f"ATTACH IF NOT EXISTS 'ducklake:{ducklake_secret_name}' AS {catalog_name}")
    conn.execute(f"USE {catalog_name}")
    return conn


def get_duckdb_connection() -> duckdb.DuckDBPyConnection:
    """Backward-compatible alias for callers expecting a DuckDB connection."""
    return get_ducklake_connection()


def query(sql: str) -> duckdb.DuckDBPyRelation:
    """
    Execute a SQL query against DuckLake through DuckDB.

    Args:
        sql: SQL query string

    Returns:
        Query results as a DuckDB relation
    """
    conn = get_ducklake_connection()
    return conn.execute(sql)
