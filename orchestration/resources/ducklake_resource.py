"""Dagster resource for ad-hoc DuckLake queries."""

from collections.abc import Iterator
from contextlib import contextmanager

import duckdb
from dagster import ConfigurableResource

from shared.database import get_ducklake_connection


class DuckLakeResource(ConfigurableResource):
    """Create in-memory DuckDB connections attached to the shared DuckLake."""

    @contextmanager
    def get_connection(self) -> Iterator[duckdb.DuckDBPyConnection]:
        conn = get_ducklake_connection()
        try:
            yield conn
        finally:
            conn.close()


ducklake_resource = DuckLakeResource()
