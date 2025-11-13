"""DuckDB database connection utilities."""

import duckdb
from shared.config import DUCKDB_PATH


def get_duckdb_connection() -> duckdb.DuckDBPyConnection:
    """
    Get a connection to the DuckDB database.

    Returns:
        DuckDB connection object
    """
    return duckdb.connect(str(DUCKDB_PATH))


def query(sql: str) -> duckdb.DuckDBPyRelation:
    """
    Execute a SQL query against the DuckDB database.

    Args:
        sql: SQL query string

    Returns:
        Query results as a DuckDB relation
    """
    conn = get_duckdb_connection()
    return conn.execute(sql)
