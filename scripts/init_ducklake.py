"""Initialize and verify the configured DuckLake catalog."""

import argparse

from shared.config import DUCKLAKE_CATALOG_NAME, DUCKLAKE_GCS_PATH, DUCKLAKE_METADATA_SCHEMA
from shared.database import get_ducklake_connection


def main() -> None:
    parser = argparse.ArgumentParser(description="Initialize the configured DuckLake catalog.")
    parser.add_argument(
        "--verify-write",
        action="store_true",
        help="Create and drop a tiny table to verify GCS writes as well as catalog access.",
    )
    args = parser.parse_args()

    conn = get_ducklake_connection()
    settings = conn.execute(f"SELECT * FROM ducklake_settings('{DUCKLAKE_CATALOG_NAME}')").fetchall()

    print(f"Attached DuckLake catalog: {DUCKLAKE_CATALOG_NAME}")
    print(f"Metadata schema: {DUCKLAKE_METADATA_SCHEMA}")
    print(f"Data path: {DUCKLAKE_GCS_PATH}")
    print(f"Settings: {settings}")

    if args.verify_write:
        conn.execute("CREATE OR REPLACE TABLE __ducklake_init_smoke_test AS SELECT 1 AS ok")
        result = conn.execute("SELECT ok FROM __ducklake_init_smoke_test").fetchone()
        conn.execute("DROP TABLE __ducklake_init_smoke_test")
        print(f"Write verification result: {result[0]}")


if __name__ == "__main__":
    main()
