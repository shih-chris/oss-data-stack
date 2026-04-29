"""Schedule for the USGS ingestion and transformation job."""

from dagster import DefaultScheduleStatus, ScheduleDefinition

from orchestration.jobs.ingestion_job import usgs_pipeline_job

daily_usgs_schedule = ScheduleDefinition(
    name="daily_usgs_schedule",
    job=usgs_pipeline_job,
    cron_schedule="*/15 * * * *",
    execution_timezone="UTC",
    default_status=DefaultScheduleStatus.RUNNING,
)
