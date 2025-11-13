# Example OSS Data Stack

## Purpose
Provides an example of an Open Source Data Stack - primarily as a way to try out new tools and technologies! As a result, we'll likely run everything locally and iterate quickly.

## Architecture
Overall data stack architecture
- Data Lake: DuckLake (likely using DuckDB for catalog db)
- Compute: DuckDB (or maybe Trino)
- Ingestion: dlt
- Transformation: SQLMesh
- Orchestration: Prefect (or maybe Dagster)
- Observability: Grafana
- Data Viz: Grafana
- AI & Agents: tbd

# Example Use Case
Over the past decade (or so) I've been really into whitewater kayaking - spending the majority of my free weekends itching to find a way to get on the water...some, including my partner, would call it an obsession.

During the spring/fall months, the limitation is generally a simple matter of finding free time - there are typically a number of dams that have scehduled releases of water. In summer and winter months, however, river levels are much more dependent on rain and as such, whitewater kayakers can often be found doing rain dances or turning into amateur meterologists.

This example use case is a bit of a side project for me to start capturing river level data (and ideally rainfall data) as a way to test out this data stack.

## The Upper Yough
This river holds a special place in my heart - it was my first "step up" run into intermediate/advanced boating and holds lots of great memories.

[ TODO: insert image here ]

It turns out The NOAA Weather API (https://api.weather.gov/) doesn't provide water level data like I originally expected. Instead, the gauge at https://water.noaa.gov/gauges/03076500 actually sources its data from USGS site #03076500, so we'll need to use the USGS Water Services API.

Gauge Information:
- USGS Site: 03076500
- Location: Youghiogheny River at Friendsville, MD
- NOAA Gauge ID: FRDM2

API Endpoint:
- https://waterservices.usgs.gov/nwis/iv/?sites=03076500&parameterCd=00065&format=json

Key Parameters:
- sites=03076500 - Your specific gauge
- parameterCd=00065 - Gage height (water level in feet)
- format=json - Response format (can also use rdb, xml)

Additional useful parameter codes:
- 00060 - Discharge (cubic feet per second)
- 00010 - Water temperature

Time Range Options:
- No time params = latest reading only
- period=P7D - Last 7 days
- startDT=2025-01-01&endDT=2025-01-31 - Specific date range
