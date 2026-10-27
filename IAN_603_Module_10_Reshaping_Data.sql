-- ============================================================
-- IAN 603 - MODULE 10
-- Reshaping Data in PostgreSQL
-- ============================================================
-- Companion file for:
-- s_module10.html
--
-- Designed for PostgreSQL and pgAdmin Query Tool.
--
-- This file is intentionally more detailed than the slides.
-- It includes:
--   1. Teaching database setup
--   2. Table/grain explanations
--   3. Pivot examples
--   4. Unpivot examples
--   5. NULL and grain checks
--   6. Validation queries
--   7. Module practice queries
--   8. Additional optional practice
--
-- HOW TO USE
-- ------------------------------------------------------------
-- 1. Open pgAdmin.
-- 2. Open Query Tool for your practice database.
-- 3. Run SECTION 1 once to create/reset the teaching tables.
-- 4. Run later examples one at a time while following Module 10.
-- 5. Re-run SECTION 1 whenever you want a clean starting point.
--
-- NOTE
-- ------------------------------------------------------------
-- SECTION 1 uses DROP TABLE IF EXISTS. It is intended for a
-- practice database, not a production database.
-- ============================================================


-- ============================================================
-- TABLE GUIDE
-- ============================================================
--
-- patients
--   Grain: one row per patient.
--   Used to demonstrate preserving all patients with LEFT JOIN.
--
-- admissions
--   Grain: one row per hospital admission.
--   Useful dimensions: diagnosis, department, admit_time.
--   Useful measure: admission count.
--
-- sales
--   Grain: one row per sales transaction.
--   Useful dimensions: product, category, sale_month.
--   Measure: revenue.
--   Important: several transactions can belong to the same
--   product-month, so aggregation is required before/pivoting.
--
-- survey_responses
--   Grain: one row per respondent-question.
--   Used for converting question values into separate columns.
--
-- monthly_sales
--   Grain: one row per product.
--   Jan/Feb/Mar are stored as separate columns, so this table
--   begins in wide form and is useful for unpivot examples.
--
-- patient_metrics
--   Grain: one row per patient.
--   Several measurements are stored in columns. This is another
--   wide-form table used for LATERAL VALUES unpivot examples.
--
-- students
--   Grain: one row per student.
--
-- grades
--   Grain: one row per student-course.
--   Used for building a grade matrix with course columns.
--
-- Key idea:
--   Always state the source grain and target grain before writing
--   a reshape query. A pivot often changes the row grain.



-- ============================================================
-- QUICK CONCEPT NOTES
-- ============================================================
--
-- LONG FORM
--   Repeated categories are stored as row values.
--   Example:
--     product | sale_month | revenue
--
-- WIDE FORM
--   Selected category values become columns.
--   Example:
--     product | jan_revenue | feb_revenue | mar_revenue
--
-- PIVOT IN POSTGRESQL
--   PostgreSQL does not have a core PIVOT keyword.
--   In this module, use conditional aggregation:
--
--     SUM(revenue) FILTER (WHERE condition)
--
--   or:
--
--     SUM(CASE WHEN condition THEN revenue END)
--
-- UNPIVOT IN POSTGRESQL
--   PostgreSQL does not have a core UNPIVOT keyword.
--   Common patterns:
--     1. UNION ALL
--     2. CROSS JOIN LATERAL with VALUES
--
-- NULL VS ZERO
--   NULL often means no recorded observation.
--   Zero means a real observed value of zero.
--   Do not replace NULL with zero unless the business meaning
--   supports that interpretation.
--
-- VALIDATION
--   After reshaping, compare:
--     * row grain
--     * row counts
--     * total measures
--     * expected categories
--     * NULL behavior


-- ============================================================
-- SECTION 1 - CREATE / RESET THE MODULE 10 TEACHING DATABASE
-- ============================================================
-- The commands below recreate the same small datasets used by
-- the interactive Module 10 page.
-- ============================================================

DROP TABLE IF EXISTS grades CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS patient_metrics CASCADE;
DROP TABLE IF EXISTS monthly_sales CASCADE;
DROP TABLE IF EXISTS survey_responses CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

CREATE TABLE patients (
  subject_id integer PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE admissions (
  hadm_id integer PRIMARY KEY,
  subject_id integer NOT NULL REFERENCES patients(subject_id),
  admit_time timestamp NOT NULL,
  diagnosis text NOT NULL,
  department text NOT NULL
);

CREATE TABLE sales (
  sale_id integer PRIMARY KEY,
  product text NOT NULL,
  category text NOT NULL,
  sale_month date NOT NULL,
  revenue numeric(10,2) NOT NULL CHECK (revenue >= 0)
);

CREATE TABLE survey_responses (
  respondent_id integer NOT NULL,
  question text NOT NULL,
  score integer CHECK (score BETWEEN 1 AND 5),
  PRIMARY KEY (respondent_id, question)
);

CREATE TABLE monthly_sales (
  product text PRIMARY KEY,
  jan_revenue numeric(10,2),
  feb_revenue numeric(10,2),
  mar_revenue numeric(10,2)
);

CREATE TABLE patient_metrics (
  patient_id integer PRIMARY KEY,
  heart_rate integer,
  systolic_bp integer,
  diastolic_bp integer,
  oxygen_sat numeric(5,2)
);

CREATE TABLE students (
  student_id integer PRIMARY KEY,
  student_name text NOT NULL
);

CREATE TABLE grades (
  student_id integer REFERENCES students(student_id),
  course_code text NOT NULL,
  grade numeric(5,2),
  PRIMARY KEY (student_id, course_code)
);

INSERT INTO patients VALUES
(1001,'Alice Smith'),
(1002,'Bob Johnson'),
(1003,'Carol White'),
(1004,'David Brown'),
(1005,'Eve Davis');

INSERT INTO admissions VALUES
(101,1001,TIMESTAMP '2025-01-10 09:00','Pneumonia','Internal Medicine'),
(102,1002,TIMESTAMP '2025-01-15 14:00','Fracture','Orthopedics'),
(103,1001,TIMESTAMP '2025-01-28 16:00','Flu','Internal Medicine'),
(104,1001,TIMESTAMP '2025-02-05 08:30','Pneumonia','Internal Medicine'),
(105,1003,TIMESTAMP '2025-02-10 11:00','Flu','Internal Medicine'),
(106,1004,TIMESTAMP '2025-02-18 07:45','Pneumonia','Pulmonology'),
(107,1005,TIMESTAMP '2025-03-02 13:20','Fracture','Orthopedics'),
(108,1002,TIMESTAMP '2025-03-15 19:10','Flu','Internal Medicine'),
(109,1001,TIMESTAMP '2025-03-22 10:15','Flu','Internal Medicine'),
(110,1003,TIMESTAMP '2025-03-30 17:00','Pneumonia','Pulmonology');

INSERT INTO sales VALUES
(1,'Laptop','Electronics',DATE '2025-01-01',900.00),
(2,'Laptop','Electronics',DATE '2025-01-01',700.00),
(3,'Mouse','Accessories',DATE '2025-01-01',40.00),
(4,'Mouse','Accessories',DATE '2025-01-01',60.00),
(5,'Laptop','Electronics',DATE '2025-02-01',1400.00),
(6,'Laptop','Electronics',DATE '2025-02-01',1000.00),
(7,'Mouse','Accessories',DATE '2025-02-01',150.00),
(8,'Keyboard','Accessories',DATE '2025-02-01',200.00),
(9,'Laptop','Electronics',DATE '2025-03-01',1800.00),
(10,'Mouse','Accessories',DATE '2025-03-01',190.00),
(11,'Keyboard','Accessories',DATE '2025-03-01',250.00);

INSERT INTO survey_responses VALUES
(1,'Q1',4),(1,'Q2',5),(1,'Q3',4),
(2,'Q1',3),(2,'Q2',4),
(3,'Q1',5),(3,'Q2',5),(3,'Q3',5);

INSERT INTO monthly_sales VALUES
('Laptop',1600.00,2400.00,1800.00),
('Mouse',100.00,150.00,190.00),
('Keyboard',NULL,200.00,250.00);

INSERT INTO patient_metrics VALUES
(1001,72,120,80,98.0),
(1002,68,130,85,97.0),
(1003,88,142,92,94.5);

INSERT INTO students VALUES
(1,'Ana Patel'),(2,'Malik Green'),(3,'Sofia Chen');

INSERT INTO grades VALUES
(1,'CSC101',92),(1,'STA201',88),(1,'DBA301',95),
(2,'CSC101',84),(2,'STA201',91),
(3,'CSC101',97),(3,'STA201',94),(3,'DBA301',90);


-- ============================================================
-- SECTION 2 - QUICK DATABASE CHECK
-- ============================================================
-- Run these after SECTION 1. They help confirm that the tables
-- loaded correctly before you begin reshaping data.
-- ============================================================

SELECT COUNT(*) AS patient_rows FROM patients;
SELECT COUNT(*) AS admission_rows FROM admissions;
SELECT COUNT(*) AS sales_rows FROM sales;
SELECT COUNT(*) AS survey_rows FROM survey_responses;
SELECT COUNT(*) AS monthly_sales_rows FROM monthly_sales;
SELECT COUNT(*) AS patient_metric_rows FROM patient_metrics;
SELECT COUNT(*) AS student_rows FROM students;
SELECT COUNT(*) AS grade_rows FROM grades;


-- ============================================================
-- SECTION 3 - SEE LONG AND WIDE STRUCTURES
-- ============================================================

-- Long transaction data.
-- Grain: one row per sales transaction.
SELECT *
FROM sales
ORDER BY product, sale_month, sale_id;

-- A summarized long result.
-- Grain: one row per product-month.
SELECT
    product,
    sale_month,
    SUM(revenue) AS revenue
FROM sales
GROUP BY product, sale_month
ORDER BY product, sale_month;

-- Wide data.
-- Grain: one row per product.
SELECT *
FROM monthly_sales
ORDER BY product;


-- ============================================================
-- SECTION 4 - QUERIES USED THROUGHOUT MODULE 10
-- ============================================================
-- These match the runnable pgAdmin-style examples in the module.
-- Read the comments before each query and run examples separately.
-- ============================================================


-- ------------------------------------------------------------
-- MODULE EXAMPLE 01: Inspect admissions
-- ------------------------------------------------------------
SELECT hadm_id, subject_id, admit_time, diagnosis, department
FROM admissions
ORDER BY admit_time, hadm_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 02: Diagnosis pivot with CASE
-- ------------------------------------------------------------
SELECT DATE_TRUNC('month', admit_time)::date AS admit_month,
       SUM(CASE WHEN diagnosis = 'Pneumonia' THEN 1 ELSE 0 END) AS pneumonia_count,
       SUM(CASE WHEN diagnosis = 'Fracture' THEN 1 ELSE 0 END) AS fracture_count,
       SUM(CASE WHEN diagnosis = 'Flu' THEN 1 ELSE 0 END) AS flu_count
FROM admissions
GROUP BY 1
ORDER BY 1;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 03: Diagnosis pivot with FILTER
-- ------------------------------------------------------------
SELECT DATE_TRUNC('month', admit_time)::date AS admit_month,
       COUNT(*) FILTER (WHERE diagnosis = 'Pneumonia') AS pneumonia_count,
       COUNT(*) FILTER (WHERE diagnosis = 'Fracture') AS fracture_count,
       COUNT(*) FILTER (WHERE diagnosis = 'Flu') AS flu_count
FROM admissions
GROUP BY 1
ORDER BY 1;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 04: Sales revenue by product column
-- ------------------------------------------------------------
SELECT sale_month,
       SUM(revenue) FILTER (WHERE product = 'Laptop') AS laptop_revenue,
       SUM(revenue) FILTER (WHERE product = 'Mouse') AS mouse_revenue,
       SUM(revenue) FILTER (WHERE product = 'Keyboard') AS keyboard_revenue
FROM sales
GROUP BY sale_month
ORDER BY sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 05: Survey scores to wide form
-- ------------------------------------------------------------
SELECT respondent_id,
       MAX(score) FILTER (WHERE question = 'Q1') AS q1_score,
       MAX(score) FILTER (WHERE question = 'Q2') AS q2_score,
       MAX(score) FILTER (WHERE question = 'Q3') AS q3_score
FROM survey_responses
GROUP BY respondent_id
ORDER BY respondent_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 06: Preserve missing vs force zero
-- ------------------------------------------------------------
SELECT respondent_id,
       MAX(CASE WHEN question = 'Q3' THEN score END) AS q3_preserve_missing,
       MAX(CASE WHEN question = 'Q3' THEN score ELSE 0 END) AS q3_force_zero
FROM survey_responses
GROUP BY respondent_id
ORDER BY respondent_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 07: Inspect monthly_sales
-- ------------------------------------------------------------
SELECT *
FROM monthly_sales
ORDER BY product;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 08: UNION ALL unpivot
-- ------------------------------------------------------------
SELECT product, DATE '2025-01-01' AS sale_month, jan_revenue AS revenue
FROM monthly_sales
UNION ALL
SELECT product, DATE '2025-02-01', feb_revenue
FROM monthly_sales
UNION ALL
SELECT product, DATE '2025-03-01', mar_revenue
FROM monthly_sales
ORDER BY product, sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 09: LATERAL VALUES unpivot
-- ------------------------------------------------------------
SELECT m.product, v.sale_month, v.revenue
FROM monthly_sales AS m
CROSS JOIN LATERAL (
    VALUES
      (DATE '2025-01-01', m.jan_revenue),
      (DATE '2025-02-01', m.feb_revenue),
      (DATE '2025-03-01', m.mar_revenue)
) AS v(sale_month, revenue)
ORDER BY m.product, v.sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 10: Patient metrics to long form
-- ------------------------------------------------------------
SELECT p.patient_id, v.metric, v.value
FROM patient_metrics AS p
CROSS JOIN LATERAL (
    VALUES
      ('heart_rate', p.heart_rate::numeric),
      ('systolic_bp', p.systolic_bp::numeric),
      ('diastolic_bp', p.diastolic_bp::numeric),
      ('oxygen_sat', p.oxygen_sat)
) AS v(metric, value)
ORDER BY p.patient_id, v.metric;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 11: Unpivot and remove NULL values
-- ------------------------------------------------------------
SELECT m.product, v.sale_month, v.revenue
FROM monthly_sales AS m
CROSS JOIN LATERAL (
    VALUES
      (DATE '2025-01-01', m.jan_revenue),
      (DATE '2025-02-01', m.feb_revenue),
      (DATE '2025-03-01', m.mar_revenue)
) AS v(sale_month, revenue)
WHERE v.revenue IS NOT NULL
ORDER BY m.product, v.sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 12: Pivot then unpivot
-- ------------------------------------------------------------
WITH wide AS (
    SELECT product,
           SUM(revenue) FILTER (WHERE sale_month = DATE '2025-01-01') AS jan_revenue,
           SUM(revenue) FILTER (WHERE sale_month = DATE '2025-02-01') AS feb_revenue,
           SUM(revenue) FILTER (WHERE sale_month = DATE '2025-03-01') AS mar_revenue
    FROM sales
    GROUP BY product
)
SELECT w.product, v.sale_month, v.revenue
FROM wide AS w
CROSS JOIN LATERAL (
  VALUES
    (DATE '2025-01-01', w.jan_revenue),
    (DATE '2025-02-01', w.feb_revenue),
    (DATE '2025-03-01', w.mar_revenue)
) AS v(sale_month, revenue)
ORDER BY w.product, v.sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 13: Inspect product-month cardinality
-- ------------------------------------------------------------
SELECT product, sale_month, COUNT(*) AS source_rows, SUM(revenue) AS total_revenue
FROM sales
GROUP BY product, sale_month
ORDER BY product, sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 14: Transaction detail vs pivot value
-- ------------------------------------------------------------
SELECT product, sale_month, sale_id, revenue
FROM sales
WHERE product = 'Laptop' AND sale_month = DATE '2025-01-01'
ORDER BY sale_id;

SELECT product, sale_month, SUM(revenue) AS pivot_cell_value
FROM sales
WHERE product = 'Laptop' AND sale_month = DATE '2025-01-01'
GROUP BY product, sale_month;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 15: Patient month matrix
-- ------------------------------------------------------------
SELECT p.subject_id, p.name,
       COUNT(a.hadm_id) FILTER (WHERE DATE_TRUNC('month', a.admit_time) = DATE '2025-01-01') AS jan_admissions,
       COUNT(a.hadm_id) FILTER (WHERE DATE_TRUNC('month', a.admit_time) = DATE '2025-02-01') AS feb_admissions,
       COUNT(a.hadm_id) FILTER (WHERE DATE_TRUNC('month', a.admit_time) = DATE '2025-03-01') AS mar_admissions
FROM patients AS p
LEFT JOIN admissions AS a ON a.subject_id = p.subject_id
GROUP BY p.subject_id, p.name
ORDER BY p.subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 16: Pre-aggregate then pivot
-- ------------------------------------------------------------
WITH monthly_product AS (
    SELECT product, category, sale_month, SUM(revenue) AS revenue
    FROM sales
    GROUP BY product, category, sale_month
)
SELECT category,
       SUM(revenue) FILTER (WHERE sale_month = DATE '2025-01-01') AS jan_revenue,
       SUM(revenue) FILTER (WHERE sale_month = DATE '2025-02-01') AS feb_revenue,
       SUM(revenue) FILTER (WHERE sale_month = DATE '2025-03-01') AS mar_revenue
FROM monthly_product
GROUP BY category
ORDER BY category;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 17: Discover diagnosis and product values
-- ------------------------------------------------------------
SELECT DISTINCT diagnosis
FROM admissions
ORDER BY diagnosis;

SELECT DISTINCT product
FROM sales
ORDER BY product;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 18: Static diagnosis columns
-- ------------------------------------------------------------
SELECT DATE_TRUNC('month', admit_time)::date AS admit_month,
       COUNT(*) FILTER (WHERE diagnosis = 'Pneumonia') AS pneumonia,
       COUNT(*) FILTER (WHERE diagnosis = 'Fracture') AS fracture,
       COUNT(*) FILTER (WHERE diagnosis = 'Flu') AS flu
FROM admissions
GROUP BY 1
ORDER BY 1;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 19: Monthly product revenue in long form
-- ------------------------------------------------------------
SELECT sale_month, product, SUM(revenue) AS revenue
FROM sales
GROUP BY sale_month, product
ORDER BY sale_month, product;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 20: Student grade matrix
-- ------------------------------------------------------------
SELECT s.student_id, s.student_name,
       MAX(g.grade) FILTER (WHERE g.course_code = 'CSC101') AS csc101,
       MAX(g.grade) FILTER (WHERE g.course_code = 'STA201') AS sta201,
       MAX(g.grade) FILTER (WHERE g.course_code = 'DBA301') AS dba301
FROM students AS s
LEFT JOIN grades AS g ON g.student_id = s.student_id
GROUP BY s.student_id, s.student_name
ORDER BY s.student_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 21: Patient month matrix
-- ------------------------------------------------------------
SELECT p.subject_id, p.name,
       COUNT(a.hadm_id) FILTER (WHERE DATE_TRUNC('month', a.admit_time) = DATE '2025-01-01') AS jan,
       COUNT(a.hadm_id) FILTER (WHERE DATE_TRUNC('month', a.admit_time) = DATE '2025-02-01') AS feb,
       COUNT(a.hadm_id) FILTER (WHERE DATE_TRUNC('month', a.admit_time) = DATE '2025-03-01') AS mar,
       COUNT(a.hadm_id) AS total_admissions
FROM patients AS p
LEFT JOIN admissions AS a ON a.subject_id = p.subject_id
GROUP BY p.subject_id, p.name
ORDER BY total_admissions DESC, p.subject_id;


-- ------------------------------------------------------------
-- MODULE EXAMPLE 22: Assessment starter
-- ------------------------------------------------------------
-- Assessment: reshape the long sales table to one row per product.
-- Return Jan, Feb, and Mar revenue columns. Preserve NULL when a
-- product has no observation for a month, and explain the output grain.
SELECT
  product
  -- add reshaped month columns
FROM sales
GROUP BY product
ORDER BY product;


-- ============================================================
-- SECTION 5 - VALIDATION PATTERNS
-- ============================================================

-- A. Check total sales revenue before reshaping.
SELECT
    SUM(revenue) AS source_total_revenue
FROM sales;

-- B. Check revenue at the product-month grain.
-- The sum of total_revenue should equal the source total.
SELECT
    product,
    sale_month,
    COUNT(*) AS transaction_count,
    SUM(revenue) AS total_revenue
FROM sales
GROUP BY product, sale_month
ORDER BY product, sale_month;

-- C. Check whether any product-month has multiple source rows.
-- If source_rows > 1, a pivot cell needs an aggregation rule.
SELECT
    product,
    sale_month,
    COUNT(*) AS source_rows
FROM sales
GROUP BY product, sale_month
HAVING COUNT(*) > 1
ORDER BY product, sale_month;

-- D. Discover categories before writing fixed pivot columns.
SELECT DISTINCT diagnosis
FROM admissions
ORDER BY diagnosis;

SELECT DISTINCT product
FROM sales
ORDER BY product;

SELECT DISTINCT question
FROM survey_responses
ORDER BY question;

SELECT DISTINCT course_code
FROM grades
ORDER BY course_code;

-- E. Check NULL values in a wide table before unpivoting.
SELECT
    product,
    jan_revenue,
    feb_revenue,
    mar_revenue
FROM monthly_sales
WHERE jan_revenue IS NULL
   OR feb_revenue IS NULL
   OR mar_revenue IS NULL
ORDER BY product;

-- F. Count rows before and after a simple unpivot.
SELECT COUNT(*) AS wide_rows
FROM monthly_sales;

SELECT COUNT(*) AS long_rows_including_nulls
FROM monthly_sales AS m
CROSS JOIN LATERAL (
    VALUES
        (DATE '2025-01-01', m.jan_revenue),
        (DATE '2025-02-01', m.feb_revenue),
        (DATE '2025-03-01', m.mar_revenue)
) AS v(sale_month, revenue);

SELECT COUNT(*) AS long_rows_excluding_nulls
FROM monthly_sales AS m
CROSS JOIN LATERAL (
    VALUES
        (DATE '2025-01-01', m.jan_revenue),
        (DATE '2025-02-01', m.feb_revenue),
        (DATE '2025-03-01', m.mar_revenue)
) AS v(sale_month, revenue)
WHERE v.revenue IS NOT NULL;


-- ============================================================
-- SECTION 6 - ADDITIONAL GUIDED EXAMPLES
-- ============================================================

-- Example A: Pivot product revenue into Jan / Feb / Mar columns.
-- Source grain: one row per transaction.
-- Target grain: one row per product.
-- Aggregation: SUM because several transactions can contribute
-- to one product-month cell.
SELECT
    product,
    SUM(revenue) FILTER (
        WHERE sale_month = DATE '2025-01-01'
    ) AS jan_revenue,
    SUM(revenue) FILTER (
        WHERE sale_month = DATE '2025-02-01'
    ) AS feb_revenue,
    SUM(revenue) FILTER (
        WHERE sale_month = DATE '2025-03-01'
    ) AS mar_revenue
FROM sales
GROUP BY product
ORDER BY product;

-- Example B: Same pivot using CASE instead of FILTER.
SELECT
    product,
    SUM(CASE
        WHEN sale_month = DATE '2025-01-01' THEN revenue
    END) AS jan_revenue,
    SUM(CASE
        WHEN sale_month = DATE '2025-02-01' THEN revenue
    END) AS feb_revenue,
    SUM(CASE
        WHEN sale_month = DATE '2025-03-01' THEN revenue
    END) AS mar_revenue
FROM sales
GROUP BY product
ORDER BY product;

-- Example C: Unpivot monthly_sales with UNION ALL.
-- Source grain: one row per product.
-- Target grain: one row per product-month.
SELECT product, DATE '2025-01-01' AS sale_month, jan_revenue AS revenue
FROM monthly_sales
UNION ALL
SELECT product, DATE '2025-02-01', feb_revenue
FROM monthly_sales
UNION ALL
SELECT product, DATE '2025-03-01', mar_revenue
FROM monthly_sales
ORDER BY product, sale_month;

-- Example D: Unpivot monthly_sales with LATERAL VALUES.
-- This is often more compact when many source columns belong to
-- the same logical measure.
SELECT
    m.product,
    v.sale_month,
    v.revenue
FROM monthly_sales AS m
CROSS JOIN LATERAL (
    VALUES
        (DATE '2025-01-01', m.jan_revenue),
        (DATE '2025-02-01', m.feb_revenue),
        (DATE '2025-03-01', m.mar_revenue)
) AS v(sale_month, revenue)
ORDER BY m.product, v.sale_month;

-- Example E: Unpivot patient metrics.
-- The ::numeric casts give all VALUES rows a compatible data type.
SELECT
    p.patient_id,
    v.metric,
    v.value
FROM patient_metrics AS p
CROSS JOIN LATERAL (
    VALUES
        ('heart_rate', p.heart_rate::numeric),
        ('systolic_bp', p.systolic_bp::numeric),
        ('diastolic_bp', p.diastolic_bp::numeric),
        ('oxygen_sat', p.oxygen_sat::numeric)
) AS v(metric, value)
ORDER BY p.patient_id, v.metric;


-- ============================================================
-- SECTION 7 - PRACTICE
-- ============================================================
-- Try these before looking back at the module solutions.
-- The prompts are comments, so the entire file remains runnable.
-- ============================================================

-- PRACTICE 1
-- Build one row per student.
-- Create columns for CSC101, STA201, and DBA301.
-- Keep a missing course as NULL.
--
-- Starter:
-- SELECT
--     s.student_id,
--     s.student_name
--     -- add course columns here
-- FROM students AS s
-- LEFT JOIN grades AS g
--     ON g.student_id = s.student_id
-- GROUP BY s.student_id, s.student_name
-- ORDER BY s.student_id;


-- PRACTICE 2
-- Build one row per patient.
-- Create Jan, Feb, and Mar admission-count columns.
-- Add total_admissions.
-- Preserve patients who have no admissions.
--
-- Hint:
-- Start from patients and LEFT JOIN admissions.


-- PRACTICE 3
-- Reshape survey_responses to one row per respondent.
-- Create Q1, Q2, and Q3 score columns.
-- Keep unanswered questions as NULL.


-- PRACTICE 4
-- Convert monthly_sales to long form with these columns:
--     product, sale_month, revenue
-- Remove rows where revenue is NULL.


-- PRACTICE 5
-- Create one row per month from admissions and build columns for:
--     Pneumonia, Fracture, Flu
-- Use COUNT(*) FILTER or SUM(CASE ...).


-- ============================================================
-- SECTION 8 - OPTIONAL CHALLENGE
-- ============================================================
-- Build a reusable long-form product-month revenue result in a
-- CTE, then pivot it to one row per product.
--
-- Requirements:
--   * first CTE grain = one row per product-month
--   * final grain = one row per product
--   * Jan / Feb / Mar columns
--   * preserve NULL when a product has no observation that month
--
-- Think about:
--   Why is pre-aggregation useful before a pivot?
--   What would change if new months appeared in the data?


-- ============================================================
-- MODULE 10 CHECKLIST
-- ============================================================
-- Before you consider a reshape complete, confirm:
--
-- [ ] I can state the source grain.
-- [ ] I can state the output grain.
-- [ ] I know whether aggregation is required.
-- [ ] I know whether NULL and zero mean different things.
-- [ ] I checked categories before creating fixed columns.
-- [ ] I compared totals before and after reshaping.
-- [ ] I checked for unexpected row multiplication.
-- [ ] I selected long or wide form based on the downstream task.
--
-- End of IAN 603 Module 10 SQL file.
