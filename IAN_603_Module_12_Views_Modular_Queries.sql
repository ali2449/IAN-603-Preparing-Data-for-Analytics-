-- ============================================================
-- IAN 603 - MODULE 12
-- Views & Modular Queries
-- ============================================================
-- Companion file for s_module12.html
-- PostgreSQL / pgAdmin Query Tool
--
-- HOW TO USE
-- 1. Run SECTION 1 to recreate the sample schema and views.
-- 2. Run later sections independently.
-- 3. Some examples intentionally demonstrate behavior such as
--    CHECK OPTION failures or stale materialized-view results.
--
-- CORE IDEAS
-- * Standard view: stored query definition; data stays live.
-- * View contract: column names, types, meaning, and row grain.
-- * Updatable view: some simple views can pass writes to base table.
-- * CHECK OPTION: prevents a write from making a row disappear
--   from the view's own predicate.
-- * Materialized view: stores query results and must be refreshed.
-- * Dependency: downstream objects depend on upstream definitions.
-- ============================================================

-- ============================================================
-- TABLE / OBJECT GUIDE
-- ============================================================
-- patients                 : one row per patient
-- admissions               : one row per hospital admission
-- departments              : one row per department
-- employees                : one row per employee
-- sales_orders             : one row per sales order
-- customer_transactions    : one row per transaction
-- analytics.vw_*           : reusable logical interfaces
-- analytics.mv_*           : stored analytical snapshot
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATA
-- ============================================================

DROP SCHEMA IF EXISTS analytics CASCADE;
DROP TABLE IF EXISTS customer_transactions CASCADE;
DROP TABLE IF EXISTS sales_orders CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

CREATE SCHEMA analytics;

CREATE TABLE patients (
  subject_id integer PRIMARY KEY,
  name text NOT NULL,
  date_of_birth date NOT NULL,
  gender text NOT NULL,
  email text,
  city text,
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE admissions (
  hadm_id integer PRIMARY KEY,
  subject_id integer NOT NULL REFERENCES patients(subject_id),
  admit_time timestamp NOT NULL,
  discharge_time timestamp,
  department text NOT NULL,
  diagnosis text NOT NULL
);

CREATE TABLE departments (
  department_id integer PRIMARY KEY,
  department_name text NOT NULL UNIQUE
);

CREATE TABLE employees (
  employee_id integer PRIMARY KEY,
  employee_name text NOT NULL,
  department_id integer NOT NULL REFERENCES departments(department_id),
  salary numeric(12,2) NOT NULL CHECK (salary > 0)
);

CREATE TABLE sales_orders (
  order_id integer PRIMARY KEY,
  employee_id integer NOT NULL REFERENCES employees(employee_id),
  order_date date NOT NULL,
  sale_amount numeric(12,2) NOT NULL CHECK (sale_amount >= 0)
);

CREATE TABLE customer_transactions (
  transaction_id integer PRIMARY KEY,
  customer_id integer NOT NULL,
  transaction_date date NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  status text NOT NULL CHECK (status IN ('completed','pending','cancelled'))
);

INSERT INTO patients VALUES
(1001,'Alice Smith','1980-04-16','Female','alice@example.org','Greensboro',true),
(1002,'Bob Johnson','1993-02-02','Male','bob@example.org','Greensboro',true),
(1003,'Carol White','1967-11-21','Female','carol@example.org','High Point',true),
(1004,'David Brown','1958-06-30','Male','david@example.org','Winston-Salem',false),
(1005,'Eve Davis','1996-09-08','Female','eve@example.org','Greensboro',true),
(1006,'Grace Wilson','1973-01-19','Female','grace@example.org','Burlington',true);

INSERT INTO admissions VALUES
(101,1001,'2025-01-10 08:00','2025-01-15 12:00','Internal Medicine','Influenza'),
(102,1002,'2025-02-01 14:00','2025-02-03 09:00','Orthopedics','Fracture'),
(103,1001,'2025-03-05 10:00','2025-03-12 15:00','Pulmonology','Pneumonia'),
(104,1003,'2025-04-10 07:00','2025-04-11 11:00','Cardiology','Hypertension'),
(105,1001,'2025-05-15 09:00','2025-05-20 14:00','Internal Medicine','Influenza'),
(106,1002,'2025-02-20 09:30','2025-02-22 10:00','Orthopedics','Follow-up'),
(107,1006,'2025-05-01 07:30','2025-05-04 11:30','Pulmonology','Asthma'),
(108,1006,'2025-05-25 10:00','2025-05-28 13:00','Pulmonology','Asthma');

INSERT INTO departments VALUES
(101,'Sales'),(102,'Marketing'),(103,'Analytics');

INSERT INTO employees VALUES
(1,'Jane Doe',101,92000),(2,'John Smith',101,78000),(3,'Emily Jones',102,81000),
(4,'Ravi Patel',103,99000),(5,'Mina Park',103,94000);

INSERT INTO sales_orders VALUES
(1,1,'2025-01-10',5000),(2,1,'2025-02-12',3000),(3,2,'2025-02-20',4000),
(4,3,'2025-03-05',2000),(5,4,'2025-03-20',6500),(6,4,'2025-04-11',3500);

INSERT INTO customer_transactions VALUES
(1,201,'2025-01-10',100,'completed'),(2,201,'2025-03-15',150,'completed'),
(3,202,'2025-02-01',200,'completed'),(4,203,'2024-12-01',80,'completed'),
(5,204,'2025-06-20',120,'completed'),(6,202,'2025-06-25',55,'pending');

CREATE VIEW analytics.vw_patient_admission_summary AS
SELECT
  p.subject_id,
  p.gender,
  p.city,
  a.hadm_id,
  a.admit_time,
  a.discharge_time,
  a.department,
  a.diagnosis,
  CASE WHEN a.discharge_time IS NULL THEN NULL
       ELSE ROUND(EXTRACT(EPOCH FROM (a.discharge_time - a.admit_time))/86400.0,2)
  END AS stay_days
FROM patients AS p
JOIN admissions AS a ON a.subject_id = p.subject_id;

CREATE VIEW analytics.vw_active_patients AS
SELECT subject_id, name, date_of_birth, gender, email, city, active
FROM patients
WHERE active = true
WITH LOCAL CHECK OPTION;

CREATE VIEW analytics.vw_patient_analytics AS
SELECT
  subject_id,
  CASE
    WHEN date_of_birth > DATE '1995-06-30' THEN 'Under 30'
    WHEN date_of_birth > DATE '1975-06-30' THEN '30-49'
    WHEN date_of_birth > DATE '1955-06-30' THEN '50-69'
    ELSE '70+'
  END AS age_band,
  city,
  active
FROM patients;

CREATE VIEW analytics.vw_employee_performance AS
SELECT
  e.employee_id,
  e.employee_name,
  d.department_name,
  COUNT(o.order_id) AS orders_processed,
  COALESCE(SUM(o.sale_amount),0)::numeric(12,2) AS total_sales
FROM employees AS e
JOIN departments AS d ON d.department_id = e.department_id
LEFT JOIN sales_orders AS o ON o.employee_id = e.employee_id
GROUP BY e.employee_id, e.employee_name, d.department_name;

CREATE VIEW analytics.vw_recent_customer_activity AS
SELECT customer_id, transaction_date, amount
FROM customer_transactions
WHERE status = 'completed'
  AND transaction_date >= DATE '2025-06-30' - INTERVAL '6 months';

CREATE MATERIALIZED VIEW analytics.mv_diagnosis_stats AS
SELECT
  diagnosis,
  COUNT(*) AS total_admissions,
  COUNT(DISTINCT subject_id) AS unique_patients,
  ROUND(AVG(CASE WHEN discharge_time IS NULL THEN NULL ELSE EXTRACT(EPOCH FROM (discharge_time - admit_time))/86400.0 END),2) AS avg_stay_days,
  clock_timestamp() AS refreshed_at
FROM admissions
GROUP BY diagnosis;

CREATE UNIQUE INDEX ux_mv_diagnosis_stats_diagnosis
ON analytics.mv_diagnosis_stats (diagnosis);

-- ============================================================
-- SECTION 2 - QUICK OBJECT CHECK
-- ============================================================
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('public','analytics')
ORDER BY table_schema, table_type, table_name;

SELECT table_schema, table_name
FROM information_schema.views
WHERE table_schema='analytics'
ORDER BY table_name;

SELECT schemaname, matviewname
FROM pg_matviews
WHERE schemaname='analytics'
ORDER BY matviewname;

-- ============================================================
-- SECTION 3 - VIEW CONTRACT CHECKS
-- ============================================================

-- Inspect the patient-admission interface.
SELECT *
FROM analytics.vw_patient_admission_summary
ORDER BY subject_id, admit_time;

-- Confirm its intended grain: one row per admission.
SELECT hadm_id, COUNT(*) AS rows_per_admission
FROM analytics.vw_patient_admission_summary
GROUP BY hadm_id
HAVING COUNT(*) > 1;

-- Summarize from the reusable view instead of rebuilding joins.
SELECT department,
       COUNT(*) AS admissions,
       COUNT(DISTINCT subject_id) AS unique_patients,
       ROUND(AVG(stay_days),2) AS avg_stay_days
FROM analytics.vw_patient_admission_summary
WHERE stay_days IS NOT NULL
GROUP BY department
ORDER BY admissions DESC, department;

-- ============================================================
-- SECTION 4 - MODULE 12 EXAMPLES
-- ============================================================

-- ------------------------------------------------------------
-- MODULE EXAMPLE 01: Explore source and analytics objects
-- ------------------------------------------------------------
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('public','analytics')
ORDER BY table_schema, table_type, table_name;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 02: Query patient-admission view
-- ------------------------------------------------------------
SELECT *
FROM analytics.vw_patient_admission_summary
ORDER BY subject_id, admit_time;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 03: Create or replace patient-admission view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_patient_admission_summary AS
SELECT
    p.subject_id, p.gender, p.city, a.hadm_id, a.admit_time, a.discharge_time,
    a.department, a.diagnosis,
    CASE WHEN a.discharge_time IS NULL THEN NULL
         ELSE ROUND(EXTRACT(EPOCH FROM (a.discharge_time - a.admit_time))/86400.0,2)
    END AS stay_days
FROM patients AS p
JOIN admissions AS a ON a.subject_id = p.subject_id;

SELECT * FROM analytics.vw_patient_admission_summary ORDER BY hadm_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 04: Aggregate from the shared view
-- ------------------------------------------------------------
SELECT department, COUNT(*) AS admissions, COUNT(DISTINCT subject_id) AS unique_patients, ROUND(AVG(stay_days),2) AS avg_stay_days
FROM analytics.vw_patient_admission_summary
WHERE stay_days IS NOT NULL
GROUP BY department
ORDER BY admissions DESC, department;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 05: Inspect standard view definitions
-- ------------------------------------------------------------
SELECT table_schema, table_name, view_definition
FROM information_schema.views
WHERE table_schema='analytics'
ORDER BY table_name;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 06: Inspect view-table usage
-- ------------------------------------------------------------
SELECT view_schema, view_name, table_schema, table_name
FROM information_schema.view_table_usage
WHERE view_schema='analytics'
ORDER BY view_name, table_name;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 07: Update an active patient through the view
-- ------------------------------------------------------------
BEGIN;
UPDATE analytics.vw_active_patients
SET city='High Point'
WHERE subject_id=1002
RETURNING subject_id,name,city,active;
ROLLBACK;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 08: Intentional CHECK OPTION failure
-- ------------------------------------------------------------
UPDATE analytics.vw_active_patients
SET active=false
WHERE subject_id=1002;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 09: Limited patient analytics interface
-- ------------------------------------------------------------
SELECT * FROM analytics.vw_patient_analytics ORDER BY subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 10: security_invoker view option
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_patient_analytics
WITH (security_invoker=true) AS
SELECT subject_id,
       CASE WHEN date_of_birth > DATE '1995-06-30' THEN 'Under 30'
            WHEN date_of_birth > DATE '1975-06-30' THEN '30-49'
            WHEN date_of_birth > DATE '1955-06-30' THEN '50-69'
            ELSE '70+' END AS age_band,
       city, active
FROM patients;

SELECT * FROM analytics.vw_patient_analytics ORDER BY subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 11: Create diagnosis materialized view
-- ------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_diagnosis_stats;
CREATE MATERIALIZED VIEW analytics.mv_diagnosis_stats AS
SELECT diagnosis, COUNT(*) AS total_admissions, COUNT(DISTINCT subject_id) AS unique_patients,
       ROUND(AVG(CASE WHEN discharge_time IS NULL THEN NULL ELSE EXTRACT(EPOCH FROM (discharge_time-admit_time))/86400.0 END),2) AS avg_stay_days,
       clock_timestamp() AS refreshed_at
FROM admissions
GROUP BY diagnosis;
SELECT * FROM analytics.mv_diagnosis_stats ORDER BY total_admissions DESC, diagnosis;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 12: Query diagnosis snapshot
-- ------------------------------------------------------------
SELECT * FROM analytics.mv_diagnosis_stats ORDER BY total_admissions DESC, diagnosis;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 13: Live data versus materialized snapshot
-- ------------------------------------------------------------
INSERT INTO admissions(hadm_id,subject_id,admit_time,discharge_time,department,diagnosis)
VALUES(999,1005,'2025-06-20 09:00','2025-06-22 10:00','Internal Medicine','Influenza')
ON CONFLICT(hadm_id) DO NOTHING;

SELECT 'live admissions' AS source, COUNT(*) AS influenza_rows
FROM admissions WHERE diagnosis='Influenza'
UNION ALL
SELECT 'materialized snapshot', COALESCE(MAX(total_admissions),0)
FROM analytics.mv_diagnosis_stats WHERE diagnosis='Influenza';


-- ------------------------------------------------------------
-- MODULE EXAMPLE 14: Refresh diagnosis snapshot
-- ------------------------------------------------------------
REFRESH MATERIALIZED VIEW analytics.mv_diagnosis_stats;
SELECT diagnosis,total_admissions,unique_patients,avg_stay_days,refreshed_at
FROM analytics.mv_diagnosis_stats
WHERE diagnosis='Influenza';


-- ------------------------------------------------------------
-- MODULE EXAMPLE 15: Create materialized-view index
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_diagnosis_stats_diagnosis ON analytics.mv_diagnosis_stats(diagnosis);
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='analytics' AND tablename='mv_diagnosis_stats';


-- ------------------------------------------------------------
-- MODULE EXAMPLE 16: Compare live and materialized counts
-- ------------------------------------------------------------
SELECT 'live' AS object_type, diagnosis, COUNT(*)::bigint AS admissions
FROM admissions GROUP BY diagnosis
UNION ALL
SELECT 'materialized', diagnosis, total_admissions
FROM analytics.mv_diagnosis_stats
ORDER BY diagnosis, object_type;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 17: Readmission analysis from shared view
-- ------------------------------------------------------------
WITH sequenced AS (
  SELECT subject_id,hadm_id,admit_time,
         LAG(discharge_time) OVER(PARTITION BY subject_id ORDER BY admit_time,hadm_id) AS previous_discharge
  FROM analytics.vw_patient_admission_summary
), readmissions AS (
  SELECT *, admit_time-previous_discharge AS gap
  FROM sequenced WHERE previous_discharge IS NOT NULL
)
SELECT subject_id,hadm_id,gap,gap<=INTERVAL '30 days' AS within_30_days
FROM readmissions ORDER BY subject_id,hadm_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 18: Create employee performance view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_employee_performance AS
SELECT e.employee_id,e.employee_name,d.department_name,COUNT(o.order_id) AS orders_processed,
       COALESCE(SUM(o.sale_amount),0)::numeric(12,2) AS total_sales
FROM employees e
JOIN departments d ON d.department_id=e.department_id
LEFT JOIN sales_orders o ON o.employee_id=e.employee_id
GROUP BY e.employee_id,e.employee_name,d.department_name;
SELECT * FROM analytics.vw_employee_performance ORDER BY total_sales DESC,employee_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 19: Query top performers
-- ------------------------------------------------------------
SELECT * FROM analytics.vw_employee_performance WHERE total_sales>=5000 ORDER BY total_sales DESC;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 20: Create recent customer activity view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_recent_customer_activity AS
SELECT customer_id,transaction_date,amount
FROM customer_transactions
WHERE status='completed' AND transaction_date>=DATE '2025-06-30'-INTERVAL '6 months';
SELECT * FROM analytics.vw_recent_customer_activity ORDER BY customer_id,transaction_date;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 21: Retention analysis CTE
-- ------------------------------------------------------------
WITH last_activity AS (
  SELECT customer_id,MAX(transaction_date) AS last_transaction
  FROM analytics.vw_recent_customer_activity GROUP BY customer_id
), at_risk AS (
  SELECT customer_id,last_transaction,DATE '2025-06-30'-last_transaction AS days_inactive
  FROM last_activity WHERE last_transaction<DATE '2025-06-30'-60
)
SELECT * FROM at_risk ORDER BY days_inactive DESC,customer_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 22: Catalog analytics objects
-- ------------------------------------------------------------
SELECT schemaname AS object_schema, viewname AS object_name, 'view' AS object_type
FROM pg_views WHERE schemaname='analytics'
UNION ALL
SELECT schemaname,matviewname,'materialized view'
FROM pg_matviews WHERE schemaname='analytics'
ORDER BY object_type,object_name;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 23: Assessment starter
-- ------------------------------------------------------------
-- Create analytics.vw_employee_department_info with:
-- employee_name, salary, department_name

-- Then query only that view to calculate
-- average salary for the Sales department.;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 24: Sample solution
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_employee_department_info AS
SELECT e.employee_name,e.salary,d.department_name
FROM employees e
JOIN departments d ON d.department_id=e.department_id;

SELECT department_name,ROUND(AVG(salary),2) AS avg_salary
FROM analytics.vw_employee_department_info
WHERE department_name='Sales'
GROUP BY department_name;


-- ============================================================
-- SECTION 5 - DEPENDENCY AND METADATA CHECKS
-- ============================================================

SELECT view_schema, view_name, table_schema, table_name
FROM information_schema.view_table_usage
WHERE view_schema='analytics'
ORDER BY view_name, table_name;

SELECT schemaname, viewname, definition
FROM pg_views
WHERE schemaname='analytics'
ORDER BY viewname;

SELECT schemaname, matviewname, ispopulated, definition
FROM pg_matviews
WHERE schemaname='analytics'
ORDER BY matviewname;

-- ============================================================
-- SECTION 6 - MATERIALIZED VIEW FRESHNESS
-- ============================================================

-- Compare the live source with the stored snapshot.
SELECT diagnosis, COUNT(*) AS live_admissions
FROM admissions
GROUP BY diagnosis
ORDER BY diagnosis;

SELECT diagnosis, total_admissions, refreshed_at
FROM analytics.mv_diagnosis_stats
ORDER BY diagnosis;

-- Refresh when the project requires a current snapshot.
REFRESH MATERIALIZED VIEW analytics.mv_diagnosis_stats;

SELECT diagnosis, total_admissions, refreshed_at
FROM analytics.mv_diagnosis_stats
ORDER BY diagnosis;

-- ============================================================
-- SECTION 7 - ADDITIONAL PRACTICE
-- ============================================================

-- PRACTICE 1
-- Create a view with one row per employee containing:
-- employee_id, employee_name, department_name, order_count,
-- and total_sales.

-- PRACTICE 2
-- Create a restricted patient analytics view that excludes email
-- and exposes only subject_id, age_band, city, and active.

-- PRACTICE 3
-- Query information_schema to identify which base tables are used
-- by each view in the analytics schema.

-- PRACTICE 4
-- Explain when a standard view is preferable to a materialized view.

-- PRACTICE 5
-- Add a row to a base table, compare live vs materialized results,
-- refresh, and compare again.

-- ============================================================
-- MODULE 12 CHECKLIST
-- ============================================================
-- [ ] I can describe a view as an interface/contract.
-- [ ] I know that standard views are live queries.
-- [ ] I understand CHECK OPTION.
-- [ ] I know why privileges still matter with views.
-- [ ] I can explain materialized-view staleness.
-- [ ] I can define an appropriate refresh policy.
-- [ ] I inspect dependencies before changing shared objects.
-- ============================================================
