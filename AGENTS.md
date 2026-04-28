# Project Overview

## Project Purpose
Provides an example of an Open Source Data Stack - primarily as a way to try out new tools and technologies! As a result, we'll likely run everything locally and iterate quickly.

## Overall Data Stack Architecture
Overall data stack architecture:
- **Data Lake**: DuckLake (using DuckDB for catalog db)
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
USGS API → dlt → DuckDB (raw) → dbt → DuckDB (marts)
            ↑                              ↑
            └──── Dagster orchestrates ────┘
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
│   ├── profiles.yml            # dbt profiles (DuckDB connection)
│   ├── models/                 # dbt models
│   │   ├── staging/            # Staging models (raw → cleaned)
│   │   │   └── usgs/
│   │   │       ├── _usgs__sources.yml
│   │   │       ├── _usgs__models.yml
│   │   │       └── stg_usgs__water_levels.sql
│   │   │
│   │   └── marts/              # Business logic models
│   │       └── water_metrics/
│   │           └── water_levels_daily.sql
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
│   │   └── duckdb_resource.py  # DuckDB I/O manager
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
│   ├── setup.sh              # Initial setup script
│   └── dev_utils.py          # Dev utilities
│
└── config/                   # Configuration files
    ├── dlt/                 # dlt configs
    │   └── config.toml
    └── .env                 # Environment variables (gitignored)
```

# Build and test commands
tbd

# Decision Log
tbd
