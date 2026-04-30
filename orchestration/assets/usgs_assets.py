"""Dagster assets for USGS dlt ingestion."""

from dagster import AssetExecutionContext, Config
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


class UsgsDagsterConfig(Config):
    """Run configuration for the USGS dlt asset."""

    site_codes: list[str] | None = None
    parameter_codes: list[str] | None = None
    history_period: str = "P7D"
    start_dt: str | None = None
    end_dt: str | None = None


@dlt_assets(
    dlt_source=usgs_water_data(config=USGSConfig()),
    dlt_pipeline=build_usgs_pipeline(configure_destination=False),
    name="usgs_water_services",
    group_name="raw_usgs",
    dagster_dlt_translator=USGS_DLT_TRANSLATOR,
)
def usgs_water_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: UsgsDagsterConfig,
):
    """Load USGS water levels into the DuckLake raw schema."""
    usgs_config = USGSConfig(
        site_codes=config.site_codes,
        parameter_codes=config.parameter_codes,
        history_period=config.history_period,
        start_dt=config.start_dt,
        end_dt=config.end_dt,
    )

    yield from dlt.run(
        context=context,
        dlt_source=usgs_water_data(config=usgs_config),
        dlt_pipeline=build_usgs_pipeline(),
        dagster_dlt_translator=USGS_DLT_TRANSLATOR,
    )
