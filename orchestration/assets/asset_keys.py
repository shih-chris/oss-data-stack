"""Shared Dagster asset keys."""

from dagster import AssetKey

USGS_RAW_WATER_LEVELS_ASSET_KEY = AssetKey(["raw", "usgs", "water_levels"])
