"""Tests for Dagster asset key mappings."""

from orchestration.assets.asset_keys import USGS_RAW_WATER_LEVELS_ASSET_KEY
from orchestration.assets.dbt_assets import OssDataStackDbtTranslator
from orchestration.assets.usgs_assets import usgs_water_assets


def test_dlt_asset_uses_raw_usgs_key() -> None:
    assert USGS_RAW_WATER_LEVELS_ASSET_KEY in usgs_water_assets.keys


def test_dbt_source_maps_to_dlt_asset_key() -> None:
    translator = OssDataStackDbtTranslator()

    asset_key = translator.get_asset_key(
        {
            "resource_type": "source",
            "source_name": "usgs_water_raw",
            "name": "water_levels",
        }
    )

    assert asset_key == USGS_RAW_WATER_LEVELS_ASSET_KEY


def test_dbt_models_use_layered_asset_keys() -> None:
    translator = OssDataStackDbtTranslator()

    staging_key = translator.get_asset_key(
        {
            "resource_type": "model",
            "name": "stg_usgs__water_levels",
            "fqn": ["oss_data_stack", "staging", "usgs", "stg_usgs__water_levels"],
        }
    )
    marts_key = translator.get_asset_key(
        {
            "resource_type": "model",
            "name": "fct_water_levels_daily",
            "fqn": ["oss_data_stack", "marts", "water_metrics", "fct_water_levels_daily"],
        }
    )

    assert staging_key.path == ["staging", "usgs", "stg_usgs__water_levels"]
    assert marts_key.path == ["marts", "water_metrics", "fct_water_levels_daily"]
