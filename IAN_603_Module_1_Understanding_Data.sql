-- ============================================================
-- IAN 603 - MODULE 1
-- Understanding Data in Informatics
-- ============================================================
-- Companion file for s_module1.html
-- PostgreSQL / pgAdmin Query Tool
--
-- PURPOSE
-- Module 1 is about understanding what data means before trying
-- to analyze it. This file gives a small relational dataset for
-- practicing data types, measurement meaning, missingness,
-- validity, uniqueness, and basic profiling.
--
-- KEY IDEA
-- A PostgreSQL data type tells you how a value is stored.
-- It does not by itself tell you what the value means.
-- ============================================================

DROP TABLE IF EXISTS encounters;

CREATE TABLE encounters (
    encounter_id BIGSERIAL PRIMARY KEY,
    patient_id TEXT NOT NULL,
    encounter_date DATE NOT NULL,
    triage_level TEXT NOT NULL
        CHECK (triage_level IN ('Non-urgent', 'Urgent', 'Emergent')),
    temperature_c DOUBLE PRECISION
        CHECK (temperature_c BETWEEN 30 AND 45),
    er_visits INTEGER NOT NULL
        CHECK (er_visits >= 0),
    total_charge NUMERIC(12, 2)
        CHECK (total_charge >= 0)
);

INSERT INTO encounters
    (patient_id, encounter_date, triage_level,
     temperature_c, er_visits, total_charge)
VALUES
    ('P1001', DATE '2026-09-01', 'Urgent',     38.2, 3, 125.00),
    ('P1002', DATE '2026-09-01', 'Non-urgent',36.9, 0,  65.00),
    ('P1003', DATE '2026-09-02', 'Emergent',   39.4, 5, 980.00),
    ('P1004', DATE '2026-09-02', 'Urgent',     37.8, 1, 210.00),
    ('P1005', DATE '2026-09-03', 'Non-urgent',37.0, 0,  80.00),
    ('P1006', DATE '2026-09-03', 'Urgent',     NULL, 2, 340.00),
    ('P1007', DATE '2026-09-04', 'Emergent',   40.1, 4, 1200.00),
    ('P1008', DATE '2026-09-04', 'Urgent',     38.0, 1, NULL);

-- ============================================================
-- SECTION 1 - INSPECT THE DATA
-- ============================================================

SELECT *
FROM encounters
ORDER BY encounter_id;

-- PostgreSQL storage types.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'encounters'
ORDER BY ordinal_position;

-- ============================================================
-- SECTION 2 - ASK WHAT EACH COLUMN MEANS
-- ============================================================
-- patient_id is stored as text and behaves like an identifier.
-- It is categorical/nominal even though it contains digits.
--
-- triage_level is ordered categorical data.
--
-- er_visits is a count. Zero has a meaningful interpretation.
--
-- temperature_c is numeric but Celsius does not have a true zero.
--
-- total_charge is a quantitative measure with a meaningful zero.

-- Categories and their frequencies.
SELECT triage_level, COUNT(*) AS encounters
FROM encounters
GROUP BY triage_level
ORDER BY encounters DESC, triage_level;

-- Quantitative summaries.
SELECT
    COUNT(*) AS rows,
    COUNT(temperature_c) AS recorded_temperatures,
    ROUND(AVG(temperature_c)::numeric,2) AS avg_temperature_c,
    MIN(er_visits) AS min_er_visits,
    MAX(er_visits) AS max_er_visits,
    ROUND(AVG(total_charge),2) AS avg_charge
FROM encounters;

-- ============================================================
-- SECTION 3 - BASIC DATA QUALITY PROFILING
-- ============================================================

-- Missing values.
SELECT
    COUNT(*) FILTER (WHERE temperature_c IS NULL) AS missing_temperature,
    COUNT(*) FILTER (WHERE total_charge IS NULL) AS missing_charge
FROM encounters;

-- Uniqueness of the encounter identifier.
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT encounter_id) AS distinct_encounter_ids
FROM encounters;

-- Patient identifiers can repeat across encounters in real data.
SELECT patient_id, COUNT(*) AS encounter_count
FROM encounters
GROUP BY patient_id
ORDER BY encounter_count DESC, patient_id;

-- Range checks provide evidence about plausibility.
SELECT *
FROM encounters
WHERE temperature_c IS NOT NULL
  AND (temperature_c < 35 OR temperature_c > 40)
ORDER BY temperature_c;

-- ============================================================
-- SECTION 4 - GRAIN
-- ============================================================
-- Grain means what one row represents.
-- Here: one row = one encounter.
--
-- Always state grain before aggregation or joining.

SELECT
    encounter_date,
    COUNT(*) AS encounter_count,
    SUM(er_visits) AS total_prior_er_visits,
    SUM(total_charge) AS total_charge
FROM encounters
GROUP BY encounter_date
ORDER BY encounter_date;

-- ============================================================
-- SECTION 5 - PRACTICE
-- ============================================================
-- 1. Which columns are identifiers, categories, counts, or measures?
-- 2. Find all rows with missing numeric measurements.
-- 3. Count encounters by triage level.
-- 4. Compare average charge across triage levels.
-- 5. Explain why averaging patient_id would be meaningless.
--
-- MODULE 1 CHECKLIST
-- [ ] I can state what one row represents.
-- [ ] I distinguish storage type from measurement meaning.
-- [ ] I inspect missingness and validity before analysis.
-- [ ] I know that identifiers are not quantitative measures.
-- ============================================================
