#!/bin/bash
set -euo pipefail

DB="cem_development"
USER="rw_grp"
SCHEMA="onsides"
CSV_DIR="/home/pentaho-secondary/onsides/data/csv"
LOG="remaining_3_log_$(date +%Y%m%d_%H%M%S).log"

echo "Starting reload of 3 corrected tables..." | tee "$LOG"

psql -d "$DB" -U "$USER" -v ON_ERROR_STOP=1 <<EOF 2>>"$LOG"

-- Recreate product_to_rxnorm
DROP TABLE IF EXISTS $SCHEMA.product_to_rxnorm CASCADE;
CREATE TABLE $SCHEMA.product_to_rxnorm (
    label_id INTEGER,
    rxnorm_product_id TEXT
);

-- Recreate vocab_rxnorm_ingredient_to_product
DROP TABLE IF EXISTS $SCHEMA.vocab_rxnorm_ingredient_to_product CASCADE;
CREATE TABLE $SCHEMA.vocab_rxnorm_ingredient_to_product (
    product_id TEXT,
    ingredient_id TEXT
);

-- Recreate vocab_rxnorm_ingredient
DROP TABLE IF EXISTS $SCHEMA.vocab_rxnorm_ingredient CASCADE;
CREATE TABLE $SCHEMA.vocab_rxnorm_ingredient (
    rxnorm_id TEXT,
    rxnorm_name TEXT,
    rxnorm_term_type TEXT
);

EOF

# COPY commands
for table in product_to_rxnorm vocab_rxnorm_ingredient_to_product vocab_rxnorm_ingredient; do
  echo "Loading $table ..." | tee -a "$LOG"
  psql -d "$DB" -U "$USER" -v ON_ERROR_STOP=1 -c "
  COPY $SCHEMA.$table
  FROM '$CSV_DIR/$table.csv'
  WITH (FORMAT csv, HEADER true);
  " 2>>"$LOG"

  ROWS=$(psql -d "$DB" -U "$USER" -t -c "SELECT COUNT(*) FROM $SCHEMA.$table;" 2>>"$LOG" | xargs)
  echo "✅ $table: Loaded $ROWS rows" | tee -a "$LOG"
  echo "-------------------------------------" | tee -a "$LOG"
done

echo "All 3 tables reloaded successfully." | tee -a "$LOG"
