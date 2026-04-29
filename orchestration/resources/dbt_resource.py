"""Dagster dbt resource configuration."""

from dagster_dbt import DbtCliResource, DbtProject

from shared.config import PROJECT_ROOT

DBT_PROJECT_DIR = PROJECT_ROOT / "transformations"
DBT_PROJECT = DbtProject(project_dir=DBT_PROJECT_DIR, profiles_dir=DBT_PROJECT_DIR)
DBT_PROJECT.prepare_if_dev()

dbt_resource = DbtCliResource(project_dir=DBT_PROJECT)
