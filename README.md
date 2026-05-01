# Example OSS Data Stack

## Purpose
Provides an example of an Open Source Data Stack - primarily as a way to try out new tools and technologies. DuckDB runs locally as the query engine while DuckLake persists metadata and data files in GCP.

## Architecture
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

DuckLake metadata: Cloud SQL PostgreSQL
DuckLake data files: GCS Parquet objects
DuckDB role: local/in-memory query engine
```

## DuckLake on GCP

This project uses DuckLake as the persistent storage layer. DuckDB still executes queries locally, but persistent catalog metadata is stored in Cloud SQL PostgreSQL and persistent table files are stored in GCS.

### Setup

1. Set `GCP_PROJECT_ID` in your shell.
2. Run `WRITE_ENV_FILE=1 scripts/setup_gcp.sh` to provision the GCS bucket, service account, HMAC key, Cloud SQL instance, and `.env` file.
3. Run `scripts/start_cloud_sql_proxy.sh` in a separate terminal before workloads that access DuckLake.
4. Run `uv run python scripts/init_ducklake.py` to initialize the DuckLake catalog.
5. Run `uv run python pipelines/usgs/pipeline.py` to ingest USGS data (defaults to the stations and rolling history window in `pipelines/deployment_configs/usgs_stations.yml`).
6. Run `uv run dbt build --project-dir transformations --profiles-dir transformations` to build and test dbt models.

### DuckDB CLI

Keep `scripts/start_cloud_sql_proxy.sh` running, then start an interactive DuckDB CLI session attached to DuckLake:

```bash
bash scripts/duckdb_cli.sh
```

From inside the DuckDB prompt, run the sample queries:

```sql
.read scripts/duckdb_sample_queries.sql
```

The launcher loads `.env`, creates temporary DuckDB secrets, attaches the DuckLake catalog, and runs `USE` for the configured catalog. The secrets, `ATTACH`, and `USE` statements are session-scoped because the CLI uses an in-memory DuckDB session, so rerun `bash scripts/duckdb_cli.sh` whenever you open a new CLI session.

### Run Dagster Locally

Dagster orchestrates the same dlt ingestion and dbt transformation flow. Keep `scripts/start_cloud_sql_proxy.sh` running before launching Dagster because DuckLake metadata is stored in Cloud SQL.

1. Start the Dagster UI and daemon with `DAGSTER_HOME=$PWD/storage/dagster_home uv run dagster dev`.
2. Open the Dagster UI shown in the command output.
3. Materialize the `usgs_pipeline_job` asset job to run `USGS API → dlt → DuckLake raw schemas → dbt build → DuckLake marts`.
4. Enable the `daily_usgs_schedule` schedule to run the same job every 15 minutes.

To run a bigger historical pull from Dagster Launchpad, pass config for the `usgs_water_services` asset:

```yaml
ops:
  usgs_water_services:
    config:
      history_period: P90D
```

Or use an explicit date range:

```yaml
ops:
  usgs_water_services:
    config:
      start_dt: "2025-01-01T00:00:00Z"
      end_dt: "2025-03-31T23:59:59Z"
```

The local Dagster instance stores run metadata and logs under `storage/dagster_home/`. Generated runtime state is ignored by git; only the local `dagster.yaml` is committed.

### USGS Station Config

Default USGS station selection lives in `pipelines/deployment_configs/usgs_stations.yml`. The file has top-level defaults for `parameter_codes` and `history_period`, plus per-station entries with `site_code`, river, and location metadata. Stations inherit the top-level `parameter_codes` unless a station defines its own override.

The ingestion pipeline queries each station independently. If one station request fails, the failed station is skipped and the remaining stations continue loading. Raw USGS loads use merge semantics keyed by `site_code`, `parameter_code`, and `timestamp`, and the staging model also deduplicates by the same natural key before marts are built.

### Deploy Dagster to Cloud Run

Phase 2 deploys Dagster as two Cloud Run services backed by the existing Cloud SQL instance:
- `dagster-webserver` serves the Dagster UI and GraphQL API.
- `dagster-daemon` runs schedules and sensors with exactly one always-on instance.
- Dagster run/event/schedule metadata is stored in a separate `dagster` database in Cloud SQL.
- Cloud Run uses its runtime service account for GCS access; the local service account key remains only for local development.
- Container logs are tee'd to a shared volume and shipped to Grafana Cloud Loki by a Grafana Alloy sidecar.

Provision the Cloud Run-specific infrastructure after the base DuckLake setup is complete:

```bash
export GCP_PROJECT_ID=your-gcp-project-id
export LOKI_URL=https://logs-prod-000.grafana.net/loki/api/v1/push
export LOKI_USER=your-grafana-cloud-logs-user
export LOKI_API_KEY=your-grafana-cloud-api-key
bash scripts/setup_dagster_gcp.sh
```

If you want GitHub Actions deployment, also set `GITHUB_REPOSITORY=owner/repo` before running `scripts/setup_dagster_gcp.sh`; the script prints the repository variables needed by `.github/workflows/deploy-dagster.yml`.

Build and deploy manually with:

```bash
bash scripts/deploy_dagster.sh
```

### Redeploy Dagster

Use the same deploy script whenever application code, dbt models, Dagster definitions, schedules, or Cloud Run settings change:

```bash
bash scripts/deploy_dagster.sh
```

By default, the image tag is the current git commit short SHA. If you are redeploying uncommitted local changes, set a unique tag so Cloud Run pulls a fresh image:

```bash
IMAGE_TAG="dev-$(date -u +%Y%m%d%H%M%S)" bash scripts/deploy_dagster.sh
```

If the image is already pushed and you only need to reapply Cloud Run service configuration, skip the Docker build/push step:

```bash
SKIP_BUILD=1 bash scripts/deploy_dagster.sh
```

After redeploying, confirm both services are ready:

```bash
gcloud run services list --project "$GCP_PROJECT_ID" --region "${GCP_REGION:-us-central1}"
```

Set `DAGSTER_WEBSERVER_ALLOW_UNAUTHENTICATED=1` before deployment only if you want the Dagster UI publicly invokable. Otherwise grant `roles/run.invoker` to specific users or a Google Workspace domain and use `gcloud run services proxy` for authenticated local access.

### Monorepo Structure
```
oss-data-stack/
├── pipelines/              # dlt ingestion pipelines
│   ├── deployment_configs/ # Deployment-specific station/config selections
│   └── usgs/              # USGS Water Services pipeline
├── transformations/        # dbt project
│   ├── models/
│   │   ├── staging/       # Raw data cleaning
│   │   └── marts/         # Business logic
│   └── dbt_project.yml
├── orchestration/         # Dagster project
│   ├── definitions.py     # Main Dagster definitions
│   ├── assets/           # Data assets (dlt + dbt)
│   ├── resources/        # Dagster resources
│   ├── jobs/             # Asset jobs
│   └── schedules/        # Job schedules
├── config/
│   ├── alloy/            # Grafana Alloy log shipping config
│   └── dlt/              # dlt runtime config
├── shared/              # Shared utilities
└── scripts/             # Local, GCP setup, and deploy helpers
```

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
