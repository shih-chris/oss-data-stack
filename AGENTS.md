# Project Overview

## Project Purpose
Provides an example of an Open Source Data Stack - primarily as a way to try out new tools and technologies! DuckDB runs locally as the query engine while DuckLake stores persistent data in GCP.

## Overall Data Stack Architecture
Overall data stack architecture:
- **Data Lake**: DuckLake (Cloud SQL PostgreSQL catalog + GCS object storage)
- **Compute**: DuckDB
- **Ingestion**: dlt
- **Transformation**: dbt-core
- **Orchestration**: Dagster
- **Package Manager**: uv
- **Observability**: Grafana
- **Data Viz**: Grafana
- **AI & Agents**: tbd

### Data Flow
```
USGS API → dlt → DuckLake raw schemas → dbt → DuckLake marts
            ↑                                  ↑
            └──────── Dagster orchestrates ────┘
```

## Project Folder Structure
```
oss-data-stack/
├── pyproject.toml              # uv project config with all dependencies
├── uv.lock                     # uv lockfile
├── .python-version             # Python version for uv
├── README.md
├── AGENTS.md
├── .gitignore
│
├── pipelines/                  # dlt ingestion pipelines
│   ├── __init__.py
│   ├── usgs/                   # USGS Water Services pipeline
│   │   ├── __init__.py
│   │   ├── pipeline.py         # Main dlt pipeline definition
│   │   ├── sources.py          # dlt source/resource definitions
│   │   ├── config.py           # Pipeline configuration
│   │   └── schemas/            # dlt schemas (auto-generated)
│   │
│   └── shared/                 # Shared utilities for all pipelines
│       ├── __init__.py
│       └── utils.py
│
├── transformations/            # dbt project
│   ├── dbt_project.yml         # dbt project config
│   ├── profiles.yml            # dbt profiles (DuckLake attach via DuckDB)
│   ├── models/                 # dbt models
│   │   ├── staging/            # Staging models (raw → cleaned)
│   │   │   └── usgs/
│   │   │       ├── _usgs__sources.yml
│   │   │       ├── _usgs__models.yml
│   │   │       └── stg_usgs__water_levels.sql
│   │   │
│   │   └── marts/              # Business logic models
│   │       └── water_metrics/
│   │           └── fct_water_levels_daily.sql
│   │
│   ├── macros/                 # Reusable SQL macros
│   ├── tests/                  # dbt data tests
│   ├── seeds/                  # Static CSV data
│   └── snapshots/              # Slowly changing dimensions
│
├── orchestration/              # Dagster project
│   ├── __init__.py
│   ├── definitions.py          # Main Dagster definitions (Definitions object)
│   ├── assets/                 # Dagster assets
│   │   ├── __init__.py
│   │   ├── usgs_assets.py      # dlt ingestion assets
│   │   └── dbt_assets.py       # dbt transformation assets
│   │
│   ├── resources/              # Dagster resources
│   │   ├── __init__.py
│   │   ├── dlt_resource.py     # dlt resource configuration
│   │   ├── dbt_resource.py     # dbt CLI resource configuration
│   │   └── ducklake_resource.py # DuckDB connection resource for DuckLake
│   │
│   ├── sensors/                # Dagster sensors (optional)
│   ├── schedules/              # Dagster schedules
│   │   └── daily_ingestion.py
│   │
│   └── jobs/                   # Dagster jobs (optional)
│
├── shared/                     # Shared utilities across layers
│   ├── __init__.py
│   ├── config.py              # Global configuration
│   └── database.py            # DuckDB connection utilities
│
├── tests/                     # Python test suite
│   ├── pipelines/
│   └── orchestration/
│
├── scripts/                   # Development/ops scripts
│   ├── setup_gcp.sh          # GCP DuckLake infrastructure setup
│   ├── start_cloud_sql_proxy.sh
│   └── init_ducklake.py      # DuckLake catalog initialization
│
└── config/                   # Configuration files
    ├── dlt/                 # dlt configs
    │   └── config.toml
    └── .env                 # Environment variables (gitignored)
```

# Build and test commands
- Install/sync dependencies: `uv sync --extra dev`
- Run Python tests: `uv run pytest`
- Run linting: `uv run ruff check .`
- Run the USGS dlt pipeline directly: `uv run python pipelines/usgs/pipeline.py`
- Run dbt transformations and tests directly: `uv run dbt build --project-dir transformations --profiles-dir transformations`
- Run Dagster locally: `DAGSTER_HOME=$PWD/storage/dagster_home uv run dagster dev`

DuckLake workloads require `scripts/start_cloud_sql_proxy.sh` running locally before dlt, dbt, Dagster materializations, or ad-hoc DuckDB queries.

# Decision Log
tbd
