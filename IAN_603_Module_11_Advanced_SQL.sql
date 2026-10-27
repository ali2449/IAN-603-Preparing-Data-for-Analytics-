-- ============================================================
-- IAN 603 - MODULE 11
-- Advanced SQL: CTEs & Window Functions
-- ============================================================
-- Companion file for s_module11.html
-- PostgreSQL / pgAdmin Query Tool
--
-- HOW TO USE
-- 1. Run SECTION 1 once to reset the teaching database.
-- 2. Run examples one at a time while following Module 11.
-- 3. Pay attention to grain, PARTITION BY, ORDER BY, and frames.
-- 4. Re-run SECTION 1 whenever you want a clean starting point.
--
-- CORE IDEAS
-- * CTE: names an intermediate result for one statement.
-- * Recursive CTE: repeatedly expands from an anchor query.
-- * Window function: adds context without collapsing the row.
-- * PARTITION BY: defines independent groups for a window.
-- * ORDER BY: defines sequence inside a window.
-- * Frame: defines which ordered rows participate in a calculation.
-- ============================================================

-- ============================================================
-- TABLE / GRAIN GUIDE
-- ============================================================
-- patients        : one row per patient
-- admissions      : one row per hospital admission
-- employees       : one row per employee; manager_id forms hierarchy
-- sales           : one row per sales transaction
-- website_visits  : one row per website visit
--
-- Important:
-- GROUP BY usually changes row grain.
-- Window functions usually keep the existing row grain.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATA
-- ============================================================

DROP TABLE IF EXISTS website_visits CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

CREATE TABLE patients (
  subject_id integer PRIMARY KEY,
  name text NOT NULL,
  age integer NOT NULL CHECK (age >= 0)
);

CREATE TABLE admissions (
  hadm_id integer PRIMARY KEY,
  subject_id integer NOT NULL REFERENCES patients(subject_id),
  admit_time timestamp NOT NULL,
  discharge_time timestamp,
  department text NOT NULL,
  diagnosis text NOT NULL
);

CREATE TABLE employees (
  employee_id integer PRIMARY KEY,
  employee_name text NOT NULL,
  department text NOT NULL,
  salary numeric(10,2) NOT NULL CHECK (salary > 0),
  manager_id integer REFERENCES employees(employee_id)
);

CREATE TABLE sales (
  sale_id integer PRIMARY KEY,
  sale_date date NOT NULL,
  product text NOT NULL,
  department text NOT NULL,
  revenue numeric(10,2) NOT NULL CHECK (revenue >= 0)
);

CREATE TABLE website_visits (
  visit_id integer PRIMARY KEY,
  user_id integer NOT NULL,
  visit_timestamp timestamp NOT NULL
);

INSERT INTO patients VALUES
(1001,'Alice Smith',45),(1002,'Bob Johnson',32),(1003,'Carol White',58),
(1004,'David Brown',67),(1005,'Eve Davis',29),(1006,'Grace Wilson',52);

INSERT INTO admissions VALUES
(101,1001,'2025-01-10 08:00','2025-01-15 12:00','Cardiology','Pneumonia'),
(102,1002,'2025-02-01 14:00','2025-02-03 09:00','Orthopedics','Fracture'),
(103,1001,'2025-03-05 10:00','2025-03-12 15:00','Internal Medicine','Hypertension'),
(104,1003,'2025-04-10 07:00','2025-04-11 11:00','Neurology','Migraine'),
(105,1001,'2025-05-15 09:00','2025-05-20 14:00','Cardiology','Chest pain'),
(106,1002,'2025-02-20 09:30','2025-02-22 10:00','Orthopedics','Follow-up'),
(107,1006,'2025-05-01 07:30','2025-05-04 11:30','Internal Medicine','Asthma'),
(108,1006,'2025-05-25 10:00','2025-05-28 13:00','Internal Medicine','Asthma');

INSERT INTO employees VALUES
(1,'Nora Patel','Executive',150000,NULL),
(2,'Amir Chen','Analytics',125000,1),
(3,'Beth Morgan','Analytics',125000,1),
(4,'Chen Wu','Analytics',95000,2),
(5,'Dana Ruiz','Analytics',95000,2),
(6,'Eli Brooks','Engineering',115000,1),
(7,'Fatima Noor','Engineering',105000,6),
(8,'Gio Rossi','Engineering',105000,6),
(9,'Hana Kim','IT',85000,1);

INSERT INTO sales VALUES
(1,'2025-01-01','Laptop','Electronics',1000),
(2,'2025-01-01','Monitor','Electronics',1000),
(3,'2025-01-02','Laptop','Electronics',1200),
(4,'2025-01-02','Mouse','Accessories',200),
(5,'2025-01-03','Keyboard','Accessories',300),
(6,'2025-01-03','Mouse','Accessories',300),
(7,'2025-01-04','Laptop','Electronics',1500),
(8,'2025-01-04','Monitor','Electronics',1300),
(9,'2025-01-05','Mouse','Accessories',400),
(10,'2025-01-05','Keyboard','Accessories',400);

INSERT INTO website_visits VALUES
(1,501,'2025-06-01 08:00'),(2,501,'2025-06-01 10:30'),(3,501,'2025-06-02 09:15'),
(4,502,'2025-06-01 11:00'),(5,502,'2025-06-03 14:00'),(6,503,'2025-06-02 16:20');

-- ============================================================
-- SECTION 2 - QUICK DATA CHECK
-- ============================================================
SELECT COUNT(*) AS patients FROM patients;
SELECT COUNT(*) AS admissions FROM admissions;
SELECT COUNT(*) AS employees FROM employees;
SELECT COUNT(*) AS sales FROM sales;
SELECT COUNT(*) AS website_visits FROM website_visits;

-- Inspect the base tables before using advanced SQL.
SELECT * FROM patients ORDER BY subject_id;
SELECT * FROM admissions ORDER BY subject_id, admit_time;
SELECT * FROM employees ORDER BY employee_id;
SELECT * FROM sales ORDER BY sale_date, sale_id;
SELECT * FROM website_visits ORDER BY user_id, visit_timestamp;

-- ============================================================
-- SECTION 3 - CTE PATTERN REMINDERS
-- ============================================================
-- One CTE:
WITH patient_admission_counts AS (
    SELECT subject_id, COUNT(*) AS admission_count
    FROM admissions
    GROUP BY subject_id
)
SELECT p.subject_id, p.name,
       COALESCE(c.admission_count,0) AS admission_count
FROM patients AS p
LEFT JOIN patient_admission_counts AS c USING (subject_id)
ORDER BY p.subject_id;

-- Chained CTEs: each step has one clear responsibility.
WITH daily_sales AS (
    SELECT sale_date, department, SUM(revenue) AS daily_revenue
    FROM sales
    GROUP BY sale_date, department
),
department_totals AS (
    SELECT department, SUM(daily_revenue) AS department_revenue
    FROM daily_sales
    GROUP BY department
)
SELECT *
FROM department_totals
ORDER BY department_revenue DESC;

-- ============================================================
-- SECTION 4 - WINDOW FUNCTION PATTERN REMINDERS
-- ============================================================
-- Ranking inside each department.
SELECT employee_id, employee_name, department, salary,
       ROW_NUMBER() OVER (
           PARTITION BY department
           ORDER BY salary DESC, employee_id
       ) AS row_num,
       RANK() OVER (
           PARTITION BY department
           ORDER BY salary DESC
       ) AS salary_rank,
       DENSE_RANK() OVER (
           PARTITION BY department
           ORDER BY salary DESC
       ) AS dense_salary_rank
FROM employees
ORDER BY department, salary DESC, employee_id;

-- Previous row in a patient sequence.
SELECT subject_id, hadm_id, admit_time,
       LAG(discharge_time) OVER (
           PARTITION BY subject_id
           ORDER BY admit_time, hadm_id
       ) AS previous_discharge
FROM admissions
ORDER BY subject_id, admit_time, hadm_id;

-- Running total with an explicit frame.
SELECT sale_id, sale_date, product, revenue,
       SUM(revenue) OVER (
           ORDER BY sale_date, sale_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_revenue
FROM sales
ORDER BY sale_date, sale_id;

-- ============================================================
-- SECTION 5 - MODULE 11 EXAMPLES
-- ============================================================

-- ------------------------------------------------------------
-- MODULE EXAMPLE 01: Older patients CTE
-- ------------------------------------------------------------
WITH older_patients AS (
    SELECT subject_id, name, age
    FROM patients
    WHERE age > 50
)
SELECT op.subject_id, op.name, op.age, COUNT(a.hadm_id) AS admission_count
FROM older_patients AS op
LEFT JOIN admissions AS a ON a.subject_id = op.subject_id
GROUP BY op.subject_id, op.name, op.age
ORDER BY op.age DESC;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 02: Chained CTEs
-- ------------------------------------------------------------
WITH admission_counts AS (
    SELECT subject_id, COUNT(*) AS admission_count
    FROM admissions
    GROUP BY subject_id
),
patient_features AS (
    SELECT p.subject_id, p.name, p.age, COALESCE(a.admission_count,0) AS admission_count
    FROM patients AS p
    LEFT JOIN admission_counts AS a USING (subject_id)
)
SELECT *,
       CASE WHEN admission_count >= 2 THEN 'repeat' ELSE 'single_or_none' END AS visit_pattern
FROM patient_features
ORDER BY admission_count DESC, subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 03: Prepare stay days, then summarize
-- ------------------------------------------------------------
WITH stay_days AS (
    SELECT hadm_id, subject_id, department,
           EXTRACT(EPOCH FROM (discharge_time - admit_time))/86400.0 AS stay_days
    FROM admissions
    WHERE discharge_time IS NOT NULL
)
SELECT p.name, COUNT(s.hadm_id) AS admissions, ROUND(AVG(s.stay_days),2) AS avg_stay_days
FROM patients AS p
LEFT JOIN stay_days AS s USING (subject_id)
GROUP BY p.subject_id, p.name
ORDER BY admissions DESC, p.subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 04: EXPLAIN a CTE query
-- ------------------------------------------------------------
EXPLAIN
WITH older_patients AS (
    SELECT * FROM patients WHERE age > 50
)
SELECT * FROM older_patients WHERE subject_id > 1002;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 05: Recursive organization traversal
-- ------------------------------------------------------------
WITH RECURSIVE org AS (
    SELECT employee_id, employee_name, manager_id, 0 AS depth, employee_name::text AS path
    FROM employees
    WHERE manager_id IS NULL
  UNION ALL
    SELECT e.employee_id, e.employee_name, e.manager_id, o.depth + 1,
           o.path || ' > ' || e.employee_name
    FROM employees AS e
    JOIN org AS o ON e.manager_id = o.employee_id
)
SELECT employee_id, employee_name, manager_id, depth, path
FROM org
ORDER BY path;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 06: Average salary and row number
-- ------------------------------------------------------------
SELECT employee_id, employee_name, department, salary,
       AVG(salary) OVER (PARTITION BY department) AS department_avg_salary,
       ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, employee_id) AS row_num
FROM employees
ORDER BY department, row_num;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 07: ROW_NUMBER vs RANK vs DENSE_RANK
-- ------------------------------------------------------------
SELECT employee_name, department, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, employee_id) AS row_number,
       RANK() OVER (ORDER BY salary DESC) AS rank,
       DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rank
FROM employees
ORDER BY salary DESC, employee_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 08: Department salary ranks
-- ------------------------------------------------------------
SELECT employee_name, department, salary,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank
FROM employees
ORDER BY department, salary_rank, employee_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 09: Previous discharge with LAG
-- ------------------------------------------------------------
WITH sequenced AS (
    SELECT hadm_id, subject_id, admit_time, discharge_time,
           LAG(discharge_time) OVER (PARTITION BY subject_id ORDER BY admit_time, hadm_id) AS previous_discharge
    FROM admissions
)
SELECT hadm_id, subject_id, admit_time, previous_discharge,
       admit_time - previous_discharge AS time_since_discharge
FROM sequenced
WHERE previous_discharge IS NOT NULL
ORDER BY subject_id, admit_time;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 10: Next visit with LEAD
-- ------------------------------------------------------------
SELECT user_id, visit_timestamp,
       LEAD(visit_timestamp) OVER (PARTITION BY user_id ORDER BY visit_timestamp, visit_id) AS next_visit,
       LEAD(visit_timestamp) OVER (PARTITION BY user_id ORDER BY visit_timestamp, visit_id) - visit_timestamp AS time_to_next_visit
FROM website_visits
ORDER BY user_id, visit_timestamp;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 11: Running department revenue
-- ------------------------------------------------------------
WITH daily AS (
    SELECT sale_date, department, SUM(revenue) AS daily_revenue
    FROM sales
    GROUP BY sale_date, department
)
SELECT sale_date, department, daily_revenue,
       SUM(daily_revenue) OVER (
           PARTITION BY department
           ORDER BY sale_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_revenue
FROM daily
ORDER BY department, sale_date;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 12: Three-row moving average
-- ------------------------------------------------------------
WITH daily AS (
    SELECT sale_date, SUM(revenue) AS daily_revenue
    FROM sales
    GROUP BY sale_date
)
SELECT sale_date, daily_revenue,
       ROUND(AVG(daily_revenue) OVER (
           ORDER BY sale_date
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ),2) AS moving_avg_3_rows
FROM daily
ORDER BY sale_date;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 13: Explicit cumulative frame
-- ------------------------------------------------------------
SELECT sale_id, sale_date, product, revenue,
       SUM(revenue) OVER (
           ORDER BY sale_date, sale_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_revenue
FROM sales
ORDER BY sale_date, sale_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 14: LAST_VALUE frame behavior
-- ------------------------------------------------------------
SELECT sale_id, sale_date, revenue,
       LAST_VALUE(revenue) OVER (ORDER BY sale_date, sale_id) AS default_frame_last_value,
       LAST_VALUE(revenue) OVER (
           ORDER BY sale_date, sale_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS partition_last_value
FROM sales
ORDER BY sale_date, sale_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 15: Average stay with GROUP BY
-- ------------------------------------------------------------
SELECT subject_id,
       ROUND(AVG(EXTRACT(EPOCH FROM (discharge_time-admit_time))/86400.0),2) AS avg_stay_days
FROM admissions
WHERE discharge_time IS NOT NULL
GROUP BY subject_id
ORDER BY subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 16: Average stay with PARTITION BY
-- ------------------------------------------------------------
SELECT hadm_id, subject_id, admit_time,
       ROUND(EXTRACT(EPOCH FROM (discharge_time-admit_time))/86400.0,2) AS stay_days,
       ROUND(AVG(EXTRACT(EPOCH FROM (discharge_time-admit_time))/86400.0)
             OVER (PARTITION BY subject_id),2) AS patient_avg_stay_days
FROM admissions
WHERE discharge_time IS NOT NULL
ORDER BY subject_id, admit_time;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 17: GROUP BY vs PARTITION BY row counts
-- ------------------------------------------------------------
SELECT 'GROUP BY' AS method, COUNT(*) AS output_rows
FROM (
  SELECT subject_id, AVG(discharge_time-admit_time)
  FROM admissions
  GROUP BY subject_id
) AS g
UNION ALL
SELECT 'PARTITION BY', COUNT(*)
FROM (
  SELECT hadm_id, AVG(discharge_time-admit_time) OVER (PARTITION BY subject_id)
  FROM admissions
) AS w;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 18: Percent of all revenue
-- ------------------------------------------------------------
SELECT sale_id, product, revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (),2) AS percent_of_all_revenue
FROM sales
ORDER BY revenue DESC, sale_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 19: Top two salaries per department
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT employee_id, employee_name, department, salary,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, employee_id) AS rn
    FROM employees
)
SELECT employee_id, employee_name, department, salary, rn
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 20: Top salary ranks including ties
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT employee_id, employee_name, department, salary,
           RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT employee_id, employee_name, department, salary, salary_rank
FROM ranked
WHERE salary_rank <= 2
ORDER BY department, salary_rank, employee_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 21: Top products within department
-- ------------------------------------------------------------
WITH product_totals AS (
    SELECT department, product, SUM(revenue) AS product_revenue
    FROM sales
    GROUP BY department, product
),
ranked AS (
    SELECT department, product, product_revenue,
           DENSE_RANK() OVER (PARTITION BY department ORDER BY product_revenue DESC) AS revenue_rank
    FROM product_totals
)
SELECT department, product, product_revenue, revenue_rank
FROM ranked
WHERE revenue_rank <= 2
ORDER BY department, revenue_rank, product;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 22: Readmission interval analysis
-- ------------------------------------------------------------
WITH sequenced AS (
    SELECT a.*,
           LAG(discharge_time) OVER (PARTITION BY subject_id ORDER BY admit_time, hadm_id) AS previous_discharge
    FROM admissions AS a
),
intervals AS (
    SELECT hadm_id, subject_id, admit_time, previous_discharge,
           admit_time - previous_discharge AS gap
    FROM sequenced
    WHERE previous_discharge IS NOT NULL
)
SELECT p.name, i.hadm_id, i.admit_time, i.previous_discharge, i.gap,
       CASE WHEN i.gap <= INTERVAL '30 days' THEN 'within_30_days' ELSE 'over_30_days' END AS readmission_flag
FROM intervals AS i
JOIN patients AS p USING (subject_id)
ORDER BY p.name, i.admit_time;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 23: Assessment starter
-- ------------------------------------------------------------
-- Task: return the two longest stays for each department.
-- Preserve admission-level detail and break exact ties deterministically.
WITH ranked AS (
    SELECT hadm_id, subject_id, department, admit_time, discharge_time,
           EXTRACT(EPOCH FROM (discharge_time-admit_time))/86400.0 AS stay_days,
           ROW_NUMBER() OVER (
               PARTITION BY department
               ORDER BY (discharge_time-admit_time) DESC, hadm_id
           ) AS rn
    FROM admissions
    WHERE discharge_time IS NOT NULL
)
SELECT *
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;


-- ============================================================
-- SECTION 6 - VALIDATION / REASONING CHECKS
-- ============================================================

-- Compare GROUP BY output grain with window output grain.
SELECT COUNT(*) AS source_admission_rows FROM admissions;

SELECT COUNT(*) AS grouped_patient_rows
FROM (
    SELECT subject_id, COUNT(*)
    FROM admissions
    GROUP BY subject_id
) AS g;

SELECT COUNT(*) AS window_output_rows
FROM (
    SELECT hadm_id, subject_id,
           COUNT(*) OVER (PARTITION BY subject_id) AS patient_admissions
    FROM admissions
) AS w;

-- Verify that ranking ties behave differently.
SELECT employee_name, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, employee_id) AS row_number,
       RANK() OVER (ORDER BY salary DESC) AS rank_value,
       DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rank_value
FROM employees
ORDER BY salary DESC, employee_id;

-- Verify that a running total ends at the grand total.
WITH running AS (
    SELECT sale_id,
           SUM(revenue) OVER (
               ORDER BY sale_date, sale_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS running_revenue
    FROM sales
)
SELECT MAX(running_revenue) AS final_running_total,
       (SELECT SUM(revenue) FROM sales) AS source_total
FROM running;

-- ============================================================
-- SECTION 7 - ADDITIONAL PRACTICE
-- ============================================================

-- PRACTICE 1
-- Return patients age 50 or older and their admission counts.
-- Use a CTE for the filtered patients.

-- PRACTICE 2
-- Return the top 2 employees by salary inside each department.
-- First use ROW_NUMBER, then repeat with RANK. Compare ties.

-- PRACTICE 3
-- For each admission, show the previous admission date for the
-- same patient and calculate the number of days between visits.

-- PRACTICE 4
-- Aggregate sales to one row per day, then calculate a 3-row
-- moving average over daily revenue.

-- PRACTICE 5
-- Use a recursive CTE to display employee hierarchy depth.

-- ============================================================
-- MODULE 11 CHECKLIST
-- ============================================================
-- [ ] I can explain why a CTE improves readability.
-- [ ] I know when recursion is appropriate.
-- [ ] I can distinguish GROUP BY from PARTITION BY.
-- [ ] I can choose ROW_NUMBER, RANK, or DENSE_RANK.
-- [ ] I can use LAG and LEAD with a meaningful ordering.
-- [ ] I can explain a window frame.
-- [ ] I verify output grain after advanced queries.
-- ============================================================
