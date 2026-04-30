"""dlt sources for USGS Water Services API."""

from typing import Any, Dict, Iterator

import dlt
import requests

from pipelines.usgs.config import PARAMETER_CODE_NAMES, USGSConfig


@dlt.source
def usgs_water_data(config: USGSConfig = None) -> Iterator[dlt.resource]:
    """
    Source for USGS Water Services API data.

    Args:
        config: Configuration for USGS API requests

    Yields:
        dlt resources for water level data
    """
    if config is None:
        config = USGSConfig()

    yield water_levels(config=config)


@dlt.resource(write_disposition="append")
def water_levels(config: USGSConfig) -> Iterator[Dict[str, Any]]:
    """
    Resource for fetching water level data from USGS.

    Args:
        config: Configuration for USGS API requests

    Yields:
        Normalized water level records
    """
    params = _build_request_params(config)

    response = requests.get(config.base_url, params=params, timeout=30)
    response.raise_for_status()

    data = response.json()

    # Extract time series data
    time_series_list = data.get("value", {}).get("timeSeries", [])

    for series in time_series_list:
        source_info = series.get("sourceInfo", {})
        site_code = source_info.get("siteCode", [{}])[0].get("value")
        site_name = source_info.get("siteName")
        latitude = source_info.get("geoLocation", {}).get("geogLocation", {}).get("latitude")
        longitude = source_info.get("geoLocation", {}).get("geogLocation", {}).get("longitude")

        variable = series.get("variable", {})
        parameter_code = variable.get("variableCode", [{}])[0].get("value")
        parameter_name = PARAMETER_CODE_NAMES.get(parameter_code, parameter_code)
        unit = variable.get("unit", {}).get("unitCode")

        values_list = series.get("values", [{}])[0].get("value", [])

        for value_record in values_list:
            yield {
                "site_code": site_code,
                "site_name": site_name,
                "latitude": latitude,
                "longitude": longitude,
                "parameter_code": parameter_code,
                "parameter_name": parameter_name,
                "timestamp": value_record.get("dateTime"),
                "value": float(value_record.get("value")),
                "unit": unit,
                "qualifiers": value_record.get("qualifiers", []),
            }


def _build_request_params(config: USGSConfig) -> Dict[str, str]:
    """Build USGS API query parameters from the pipeline config."""
    params = {
        "sites": ",".join(config.site_codes),
        "parameterCd": ",".join(config.parameter_codes),
        "format": config.format,
    }

    if config.start_dt and config.end_dt:
        params["startDT"] = config.start_dt
        params["endDT"] = config.end_dt
    elif config.history_period:
        params["period"] = config.history_period

    return params
