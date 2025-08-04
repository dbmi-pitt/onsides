#!/bin/bash
# untested

set -euo pipefail

DB="cem_development"
USER="rw_grp"
SCHEMA="onsides"
SCHEMA_FILE="data_our_improvements/schema/postgres_v3.1.0_fixed.sql"
LOG="setup_schema_log_$(date +%Y%m%d_%H%M%S).log"

echo "Creating or replacing schema '$SCHEMA' in database '$DB'..." | tee "$LOG"

# Create schema if it doesn't exist
psql -d "$DB" -U "$USER" -v ON_ERROR_STOP=1 -c "CREATE SCHEMA IF NOT EXISTS $SCHEMA;" 2>>"$LOG"

# Run schema creation
echo "Applying fixed schema from $SCHEMA_FILE..." | tee -a "$LOG"
psql -d "$DB" -U "$USER" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE" 2>>"$LOG"

# Optional: insert tracking metadata
psql -d "$DB" -U "$USER" -v ON_ERROR_STOP=1 <<EOF 2>>"$LOG"
INSERT INTO _about.about (schema, table, attribute, value, "timestamp")
VALUES
  ('$SCHEMA', NULL, 'schema_applied', '$SCHEMA_FILE', now());
EOF

echo "✅ Schema setup complete." | tee -a "$LOG"
