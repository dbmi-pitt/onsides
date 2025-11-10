#!/bin/bash
# Copy data from _about.about in cem_development (5432) to cem_development_2025 (5433)
# Usage: ./copy_about_metadata.sh

# Source DB (cem_development on 5432)
SOURCE_HOST="${SOURCE_HOST:-localhost}"
SOURCE_PORT="${SOURCE_PORT:-5432}"
SOURCE_USER="${SOURCE_USER:-postgres}"
SOURCE_DB="${SOURCE_DB:-cem_development}"

# Target DB (cem_development_2025 on 5433)
TARGET_HOST="${TARGET_HOST:-localhost}"
TARGET_PORT="${TARGET_PORT:-5433}"
TARGET_USER="${TARGET_USER:-postgres}"
TARGET_DB="${TARGET_DB:-cem_development_2025}"

# Check if source data exists
SOURCE_COUNT=$(psql \
    --host="$SOURCE_HOST" \
    --port="$SOURCE_PORT" \
    --username="$SOURCE_USER" \
    --dbname="$SOURCE_DB" \
    --tuples-only \
    --command="SELECT COUNT(*) FROM \"_about\".about;")

if [[ "$SOURCE_COUNT" -eq 0 ]]; then
  echo "No data in source _about.about table."
  exit 0
fi

echo "Found $SOURCE_COUNT rows in source. Copying to target..."

# Export from source and import to target using COPY
psql \
    --host="$SOURCE_HOST" \
    --port="$SOURCE_PORT" \
    --username="$SOURCE_USER" \
    --dbname="$SOURCE_DB" \
    --command="COPY \"_about\".about TO STDOUT WITH CSV HEADER;" \
| psql \
    --host="$TARGET_HOST" \
    --port="$TARGET_PORT" \
    --username="$TARGET_USER" \
    --dbname="$TARGET_DB" \
    --command="COPY \"_about\".about FROM STDIN WITH CSV HEADER;"

echo "Data copied successfully."