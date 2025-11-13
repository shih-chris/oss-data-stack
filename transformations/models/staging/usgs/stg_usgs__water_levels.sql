{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('usgs_water_raw', 'water_levels') }}
),

renamed as (
    select
        -- Identifiers
        site_code,
        site_name,

        -- Geography
        latitude as site_latitude,
        longitude as site_longitude,

        -- Measurement
        parameter_code,
        parameter_name,
        timestamp as measurement_timestamp,
        value as measurement_value,
        unit as measurement_unit,

        -- Metadata
        _dlt_load_id as dlt_load_id,
        _dlt_id as dlt_id

    from source
)

select * from renamed
