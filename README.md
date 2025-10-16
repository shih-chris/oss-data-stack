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
