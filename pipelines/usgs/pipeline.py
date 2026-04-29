"""USGS Water Services dlt pipeline."""

import dlt
from dlt.destinations.impl.ducklake.configuration import DuckLakeCredentials

from pipelines.usgs.config import USGSConfig
from pipelines.usgs.sources import usgs_water_data
from shared.config import (
    DUCKLAKE_CATALOG_NAME,
    DUCKLAKE_METADATA_SCHEMA,
    get_ducklake_catalog_uri,
    get_ducklake_storage_config,
    require_ducklake_config,
)


def _ducklake_destination():
    require_ducklake_config(require_hmac=False)

    credentials_kwargs = {
        "ducklake_name": DUCKLAKE_CATALOG_NAME,
        "catalog": get_ducklake_catalog_uri(),
        "storage": get_ducklake_storage_config(),
    }
    if "metadata_schema" in DuckLakeCredentials.__dataclass_fields__:
        credentials_kwargs["metadata_schema"] = DUCKLAKE_METADATA_SCHEMA
    elif DUCKLAKE_METADATA_SCHEMA != DUCKLAKE_CATALOG_NAME:
        raise RuntimeError(
            "This dlt version uses ducklake_name as the Postgres metadata schema. "
            "Set DUCKLAKE_METADATA_SCHEMA to the same value as DUCKLAKE_CATALOG_NAME."
        )

    return dlt.destinations.ducklake(credentials=DuckLakeCredentials(**credentials_kwargs))


def run_usgs_pipeline(
    site_codes: list[str] = None,
    parameter_codes: list[str] = None,
    destination: str = "ducklake",
    dataset_name: str = "usgs_water_raw",
) -> dlt.Pipeline:
    """
    Run the USGS water data ingestion pipeline.

    Args:
        site_codes: List of USGS site codes to fetch data for
        parameter_codes: List of parameter codes (e.g., "00065" for gage height)
        destination: dlt destination (default: "ducklake")
        dataset_name: Name of the dataset/schema in the destination

    Returns:
        dlt Pipeline object with run information
    """
    # Create configuration
    config = USGSConfig(
        site_codes=site_codes,
        parameter_codes=parameter_codes,
    )

    if destination != "ducklake":
        raise ValueError("This project is configured for the DuckLake destination only.")

    # Create dlt pipeline backed by DuckLake metadata in Cloud SQL and files in GCS.
    pipeline = dlt.pipeline(
        pipeline_name="usgs_water_services",
        destination=_ducklake_destination(),
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
