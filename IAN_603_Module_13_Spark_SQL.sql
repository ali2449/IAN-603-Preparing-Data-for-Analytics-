-- ============================================================
-- IAN 603 - MODULE 13
-- Introduction to Spark SQL
-- ============================================================
-- Companion file for s_module13.html
--
-- IMPORTANT
-- This file is written for SPARK SQL, not PostgreSQL.
-- Run it in a Spark SQL notebook cell (for example Microsoft
-- Fabric, Databricks, or another Spark environment).
--
-- The module also demonstrates PySpark/DataFrame code. This .sql
-- file focuses on the SQL side so students can practice familiar
-- relational ideas in a distributed execution environment.
--
-- CORE IDEAS
-- * Spark SQL keeps familiar relational logic.
-- * Spark builds logical and physical execution plans.
-- * Large scans and shuffles can dominate performance.
-- * Partitioning and file layout influence how much data is read.
-- * Curated lakehouse tables should have a clear row grain.
-- * Delta tables provide table behavior on top of lakehouse files.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE SMALL TEMP VIEWS FOR PRACTICE
-- ============================================================
-- TEMP VIEW data is session-scoped and is safe for practice.

CREATE OR REPLACE TEMP VIEW sales AS
SELECT * FROM VALUES
  (1, DATE '2026-01-05', 'Laptop',   'East', 1200.0, 1),
  (2, DATE '2026-01-10', 'Mouse',    'East',   80.0, 2),
  (3, DATE '2026-01-12', 'Keyboard', 'West',  160.0, 2),
  (4, DATE '2026-02-01', 'Laptop',   'West', 1300.0, 1),
  (5, DATE '2026-02-14', 'Mouse',    'South',  90.0, 3),
  (6, DATE '2026-02-20', 'Monitor',  'East',  500.0, 1),
  (7, DATE '2026-03-03', 'Laptop',   'South',1250.0, 1),
  (8, DATE '2026-03-09', 'Keyboard', 'East',  100.0, 1),
  (9, DATE '2026-03-12', 'Monitor',  'West',  550.0, 1),
  (10,DATE '2026-03-15', 'Mouse',    'West',   60.0, 1)
AS sales(order_id, order_date, product, region, revenue, quantity);

CREATE OR REPLACE TEMP VIEW admissions AS
SELECT * FROM VALUES
  (1001,1,TIMESTAMP '2026-01-10 08:00:00',TIMESTAMP '2026-01-14 12:00:00','Influenza'),
  (1001,2,TIMESTAMP '2026-02-01 09:00:00',TIMESTAMP '2026-02-04 10:00:00','Follow-up'),
  (1002,3,TIMESTAMP '2026-01-20 10:00:00',TIMESTAMP '2026-01-25 15:00:00','Fracture'),
  (1003,4,TIMESTAMP '2026-02-18 11:00:00',TIMESTAMP '2026-02-20 10:00:00','Asthma'),
  (1003,5,TIMESTAMP '2026-03-01 12:00:00',TIMESTAMP '2026-03-04 16:00:00','Asthma'),
  (1004,6,TIMESTAMP '2026-03-10 07:30:00',TIMESTAMP '2026-03-11 10:30:00','Hypertension')
AS admissions(subject_id, hadm_id, admit_ts, discharge_ts, diagnosis);

CREATE OR REPLACE TEMP VIEW survey_responses AS
SELECT * FROM VALUES
  (1,'ease',4),(1,'speed',5),(1,'trust',4),
  (2,'ease',3),(2,'speed',4),(2,'trust',3),
  (3,'ease',5),(3,'speed',5),(3,'trust',4),
  (4,'ease',2),(4,'speed',3),(4,'trust',2)
AS survey_responses(respondent_id, question, score);

CREATE OR REPLACE TEMP VIEW web_events AS
SELECT * FROM VALUES
  (1,TIMESTAMP '2026-01-01 09:00:00','view'),
  (1,TIMESTAMP '2026-01-01 09:05:00','click'),
  (1,TIMESTAMP '2026-01-01 09:20:00','purchase'),
  (2,TIMESTAMP '2026-01-02 10:00:00','view'),
  (2,TIMESTAMP '2026-01-02 10:30:00','click'),
  (3,TIMESTAMP '2026-01-03 11:00:00','view')
AS web_events(user_id, event_ts, event_type);

-- ============================================================
-- SECTION 2 - BASIC SPARK SQL
-- ============================================================

SELECT *
FROM sales
ORDER BY order_date, order_id;

SELECT product,
       SUM(revenue) AS total_revenue,
       SUM(quantity) AS units
FROM sales
GROUP BY product
ORDER BY total_revenue DESC;

SELECT region,
       COUNT(*) AS order_count,
       SUM(revenue) AS revenue
FROM sales
WHERE order_date >= DATE '2026-02-01'
GROUP BY region
ORDER BY revenue DESC;

-- ============================================================
-- SECTION 3 - CTEs AND WINDOWS STILL APPLY
-- ============================================================

WITH monthly_sales AS (
    SELECT DATE_TRUNC('month', order_date) AS sale_month,
           product,
           SUM(revenue) AS monthly_revenue
    FROM sales
    GROUP BY DATE_TRUNC('month', order_date), product
)
SELECT sale_month, product, monthly_revenue,
       RANK() OVER (
           PARTITION BY sale_month
           ORDER BY monthly_revenue DESC
       ) AS monthly_rank
FROM monthly_sales
ORDER BY sale_month, monthly_rank, product;

SELECT subject_id, hadm_id, admit_ts, discharge_ts,
       LAG(discharge_ts) OVER (
           PARTITION BY subject_id
           ORDER BY admit_ts, hadm_id
       ) AS previous_discharge
FROM admissions
ORDER BY subject_id, admit_ts, hadm_id;

SELECT user_id, event_ts, event_type,
       LAG(event_ts) OVER (
           PARTITION BY user_id
           ORDER BY event_ts
       ) AS previous_event_ts
FROM web_events
ORDER BY user_id, event_ts;

-- ============================================================
-- SECTION 4 - RESHAPING IN SPARK SQL
-- ============================================================

-- Conditional aggregation (portable and easy to read).
SELECT respondent_id,
       MAX(CASE WHEN question='ease'  THEN score END) AS ease,
       MAX(CASE WHEN question='speed' THEN score END) AS speed,
       MAX(CASE WHEN question='trust' THEN score END) AS trust
FROM survey_responses
GROUP BY respondent_id
ORDER BY respondent_id;

-- Spark SQL also supports PIVOT.
SELECT *
FROM (
    SELECT respondent_id, question, score
    FROM survey_responses
)
PIVOT (
    MAX(score)
    FOR question IN ('ease' AS ease, 'speed' AS speed, 'trust' AS trust)
)
ORDER BY respondent_id;

-- ============================================================
-- SECTION 5 - QUERY PLAN REASONING
-- ============================================================

EXPLAIN FORMATTED
SELECT region, SUM(revenue) AS revenue
FROM sales
WHERE order_date >= DATE '2026-02-01'
GROUP BY region;

-- Look for concepts such as:
--   Scan
--   Filter
--   HashAggregate
--   Exchange / shuffle
--
-- A GROUP BY on a distributed key often requires data exchange.

-- ============================================================
-- SECTION 6 - FILTER EARLY / REDUCE DATA
-- ============================================================

WITH filtered_sales AS (
    SELECT order_date, product, region, revenue
    FROM sales
    WHERE order_date >= DATE '2026-02-01'
      AND revenue > 100
)
SELECT region, SUM(revenue) AS revenue
FROM filtered_sales
GROUP BY region
ORDER BY revenue DESC;

-- ============================================================
-- SECTION 7 - LAKEHOUSE / DELTA EXAMPLES
-- ============================================================
-- The following examples require a lakehouse/catalog where you
-- have permission to create tables. Adjust names to your system.

-- CREATE TABLE curated_monthly_sales
-- USING DELTA
-- AS
-- SELECT DATE_TRUNC('month', order_date) AS sale_month,
--        product,
--        SUM(revenue) AS monthly_revenue
-- FROM sales
-- GROUP BY DATE_TRUNC('month', order_date), product;

-- DESCRIBE DETAIL curated_monthly_sales;

-- SELECT *
-- FROM curated_monthly_sales
-- ORDER BY sale_month, product;

-- ============================================================
-- SECTION 8 - FILE/TABLE WORKFLOW NOTES
-- ============================================================
-- Typical notebook workflow:
--
-- 1. Read CSV/Parquet/Delta with a DataFrame API.
-- 2. Apply or verify schema.
-- 3. Register a temporary view.
-- 4. Transform with Spark SQL.
-- 5. Validate row grain and totals.
-- 6. Write curated output as a Delta table.
--
-- Example PySpark from the module:
--   df = spark.read.format('csv').option('header','true').load('Files/sales.csv')
--   df.createOrReplaceTempView('sales_raw')
--   spark.sql('SELECT ... FROM sales_raw').show()
--
-- That is PySpark code, so it is intentionally not executable
-- inside this .sql file.

-- ============================================================
-- SECTION 9 - ADDITIONAL PRACTICE
-- ============================================================

-- PRACTICE 1
-- Return total revenue by product and region.

-- PRACTICE 2
-- Create one row per month and region with monthly revenue.

-- PRACTICE 3
-- Rank products by revenue inside each region.

-- PRACTICE 4
-- Use LAG to calculate the previous event time per web user.

-- PRACTICE 5
-- Use EXPLAIN FORMATTED on a GROUP BY query and identify where
-- Spark introduces an Exchange.

-- PRACTICE 6
-- Explain when a conventional PostgreSQL database may be a better
-- fit than Spark for the same business task.

-- ============================================================
-- MODULE 13 CHECKLIST
-- ============================================================
-- [ ] I can explain driver, executor, partition, task, and shuffle.
-- [ ] I understand SQL and DataFrames use the same Spark engine.
-- [ ] I know why explicit schemas can be safer than inference.
-- [ ] I can describe a lakehouse and Delta table at a high level.
-- [ ] I can inspect an execution plan.
-- [ ] I consider scan size and shuffle cost, not only SQL syntax.
-- [ ] I still verify row grain and business meaning.
-- ============================================================
