"""Shared configuration utilities."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Project root directory
PROJECT_ROOT = Path(__file__).parent.parent

# Storage paths
STORAGE_DIR = PROJECT_ROOT / "storage"
DUCKDB_PATH = os.getenv("DUCKDB_PATH", str(STORAGE_DIR / "catalog.duckdb"))
DATA_LAKE_DIR = STORAGE_DIR / "lake"
WAREHOUSE_DIR = STORAGE_DIR / "warehouse"

# dlt Configuration
DLT_CONFIG_PATH = PROJECT_ROOT / "config" / "dlt" / "config.toml"

# Ensure storage directories exist
STORAGE_DIR.mkdir(exist_ok=True)
DATA_LAKE_DIR.mkdir(exist_ok=True)
WAREHOUSE_DIR.mkdir(exist_ok=True)
