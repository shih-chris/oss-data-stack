"""Tests for USGS history window request configuration."""

import pytest

from pipelines.usgs.config import USGSConfig
from pipelines.usgs.sources import _build_request_params


def test_default_config_uses_period_window() -> None:
    config = USGSConfig()

    params = _build_request_params(config)

    assert params["period"] == "P7D"
    assert "03076500" in params["sites"]
    assert "01200500" in params["sites"]
    assert params["parameterCd"] == "00065,00060,00010"
    assert "startDT" not in params
    assert "endDT" not in params


def test_explicit_date_range_overrides_period() -> None:
    config = USGSConfig(
        history_period="P30D",
        start_dt="2026-01-01T00:00:00Z",
        end_dt="2026-01-31T23:59:59Z",
    )

    params = _build_request_params(config)

    assert params["startDT"] == "2026-01-01T00:00:00Z"
    assert params["endDT"] == "2026-01-31T23:59:59Z"
    assert "period" not in params


def test_date_range_requires_both_bounds() -> None:
    with pytest.raises(ValueError, match="must both be set together"):
        USGSConfig(start_dt="2026-01-01T00:00:00Z")
