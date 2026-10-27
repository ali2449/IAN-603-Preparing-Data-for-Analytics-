-- ============================================================
-- IAN 603 - MODULE 14
-- Course Synthesis & Sample Project Walkthrough
-- ============================================================
-- Companion file for module14.html
-- PostgreSQL / pgAdmin Query Tool
--
-- IMPORTANT
-- This is the SAME SAMPLE WALKTHROUGH used by Module 14.
-- It is a study/practice file, NOT the official Final Project.
-- The official Final Project instructions and submission remain
-- in Canvas.
--
-- SAMPLE WORKFLOW
-- Raw source -> Profile -> Clean -> Normalize -> Integrate
-- -> Validate -> Document
--
-- TARGET FINAL GRAIN
-- One row per route per service date.
-- ============================================================

-- ============================================================
-- SECTION 1 - RESET SAMPLE PROJECT OBJECTS
-- ============================================================

DROP VIEW IF EXISTS final_route_daily_dataset CASCADE;
DROP TABLE IF EXISTS route_streets CASCADE;
DROP TABLE IF EXISTS clean_daily_ridership CASCADE;
DROP TABLE IF EXISTS clean_bus_stops CASCADE;
DROP TABLE IF EXISTS clean_bus_routes CASCADE;
DROP TABLE IF EXISTS raw_daily_ridership CASCADE;
DROP TABLE IF EXISTS raw_bus_stops CASCADE;
DROP TABLE IF EXISTS raw_bus_routes CASCADE;

-- ============================================================
-- SECTION 2 - RAW TABLES
-- ============================================================
-- Raw tables preserve source representation as much as possible.

CREATE TABLE raw_bus_routes (
    route_id integer,
    route_name text,
    major_streets text
);

CREATE TABLE raw_bus_stops (
    stop_id integer,
    route_id integer,
    stop_name text,
    wheelchair_accessible_raw text
);

CREATE TABLE raw_daily_ridership (
    ridership_id integer,
    route_id integer,
    service_date_raw text,
    riders integer
);

-- Sample rows shown in Module 14.
INSERT INTO raw_bus_routes VALUES
(1,'Route A','Main St, Elm St, Oak Ave'),
(2,'Route B','Pine Rd, Maple Blvd'),
(3,'Route C','Cedar Ln, Birch Way, Willow St');

INSERT INTO raw_bus_stops VALUES
(101,1,'Main St Stop','Yes'),
(102,1,'Elm St Stop',NULL),
(103,2,'Pine Rd Stop','No');

INSERT INTO raw_daily_ridership VALUES
(1,1,'01/10/2025',150),
(2,1,'2025-01-11',200),
(3,2,'02/01/2025',120);

-- ============================================================
-- SECTION 3 - PROFILE BEFORE CLEANING
-- ============================================================

-- Raw ridership row count, distinct IDs, missing keys/measures,
-- and range of the rider measure.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT ridership_id) AS distinct_ids,
    COUNT(*) FILTER (WHERE route_id IS NULL) AS missing_route_ids,
    COUNT(*) FILTER (WHERE riders IS NULL) AS missing_rider_counts,
    MIN(riders) AS min_riders,
    MAX(riders) AS max_riders
FROM raw_daily_ridership;

-- Inspect date representations before parsing.
SELECT
    service_date_raw,
    COUNT(*) AS occurrences
FROM raw_daily_ridership
GROUP BY service_date_raw
ORDER BY occurrences DESC, service_date_raw;

-- Profile route keys.
SELECT route_id, COUNT(*) AS rows_per_route_id
FROM raw_bus_routes
GROUP BY route_id
HAVING COUNT(*) > 1;

-- Profile stop accessibility source values.
SELECT wheelchair_accessible_raw,
       COUNT(*) AS rows
FROM raw_bus_stops
GROUP BY wheelchair_accessible_raw
ORDER BY wheelchair_accessible_raw NULLS FIRST;

-- ============================================================
-- SECTION 4 - CLEAN ROUTES
-- ============================================================

CREATE TABLE clean_bus_routes AS
SELECT
    route_id,
    BTRIM(route_name) AS route_name
FROM raw_bus_routes;

ALTER TABLE clean_bus_routes
ADD PRIMARY KEY (route_id);

-- Normalize the comma-separated major_streets field into one
-- route/street relationship per row.
CREATE TABLE route_streets AS
SELECT
    r.route_id,
    BTRIM(street_name) AS street_name
FROM raw_bus_routes AS r
CROSS JOIN LATERAL
    REGEXP_SPLIT_TO_TABLE(r.major_streets, '\s*,\s*') AS street_name;

ALTER TABLE route_streets
ADD PRIMARY KEY (route_id, street_name);

-- ============================================================
-- SECTION 5 - CLEAN BUS STOPS
-- ============================================================

CREATE TABLE clean_bus_stops AS
SELECT
    stop_id,
    route_id,
    BTRIM(stop_name) AS stop_name,
    CASE LOWER(BTRIM(wheelchair_accessible_raw))
        WHEN 'yes' THEN TRUE
        WHEN 'no'  THEN FALSE
        ELSE NULL
    END AS wheelchair_accessible,
    CASE
        WHEN wheelchair_accessible_raw IS NULL
          OR BTRIM(wheelchair_accessible_raw) = ''
        THEN 'missing_source_value'
        ELSE 'source_value_present'
    END AS accessibility_status
FROM raw_bus_stops;

ALTER TABLE clean_bus_stops
ADD PRIMARY KEY (stop_id);

ALTER TABLE clean_bus_stops
ADD CONSTRAINT fk_clean_stop_route
FOREIGN KEY (route_id) REFERENCES clean_bus_routes(route_id);

-- ============================================================
-- SECTION 6 - CLEAN DAILY RIDERSHIP
-- ============================================================

CREATE TABLE clean_daily_ridership AS
SELECT
    ridership_id,
    route_id,
    service_date_raw,
    CASE
        WHEN BTRIM(service_date_raw) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN BTRIM(service_date_raw)::date
        WHEN BTRIM(service_date_raw) ~ '^\d{1,2}/\d{1,2}/\d{4}$'
            THEN TO_DATE(BTRIM(service_date_raw), 'MM/DD/YYYY')
        ELSE NULL
    END AS service_date,
    riders
FROM raw_daily_ridership;

ALTER TABLE clean_daily_ridership
ADD PRIMARY KEY (ridership_id);

ALTER TABLE clean_daily_ridership
ADD CONSTRAINT fk_clean_ridership_route
FOREIGN KEY (route_id) REFERENCES clean_bus_routes(route_id);

-- ============================================================
-- SECTION 7 - INSPECT CLEANED TABLES
-- ============================================================

SELECT * FROM clean_bus_routes ORDER BY route_id;
SELECT * FROM route_streets ORDER BY route_id, street_name;
SELECT * FROM clean_bus_stops ORDER BY stop_id;
SELECT * FROM clean_daily_ridership ORDER BY service_date, ridership_id;

-- ============================================================
-- SECTION 8 - INTEGRATE AT THE CORRECT GRAIN
-- ============================================================
-- Desired output grain: one row per route per service date.
--
-- Do NOT join daily ridership directly to every stop and then sum
-- riders; that would repeat a route-day rider count once per stop.
-- First reduce stops to one row per route.

CREATE OR REPLACE VIEW final_route_daily_dataset AS
WITH stop_summary AS (
    SELECT
        route_id,
        COUNT(*) AS stop_count,
        COUNT(*) FILTER (
            WHERE wheelchair_accessible IS TRUE
        ) AS accessible_stop_count,
        COUNT(*) FILTER (
            WHERE wheelchair_accessible IS NULL
        ) AS unknown_accessibility_count
    FROM clean_bus_stops
    GROUP BY route_id
)
SELECT
    r.route_id,
    r.route_name,
    d.service_date,
    d.riders,
    COALESCE(s.stop_count,0) AS stop_count,
    COALESCE(s.accessible_stop_count,0) AS accessible_stop_count,
    COALESCE(s.unknown_accessibility_count,0) AS unknown_accessibility_count
FROM clean_daily_ridership AS d
JOIN clean_bus_routes AS r
    ON r.route_id = d.route_id
LEFT JOIN stop_summary AS s
    ON s.route_id = d.route_id;

SELECT *
FROM final_route_daily_dataset
ORDER BY service_date, route_id;

-- ============================================================
-- SECTION 9 - VALIDATION
-- ============================================================

-- A. Uniqueness of raw/clean ridership identifier.
SELECT ridership_id, COUNT(*)
FROM clean_daily_ridership
GROUP BY ridership_id
HAVING COUNT(*) > 1;

-- B. Referential integrity check.
SELECT d.*
FROM clean_daily_ridership AS d
LEFT JOIN clean_bus_routes AS r
    ON r.route_id = d.route_id
WHERE r.route_id IS NULL;

-- C. Date parsing failures.
SELECT *
FROM clean_daily_ridership
WHERE service_date IS NULL;

-- D. Range validity.
SELECT *
FROM clean_daily_ridership
WHERE riders < 0;

-- E. Validate intended final grain.
SELECT
    route_id,
    service_date,
    COUNT(*) AS rows_at_grain
FROM final_route_daily_dataset
GROUP BY route_id, service_date
HAVING COUNT(*) > 1;

-- F. Compare row counts.
SELECT COUNT(*) AS cleaned_ridership_rows
FROM clean_daily_ridership;

SELECT COUNT(*) AS final_rows
FROM final_route_daily_dataset;

-- G. Compare rider totals before and after integration.
SELECT SUM(riders) AS cleaned_total_riders
FROM clean_daily_ridership;

SELECT SUM(riders) AS final_total_riders
FROM final_route_daily_dataset;

-- ============================================================
-- SECTION 10 - COURSE-SYNTHESIS EXAMPLES
-- ============================================================

-- CTE + aggregation.
WITH route_totals AS (
    SELECT route_id,
           SUM(riders) AS total_riders,
           AVG(riders)::numeric(10,2) AS avg_daily_riders
    FROM clean_daily_ridership
    GROUP BY route_id
)
SELECT r.route_id, r.route_name,
       t.total_riders, t.avg_daily_riders
FROM clean_bus_routes AS r
LEFT JOIN route_totals AS t USING (route_id)
ORDER BY total_riders DESC NULLS LAST, r.route_id;

-- Window function: previous service date per route.
SELECT
    route_id,
    service_date,
    riders,
    LAG(service_date) OVER (
        PARTITION BY route_id
        ORDER BY service_date
    ) AS previous_service_date
FROM clean_daily_ridership
ORDER BY route_id, service_date;

-- Reusable analytical view example.
CREATE OR REPLACE VIEW route_summary AS
SELECT
    f.route_id,
    MAX(f.route_name) AS route_name,
    COUNT(*) AS service_days,
    SUM(f.riders) AS total_riders,
    ROUND(AVG(f.riders),2) AS avg_daily_riders,
    MAX(f.stop_count) AS stop_count,
    MAX(f.accessible_stop_count) AS accessible_stop_count
FROM final_route_daily_dataset AS f
GROUP BY f.route_id;

SELECT *
FROM route_summary
ORDER BY total_riders DESC, route_id;

-- ============================================================
-- SECTION 11 - DOCUMENTATION QUESTIONS
-- ============================================================
-- Write answers in your project notes:
--
-- 1. What did one raw row represent in each source?
-- 2. Which source values were changed only in representation?
-- 3. Which values remained NULL because the source did not tell us?
-- 4. What is the grain of the final dataset?
-- 5. Which validation queries prove that grain?
-- 6. Which totals should be preserved?
-- 7. What assumptions did you deliberately avoid making?
--
-- ============================================================
-- SECTION 12 - ADDITIONAL PRACTICE
-- ============================================================
--
-- PRACTICE 1
-- Add more stops and route-day ridership rows. Re-run validation.
--
-- PRACTICE 2
-- Add a malformed date string and confirm that service_date is NULL.
--
-- PRACTICE 3
-- Add a stop for a nonexistent route to see how the foreign-key
-- constraint protects referential integrity.
--
-- PRACTICE 4
-- Extend final_route_daily_dataset with the number of normalized
-- major streets per route without changing the route-date grain.
--
-- PRACTICE 5
-- Create a monthly route summary using DATE_TRUNC('month', service_date).
--
-- ============================================================
-- MODULE 14 READINESS CHECKLIST
-- ============================================================
-- [ ] Raw source values are preserved.
-- [ ] I profiled before cleaning.
-- [ ] Cleaning rules are explicit.
-- [ ] Missing/unknown is not silently converted into a fact.
-- [ ] Multi-valued fields are normalized where appropriate.
-- [ ] Joins preserve the intended grain.
-- [ ] Keys and relationships are validated.
-- [ ] Dates and ranges are validated.
-- [ ] Totals are reconciled.
-- [ ] Decisions and assumptions are documented.
--
-- Again: this is a study/sample file, not the Canvas Final Project.
-- ============================================================
