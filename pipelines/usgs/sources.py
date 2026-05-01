"""dlt sources for USGS Water Services API."""

import logging
from typing import Any, Dict, Iterator

import dlt
import requests

from pipelines.usgs.config import PARAMETER_CODE_NAMES, USGSConfig

logger = logging.getLogger(__name__)


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
    for site_code in config.site_codes:
        site_config = USGSConfig(
            base_url=config.base_url,
            site_codes=[site_code],
            parameter_codes=config.parameter_codes_for_site(site_code),
            format=config.format,
            history_period=config.history_period,
            start_dt=config.start_dt,
            end_dt=config.end_dt,
        )
        params = _build_request_params(site_config)

        try:
            response = requests.get(site_config.base_url, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as exc:
            logger.warning("Skipping USGS site %s after request failure: %s", site_code, exc)
            continue
        except ValueError as exc:
            logger.warning("Skipping USGS site %s after JSON parse failure: %s", site_code, exc)
            continue

        # Extract time series data
        time_series_list = data.get("value", {}).get("timeSeries", [])

        for series in time_series_list:
            source_info = series.get("sourceInfo", {})
            response_site_code = source_info.get("siteCode", [{}])[0].get("value")
            site_name = source_info.get("siteName")
            latitude = source_info.get("geoLocation", {}).get("geogLocation", {}).get("latitude")
            longitude = source_info.get("geoLocation", {}).get("geogLocation", {}).get("longitude")

            variable = series.get("variable", {})
            parameter_code = variable.get("variableCode", [{}])[0].get("value")
            parameter_name = PARAMETER_CODE_NAMES.get(parameter_code, parameter_code)
            unit = variable.get("unit", {}).get("unitCode")

            values_list = series.get("values", [{}])[0].get("value", [])

            for value_record in values_list:
                measurement_timestamp = value_record.get("dateTime")
                if not response_site_code or not parameter_code or not measurement_timestamp:
                    logger.warning(
                        "Skipping USGS measurement missing merge key fields for requested site %s",
                        site_code,
                    )
                    continue

                try:
                    measurement_value = float(value_record.get("value"))
                except (TypeError, ValueError):
                    logger.warning(
                        "Skipping malformed USGS measurement for site %s, parameter %s",
                        response_site_code,
                        parameter_code,
                    )
                    continue

                yield {
                    "site_code": response_site_code,
                    "site_name": site_name,
                    "latitude": latitude,
                    "longitude": longitude,
                    "parameter_code": parameter_code,
                    "parameter_name": parameter_name,
                    "timestamp": measurement_timestamp,
                    "value": measurement_value,
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
