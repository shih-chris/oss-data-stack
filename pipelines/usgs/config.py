"""Configuration for USGS Water Services pipeline."""

from dataclasses import dataclass
from typing import List


@dataclass
class USGSConfig:
    """Configuration for USGS Water Services API."""

    base_url: str = "https://waterservices.usgs.gov/nwis/iv/"
    site_codes: List[str] = None
    parameter_codes: List[str] = None
    format: str = "json"

    def __post_init__(self):
        """Set default values."""
        if self.site_codes is None:
            # Default to Youghiogheny River at Friendsville, MD
            self.site_codes = ["03076500"]
        if self.parameter_codes is None:
            # Default to gage height (water level)
            self.parameter_codes = ["00065"]


# Mapping of USGS parameter codes to readable names
PARAMETER_CODE_NAMES = {
    "00060": "discharge_cfs",  # Discharge, cubic feet per second
    "00065": "gage_height_ft",  # Gage height, feet
    "00010": "water_temp_c",  # Temperature, water, degrees Celsius
}
