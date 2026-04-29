"""Dagster assets for the dbt transformation project."""

from typing import Any, Mapping

from dagster import AssetExecutionContext, AssetKey
from dagster_dbt import DagsterDbtTranslator, DbtCliResource, dbt_assets

from orchestration.assets.asset_keys import USGS_RAW_WATER_LEVELS_ASSET_KEY
from orchestration.resources.dbt_resource import DBT_PROJECT


class OssDataStackDbtTranslator(DagsterDbtTranslator):
    """Map dbt models and sources into stable Dagster asset namespaces."""

    def get_asset_key(self, dbt_resource_props: Mapping[str, Any]) -> AssetKey:
        resource_type = dbt_resource_props["resource_type"]
        if (
            resource_type == "source"
            and dbt_resource_props.get("source_name") == "usgs_water_raw"
            and dbt_resource_props.get("name") == "water_levels"
        ):
            return USGS_RAW_WATER_LEVELS_ASSET_KEY

        if resource_type == "model":
            fqn = dbt_resource_props.get("fqn", [])
            name = dbt_resource_props["name"]
            if len(fqn) >= 3 and fqn[1:3] == ["staging", "usgs"]:
                return AssetKey(["staging", "usgs", name])
            if len(fqn) >= 3 and fqn[1:3] == ["marts", "water_metrics"]:
                return AssetKey(["marts", "water_metrics", name])

        return super().get_asset_key(dbt_resource_props)

    def get_group_name(self, dbt_resource_props: Mapping[str, Any]) -> str | None:
        if dbt_resource_props["resource_type"] == "model":
            fqn = dbt_resource_props.get("fqn", [])
            if len(fqn) >= 3 and fqn[1:3] == ["staging", "usgs"]:
                return "staging_usgs"
            if len(fqn) >= 3 and fqn[1:3] == ["marts", "water_metrics"]:
                return "marts_water_metrics"

        return super().get_group_name(dbt_resource_props)


DBT_TRANSLATOR = OssDataStackDbtTranslator()


@dbt_assets(
    manifest=DBT_PROJECT.manifest_path,
    project=DBT_PROJECT,
    dagster_dbt_translator=DBT_TRANSLATOR,
)
def dbt_project_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    """Build dbt models and run dbt tests."""
    yield from dbt.cli(["build"], context=context).stream()
