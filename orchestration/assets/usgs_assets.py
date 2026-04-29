"""Dagster assets for USGS dlt ingestion."""

from dagster import AssetExecutionContext
from dagster_dlt import DagsterDltResource, DagsterDltTranslator, dlt_assets
from dagster_dlt.translator import DltResourceTranslatorData

from orchestration.assets.asset_keys import USGS_RAW_WATER_LEVELS_ASSET_KEY
from pipelines.usgs.config import USGSConfig
from pipelines.usgs.pipeline import build_usgs_pipeline
from pipelines.usgs.sources import usgs_water_data


class UsgsDagsterDltTranslator(DagsterDltTranslator):
    """Map dlt resources to the repo's raw asset key namespace."""

    def get_asset_spec(self, data: DltResourceTranslatorData):
        spec = super().get_asset_spec(data)
        if data.resource.name == "water_levels":
            return spec.replace_attributes(key=USGS_RAW_WATER_LEVELS_ASSET_KEY, deps=[])

        return spec.replace_attributes(key=["raw", "usgs", data.resource.name], deps=[])


USGS_DLT_TRANSLATOR = UsgsDagsterDltTranslator()


@dlt_assets(
    dlt_source=usgs_water_data(config=USGSConfig()),
    dlt_pipeline=build_usgs_pipeline(configure_destination=False),
    name="usgs_water_services",
    group_name="raw_usgs",
    dagster_dlt_translator=USGS_DLT_TRANSLATOR,
)
def usgs_water_assets(context: AssetExecutionContext, dlt: DagsterDltResource):
    """Load USGS water levels into the DuckLake raw schema."""
    yield from dlt.run(
        context=context,
        dlt_pipeline=build_usgs_pipeline(),
        dagster_dlt_translator=USGS_DLT_TRANSLATOR,
    )
