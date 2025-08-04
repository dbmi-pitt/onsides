#!/bin/bash
set -euo pipefail

CSV_DIR="/home/pentaho-secondary/onsides/data/csv"
DB="cem_development"
USER="rw_grp"
SCHEMA="onsides"
LOG="load_report_$(date +%Y%m%d_%H%M%S).log"

# Skip product_adverse_effect, assume it's loading
TABLES=(
  "product_to_rxnorm"
  "vocab_rxnorm_product"
  "vocab_rxnorm_ingredient_to_product"
  "vocab_rxnorm_ingredient"
  "vocab_meddra_adverse_effect"
  "high_confidence"
)

echo "Starting OnSIDES CSV load report at $(date)" | tee "$LOG"

for table in "${TABLES[@]}"; do
  FILE="${CSV_DIR}/${table}.csv"
  echo "Loading $table from $FILE ..." | tee -a "$LOG"

  psql -d "$DB" -U "$USER" -v ON_ERROR_STOP=0 <<EOF 2>>"$LOG"
\echo 'COPY $SCHEMA.$table ...'
COPY $SCHEMA.$table
FROM '$FILE'
WITH (FORMAT csv, HEADER true);
EOF

  if [ $? -eq 0 ]; then
    ROWS=$(psql -d "$DB" -U "$USER" -t -c "SELECT COUNT(*) FROM $SCHEMA.$table;" 2>>"$LOG")
    echo "✅ $table: Loaded successfully — $ROWS rows" | tee -a "$LOG"
  else
    echo "❌ $table: FAILED to load. See log for details." | tee -a "$LOG"
  fi

  echo "-------------------------------------" | tee -a "$LOG"
done

echo "Done at $(date)" | tee -a "$LOG"
