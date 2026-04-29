"""Dagster definitions for the OSS data stack."""

from dagster import Definitions

from orchestration.assets import assets
from orchestration.jobs import jobs
from orchestration.resources import resources
from orchestration.schedules import schedules

defs = Definitions(
    assets=assets,
    jobs=jobs,
    resources=resources,
    schedules=schedules,
)
