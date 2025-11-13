"""USGS Water Services dlt pipeline."""

import dlt

from pipelines.usgs.config import USGSConfig
from pipelines.usgs.sources import usgs_water_data
from shared.config import DUCKDB_PATH


def run_usgs_pipeline(
    site_codes: list[str] = None,
    parameter_codes: list[str] = None,
    destination: str = "duckdb",
    dataset_name: str = "usgs_water_raw",
) -> dlt.Pipeline:
    """
    Run the USGS water data ingestion pipeline.

    Args:
        site_codes: List of USGS site codes to fetch data for
        parameter_codes: List of parameter codes (e.g., "00065" for gage height)
        destination: dlt destination (default: "duckdb")
        dataset_name: Name of the dataset/schema in the destination

    Returns:
        dlt Pipeline object with run information
    """
    # Create configuration
    config = USGSConfig(
        site_codes=site_codes,
        parameter_codes=parameter_codes,
    )

    # Create dlt pipeline with explicit DuckDB path
    pipeline = dlt.pipeline(
        pipeline_name="usgs_water_services",
        destination=dlt.destinations.duckdb(str(DUCKDB_PATH)),
        dataset_name=dataset_name,
    )

    # Run the pipeline
    load_info = pipeline.run(usgs_water_data(config=config))

    # Print summary
    print(f"Pipeline run completed: {load_info}")
    print(f"Loaded {len(load_info.loads_ids)} load package(s)")

    return pipeline


if __name__ == "__main__":
    # Run the pipeline directly for testing
    run_usgs_pipeline()
