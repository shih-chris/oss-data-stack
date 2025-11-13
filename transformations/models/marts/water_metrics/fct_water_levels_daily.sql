{{
    config(
        materialized='table'
    )
}}

with water_levels as (
    select * from {{ ref('stg_usgs__water_levels') }}
),

daily_stats as (
    select
        site_code,
        site_name,
        parameter_name,
        date_trunc('day', measurement_timestamp) as measurement_date,

        -- Daily aggregations
        min(measurement_value) as min_value,
        max(measurement_value) as max_value,
        avg(measurement_value) as avg_value,
        count(*) as measurement_count,

        -- First and last values of the day
        first(measurement_value order by measurement_timestamp) as first_value,
        last(measurement_value order by measurement_timestamp) as last_value,

        -- Metadata
        any_value(measurement_unit) as measurement_unit,
        any_value(site_latitude) as site_latitude,
        any_value(site_longitude) as site_longitude,

        min(measurement_timestamp) as first_measurement_time,
        max(measurement_timestamp) as last_measurement_time

    from water_levels
    group by
        site_code,
        site_name,
        parameter_name,
        date_trunc('day', measurement_timestamp)
)

select * from daily_stats
order by measurement_date desc, site_code, parameter_name
