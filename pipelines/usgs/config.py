"""Configuration for USGS Water Services pipeline."""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, List, Optional

import yaml

from shared.config import PROJECT_ROOT

DEFAULT_STATIONS_CONFIG_PATH = PROJECT_ROOT / "pipelines" / "deployment_configs" / "usgs_stations.yml"


def load_stations_config(config_path: Path = DEFAULT_STATIONS_CONFIG_PATH) -> dict[str, Any]:
    """Load configured USGS station defaults."""
    if not config_path.exists():
        raise FileNotFoundError(f"USGS stations config does not exist: {config_path}")

    config = yaml.safe_load(config_path.read_text()) or {}
    if not isinstance(config, dict):
        raise ValueError(f"USGS stations config must be a mapping: {config_path}")

    defaults = config.get("defaults", {})
    stations = config.get("stations", [])
    if not isinstance(defaults, dict):
        raise ValueError("USGS stations config defaults must be a mapping")
    if not isinstance(stations, list) or not stations:
        raise ValueError("USGS stations config must define at least one station")

    return config


def _configured_site_codes(config: dict[str, Any]) -> list[str]:
    site_codes = []
    for station in config["stations"]:
        site_code = station.get("site_code") if isinstance(station, dict) else None
        if not site_code:
            raise ValueError("Each USGS station config entry must include site_code")
        site_codes.append(str(site_code))

    return site_codes


def _configured_default_parameter_codes(config: dict[str, Any]) -> list[str]:
    parameter_codes = config.get("defaults", {}).get("parameter_codes", [])
    if not parameter_codes:
        raise ValueError("USGS stations config must define defaults.parameter_codes")

    return [str(parameter_code) for parameter_code in parameter_codes]


def _configured_site_parameter_codes(
    config: dict[str, Any], default_parameter_codes: list[str]
) -> dict[str, list[str]]:
    site_parameter_codes = {}
    for station in config["stations"]:
        site_code = str(station["site_code"])
        parameter_codes = station.get("parameter_codes", default_parameter_codes)
        site_parameter_codes[site_code] = [str(parameter_code) for parameter_code in parameter_codes]

    return site_parameter_codes


@dataclass
class USGSConfig:
    """Configuration for USGS Water Services API."""

    base_url: str = "https://waterservices.usgs.gov/nwis/iv/"
    site_codes: List[str] = None
    parameter_codes: List[str] = None
    format: str = "json"
    history_period: Optional[str] = None
    start_dt: Optional[str] = None
    end_dt: Optional[str] = None
    site_parameter_codes: dict[str, List[str]] = None

    def __post_init__(self):
        """Set default values."""
        stations_config = load_stations_config()
        default_parameter_codes = _configured_default_parameter_codes(stations_config)

        if self.site_codes is None:
            self.site_codes = _configured_site_codes(stations_config)
        if self.parameter_codes is None:
            self.parameter_codes = default_parameter_codes
        if self.history_period is None and not (self.start_dt and self.end_dt):
            self.history_period = stations_config.get("defaults", {}).get("history_period", "P7D")
        if bool(self.start_dt) != bool(self.end_dt):
            raise ValueError("start_dt and end_dt must both be set together")
        if self.site_parameter_codes is None:
            if self.parameter_codes == default_parameter_codes:
                self.site_parameter_codes = _configured_site_parameter_codes(
                    stations_config, default_parameter_codes
                )
            else:
                self.site_parameter_codes = {
                    site_code: self.parameter_codes for site_code in self.site_codes
                }

    def parameter_codes_for_site(self, site_code: str) -> List[str]:
        """Return the configured parameter codes for a site."""
        return self.site_parameter_codes.get(site_code, self.parameter_codes)


# Mapping of USGS parameter codes to readable names
PARAMETER_CODE_NAMES = {
    "00060": "discharge_cfs",  # Discharge, cubic feet per second
    "00065": "gage_height_ft",  # Gage height, feet
    "00010": "water_temp_c",  # Temperature, water, degrees Celsius
}
