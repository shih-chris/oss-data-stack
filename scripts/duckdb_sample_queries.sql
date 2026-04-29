-- Run this inside the DuckDB CLI after starting it with:
-- bash scripts/duckdb_cli.sh
--
-- DuckDB prompt command:
-- .read scripts/duckdb_sample_queries.sql

SELECT * FROM ducklake_settings(current_database());

SHOW DATABASES;
SHOW SCHEMAS;
SHOW ALL TABLES;

SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema IN ('usgs_water_raw', 'main_staging', 'main_marts')
ORDER BY table_schema, table_name;

-- Raw rows from dlt ingestion. Run `uv run python pipelines/usgs/pipeline.py` first.
SELECT
    site_code,
    site_name,
    parameter_code,
    parameter_name,
    timestamp,
    value,
    unit
FROM usgs_water_raw.water_levels
ORDER BY timestamp DESC
LIMIT 20;

-- Daily mart rows from dbt. Run `uv run dbt build --project-dir transformations --profiles-dir transformations` first.
SELECT
    site_code,
    site_name,
    parameter_name,
    measurement_date,
    min_value,
    avg_value,
    max_value,
    measurement_unit
FROM main_marts.fct_water_levels_daily
ORDER BY measurement_date DESC, site_code, parameter_name
LIMIT 20;

SELECT
    site_code,
    site_name,
    parameter_name,
    COUNT(*) AS days_loaded,
    MIN(measurement_date) AS first_day,
    MAX(measurement_date) AS last_day,
    AVG(avg_value) AS avg_daily_value
FROM main_marts.fct_water_levels_daily
GROUP BY site_code, site_name, parameter_name
ORDER BY site_code, parameter_name;
