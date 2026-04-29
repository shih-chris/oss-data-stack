"""Dagster schedules."""

from orchestration.schedules.daily_ingestion import daily_usgs_schedule

schedules = [daily_usgs_schedule]
