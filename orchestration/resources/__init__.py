"""Dagster resources for the orchestration project."""

from orchestration.resources.dbt_resource import dbt_resource
from orchestration.resources.dlt_resource import dlt_resource
from orchestration.resources.ducklake_resource import ducklake_resource

resources = {
    "dbt": dbt_resource,
    "dlt": dlt_resource,
    "ducklake": ducklake_resource,
}
