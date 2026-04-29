#!/usr/bin/env python3
"""Test script to verify end-to-end pipeline functionality."""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from pipelines.usgs.pipeline import run_usgs_pipeline  # noqa: E402
from shared.database import get_ducklake_connection  # noqa: E402


def run_dlt_ingestion():
    """Test dlt pipeline ingestion."""
    print("=" * 80)
    print("Testing dlt ingestion...")
    print("=" * 80)

    pipeline = run_usgs_pipeline()
    print(f"✓ Pipeline completed: {pipeline.pipeline_name}")
    return True


def run_dbt_transformations():
    """Test dbt transformations."""
    print("\n" + "=" * 80)
    print("Testing dbt transformations...")
    print("=" * 80)

    import subprocess

    result = subprocess.run(
        ["uv", "run", "dbt", "run", "--project-dir", "transformations", "--profiles-dir", "transformations"],
        capture_output=True,
        text=True,
        cwd=project_root
    )

    if result.returncode != 0:
        print("✗ dbt run failed:")
        print(f"STDOUT:\n{result.stdout}")
        print(f"STDERR:\n{result.stderr}")
        return False

    print("✓ dbt models built successfully")
    return True


def run_data_quality():
    """Test data quality and query results."""
    print("\n" + "=" * 80)
    print("Testing data quality...")
    print("=" * 80)

    conn = get_ducklake_connection()

    # Test raw data
    raw_count = conn.execute(
        "SELECT COUNT(*) FROM usgs_water_raw.water_levels"
    ).fetchone()[0]
    print(f"✓ Raw data: {raw_count} records")

    # Test staging view
    staging_count = conn.execute(
        "SELECT COUNT(*) FROM main_staging.stg_usgs__water_levels"
    ).fetchone()[0]
    print(f"✓ Staging view: {staging_count} records")

    # Test daily fact table
    fact_count = conn.execute(
        "SELECT COUNT(*) FROM main_marts.fct_water_levels_daily"
    ).fetchone()[0]
    print(f"✓ Daily facts: {fact_count} records")

    # Show latest reading
    latest = conn.execute("""
        SELECT
            site_name,
            measurement_date,
            avg_value,
            measurement_unit,
            measurement_count
        FROM main_marts.fct_water_levels_daily
        ORDER BY measurement_date DESC
        LIMIT 1
    """).fetchone()

    if latest:
        site, date, value, unit, count = latest
        print("\n📊 Latest Reading:")
        print(f"   Site: {site}")
        print(f"   Date: {date}")
        print(f"   Avg Level: {value} {unit}")
        print(f"   Measurements: {count}")

    return raw_count > 0 and staging_count > 0 and fact_count > 0


def main():
    """Run all tests."""
    print("\n🚀 Starting end-to-end pipeline test...\n")

    tests = [
        ("dlt ingestion", run_dlt_ingestion),
        ("dbt transformations", run_dbt_transformations),
        ("data quality", run_data_quality),
    ]

    results = []
    for name, test_func in tests:
        try:
            success = test_func()
            results.append((name, success))
        except Exception as e:
            print(f"\n✗ Test '{name}' failed with error: {e}")
            results.append((name, False))

    # Summary
    print("\n" + "=" * 80)
    print("TEST SUMMARY")
    print("=" * 80)

    for name, success in results:
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"{status}: {name}")

    all_passed = all(success for _, success in results)

    if all_passed:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print("\n❌ Some tests failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
