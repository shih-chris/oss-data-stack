"""Smoke tests for Dagster definitions."""

from dagster import AssetKey

from orchestration.definitions import defs


def test_definitions_load_expected_assets() -> None:
    asset_keys = set(defs.resolve_all_asset_keys())

    assert asset_keys == {
        AssetKey(["raw", "usgs", "water_levels"]),
        AssetKey(["staging", "usgs", "stg_usgs__water_levels"]),
        AssetKey(["marts", "water_metrics", "fct_water_levels_daily"]),
    }


def test_definitions_load_expected_job_and_schedule() -> None:
    assert defs.resolve_job_def("usgs_pipeline_job").name == "usgs_pipeline_job"

    schedule = defs.resolve_schedule_def("daily_usgs_schedule")
    assert schedule.cron_schedule == "0 6 * * *"
    assert schedule.execution_timezone == "UTC"
