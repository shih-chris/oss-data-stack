"""Configuration for USGS Water Services pipeline."""

from dataclasses import dataclass
from typing import List, Optional


@dataclass
class USGSConfig:
    """Configuration for USGS Water Services API."""

    base_url: str = "https://waterservices.usgs.gov/nwis/iv/"
    site_codes: List[str] = None
    parameter_codes: List[str] = None
    format: str = "json"
    history_period: Optional[str] = "P7D"
    start_dt: Optional[str] = None
    end_dt: Optional[str] = None

    def __post_init__(self):
        """Set default values."""
        if self.site_codes is None:
            # Default to Youghiogheny River at Friendsville, MD
            self.site_codes = ["03076500"]
        if self.parameter_codes is None:
            # Default to gage height (water level)
            self.parameter_codes = ["00065"]
        if bool(self.start_dt) != bool(self.end_dt):
            raise ValueError("start_dt and end_dt must both be set together")


# Mapping of USGS parameter codes to readable names
PARAMETER_CODE_NAMES = {
    "00060": "discharge_cfs",  # Discharge, cubic feet per second
    "00065": "gage_height_ft",  # Gage height, feet
    "00010": "water_temp_c",  # Temperature, water, degrees Celsius
}
