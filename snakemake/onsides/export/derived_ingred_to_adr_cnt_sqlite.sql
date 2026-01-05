-- SQLite/DuckDB: create derived_ingred_to_adr_cnt for local database (database/onsides.db)
-- NOTE: This variant is intended to run in the SQLite/DuckDB workflow and does not
-- reproduce the "exclude indications" step that depends on the external `reposdb` schema.
-- This script is untested and designed for local/archival builds only.

BEGIN TRANSACTION;

-- Assemble ingredient <-> product <-> label mapping (local DB vocabulary tables)
DROP TABLE IF EXISTS db.derived_ingred_to_adr_cnt;

WITH labs AS (
    SELECT DISTINCT
        vi.rxnorm_id AS ingred_rxcui,
        vi.rxnorm_name AS ingred_name,
        pl.label_id,
        pl.source
    FROM
        db.product_label pl
        INNER JOIN db.product_to_rxnorm p2r ON pl.label_id = p2r.label_id
        INNER JOIN db.vocab_rxnorm_product p ON p2r.rxnorm_product_id = p.rxnorm_id
        INNER JOIN db.vocab_rxnorm_ingredient_to_product vi2p ON p.rxnorm_id = vi2p.product_id
        INNER JOIN db.vocab_rxnorm_ingredient vi ON vi2p.ingredient_id = vi.rxnorm_id
)

CREATE TABLE db.derived_ingred_to_adr_cnt AS
SELECT
    NULL AS ingred_concept_id,
    labs.ingred_rxcui AS ingred_rxcui,
    labs.ingred_name AS ingred_name,
    pae.label_section AS label_section,
    vma.meddra_id AS meddra_concept_id,
    CAST(vma.meddra_id AS TEXT) AS meddra_code,
    vma.meddra_name AS meddra_term,
    vma.meddra_term_type AS meddra_term_type,
    COUNT(DISTINCT pae.product_label_id) AS cnt
FROM labs
INNER JOIN db.product_adverse_effect pae ON pae.product_label_id = labs.label_id
INNER JOIN db.vocab_meddra_adverse_effect vma ON pae.effect_meddra_id = vma.meddra_id
WHERE pae.match_method = 'PMB'
  AND pae.pred1 >= 3.258
  AND labs.source = 'US'
-- Note: does NOT exclude indications because the `reposdb` indication table is not present
GROUP BY labs.ingred_rxcui, labs.ingred_name, pae.label_section, vma.meddra_id, vma.meddra_name, vma.meddra_term_type
ORDER BY labs.ingred_name, pae.label_section, vma.meddra_name, vma.meddra_term_type;

CREATE INDEX IF NOT EXISTS derived_ingred_to_adr_cnt_ingred_rxcui_idx ON db.derived_ingred_to_adr_cnt(ingred_rxcui);
CREATE INDEX IF NOT EXISTS derived_ingred_to_adr_cnt_ingred_meddra_code_idx ON db.derived_ingred_to_adr_cnt(meddra_code);

COMMIT;