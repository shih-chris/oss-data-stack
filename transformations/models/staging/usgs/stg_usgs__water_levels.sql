{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('usgs_water_raw', 'water_levels') }}
),

deduplicated as (
    select *
    from source
    qualify row_number() over (
        partition by site_code, parameter_code, timestamp
        order by _dlt_load_id desc, _dlt_id desc
    ) = 1
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

    from deduplicated
)

select * from renamed
