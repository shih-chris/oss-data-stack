"""Dagster asset definitions."""

from orchestration.assets.dbt_assets import dbt_project_assets
from orchestration.assets.usgs_assets import usgs_water_assets

assets = [usgs_water_assets, dbt_project_assets]
