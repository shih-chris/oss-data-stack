"""Asset jobs for the USGS pipeline."""

from dagster import AssetSelection, define_asset_job, in_process_executor

usgs_pipeline_job = define_asset_job(
    name="usgs_pipeline_job",
    selection=AssetSelection.groups("raw_usgs", "staging_usgs", "marts_water_metrics"),
    executor_def=in_process_executor,
)
