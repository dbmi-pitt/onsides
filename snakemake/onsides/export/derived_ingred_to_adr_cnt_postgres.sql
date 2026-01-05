-- Postgres: create derived_ingred_to_adr_cnt in schema onsides

-- This file implements the SQL provided in the request. It is intended to be run
-- against a production Postgres database that contains the following schemas:
--  - reposdb
--  - staging_vocabulary
--  - onsides
--
-- NOTE: This script creates temporary tables and a final table: onsides.derived_ingred_to_adr_cnt
-- It is untested in this repository. See README for notes.

DROP TABLE IF EXISTS onsides.derived_ingred_to_adr_cnt;

BEGIN;
SET LOCAL work_mem = '3GB';

-- Build a list of drug indications per reposdb mapped drug
DROP TABLE IF EXISTS inds;
CREATE TEMPORARY TABLE inds AS
SELECT r.drug_name, r.status, r.drug_rxnorm_id, r.ind_meddra_pt
FROM reposdb.reposdb_mapped r
INNER JOIN reposdb.reposdb_drugbank_to_rxnorm_v3b rdtrvb ON rdtrvb.id = r.drugbank_id
WHERE r.status = 'Approved'
  AND r.ind_meddra_pt IS NOT NULL
;
CREATE INDEX idx_inds_drug_rxnorm_id ON inds(drug_rxnorm_id);

-- Map ingredients -> products using the OMOP staging vocabulary
DROP TABLE IF EXISTS rxnmaps;
CREATE TEMPORARY TABLE rxnmaps AS
SELECT c1.concept_id AS ingred_concept_id,
       c1.concept_code AS ingred_rxcui,
       c1.concept_name AS ingred_name,
       c2.concept_id AS prod_concept_id,
       c2.concept_code AS prod_rxcui,
       c2.concept_name AS prod_name,
       inds.ind_meddra_pt
FROM staging_vocabulary.concept c1
INNER JOIN staging_vocabulary.concept_ancestor ca ON c1.concept_id = ca.ancestor_concept_id
INNER JOIN staging_vocabulary.concept c2 ON c2.concept_id = ca.descendant_concept_id
LEFT OUTER JOIN inds ON c1.concept_code = inds.drug_rxnorm_id
WHERE c1.vocabulary_id = 'RxNorm'
  AND c1.concept_class_id = 'Ingredient'
  AND c2.vocabulary_id = 'RxNorm'
;
CREATE INDEX ids_rxnmaps_prod_rxcui ON rxnmaps(prod_rxcui);

-- Join products (via product_to_rxnorm) to product labels
DROP TABLE IF EXISTS labs;
CREATE TEMPORARY TABLE labs AS
SELECT DISTINCT prd.*, pl.*
FROM onsides.product_to_rxnorm ptr
INNER JOIN rxnmaps prd ON ptr.rxnorm_product_id = prd.prod_rxcui
INNER JOIN onsides.product_label pl ON pl.label_id = ptr.label_id
;
CREATE INDEX idx_labs_label_id ON labs(label_id);

-- Final aggregated counts per ingredient x meddra term x section
CREATE TABLE onsides.derived_ingred_to_adr_cnt AS
SELECT
  ingred_concept_id,
  ingred_rxcui,
  ingred_name,
  pae.label_section,
  c.concept_id AS meddra_concept_id,
  c.concept_code as meddra_code,
  c.concept_name AS meddra_term,
  c.concept_class_id AS meddra_term_type,
  COUNT(DISTINCT pae.product_label_id ) AS cnt
FROM labs
INNER JOIN onsides.product_adverse_effect pae ON pae.product_label_id = labs.label_id
INNER JOIN staging_vocabulary.concept c ON CAST(pae.effect_meddra_id AS varchar) = c.concept_code
WHERE pae.match_method = 'PMB'
  AND pae.pred1 >= 3.258
  AND c.vocabulary_id = 'MedDRA'
  AND labs."source" = 'US'
  AND CAST(pae.effect_meddra_id AS varchar) NOT IN (
      SELECT ind_meddra_pt FROM inds WHERE ingred_rxcui = inds.drug_rxnorm_id
  ) -- do not include indications as adverse events
GROUP BY ingred_concept_id, ingred_rxcui, ingred_name, pae.label_section, c.concept_id, c.concept_name, c.concept_code, c.concept_class_id
ORDER BY ingred_name, label_section, meddra_term, meddra_term_type
;

CREATE INDEX derived_ingred_to_adr_cnt_ingred_rxcui_idx ON onsides.derived_ingred_to_adr_cnt(ingred_rxcui);
CREATE INDEX derived_ingred_to_adr_cnt_ingred_meddra_code_idx ON onsides.derived_ingred_to_adr_cnt(meddra_code);

-- Example query to inspect results (left for operator):
-- SELECT * FROM onsides.derived_ingred_to_adr_cnt d WHERE d.ingred_rxcui = '2683';

COMMIT;

-- Cleanup temporary tables
DROP TABLE IF EXISTS rxnmaps;
DROP TABLE IF EXISTS labs;
DROP TABLE IF EXISTS inds;
