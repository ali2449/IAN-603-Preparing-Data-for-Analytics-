-- ============================================================
-- IAN 603 - MODULE 4
-- Aggregating Data with PostgreSQL
-- ============================================================
-- Companion file for s_module4.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING, FILTER,
-- CASE-based conditional aggregation, ROLLUP, CUBE,
-- GROUPING SETS, and introductory window calculations.
--
-- Main habit: aggregation changes row grain. Define the desired
-- grouping grain before writing the aggregate query.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP TABLE IF EXISTS grades,product_sales,employees,sales,admissions CASCADE;CREATE TABLE admissions(hadm_id integer PRIMARY KEY,subject_id integer NOT NULL,admit_time timestamp NOT NULL,discharge_time timestamp,diagnosis text NOT NULL);INSERT INTO admissions VALUES(1001,1,'2024-01-02 08:00','2024-01-05 12:00','Pneumonia'),(1002,1,'2024-03-10 09:00','2024-03-12 14:00','Fracture'),(1003,2,'2024-02-01 10:00','2024-02-04 10:00','Pneumonia'),(1004,2,'2024-04-18 12:00',NULL,'Pneumonia'),(1005,3,'2024-01-15 07:00','2024-01-16 18:00','Migraine'),(1006,3,'2024-05-06 11:00','2024-05-09 09:00','Fracture'),(1007,4,'2024-06-03 09:00','2024-06-08 09:00','Pneumonia'),(1008,5,'2024-06-14 13:00','2024-06-15 10:00','Asthma'),(1009,5,'2024-07-01 16:00','2024-07-04 11:00','Fracture'),(1010,6,'2024-07-20 06:00',NULL,'Pneumonia');CREATE TABLE sales(sale_id integer PRIMARY KEY,product text NOT NULL,quantity integer NOT NULL,price numeric(10,2) NOT NULL,category text NOT NULL,sale_date date NOT NULL);INSERT INTO sales VALUES(1,'Laptop',3,900,'Technology','2024-01-02'),(2,'Monitor',5,220,'Technology','2024-01-04'),(3,'Keyboard',6,45,'Technology','2024-01-05'),(4,'Desk',4,350,'Office','2024-01-08'),(5,'Chair',8,180,'Office','2024-01-09'),(6,'Notebook',12,8,'Office','2024-01-10'),(7,'Blender',5,95,'Home','2024-01-12'),(8,'Lamp',7,40,'Home','2024-01-14'),(9,'Storage Bin',10,22,'Home','2024-01-16'),(10,'Headphones',4,120,'Technology','2024-01-18');CREATE TABLE employees(employee_id integer PRIMARY KEY,name text NOT NULL,salary numeric(10,2) NOT NULL,department text NOT NULL,hire_date date NOT NULL);INSERT INTO employees VALUES(1,'Jordan Kim',92000,'Analytics','2021-04-12'),(2,'Taylor Brooks',81000,'Analytics','2022-07-01'),(3,'Casey Morgan',76000,'Analytics','2023-02-14'),(4,'Riley Chen',98000,'Engineering','2020-09-10'),(5,'Morgan Patel',88000,'Engineering','2022-11-20'),(6,'Jamie Rivera',72000,'Operations','2021-06-18'),(7,'Avery Scott',69000,'Operations','2023-03-25'),(8,'Cameron Bell',65000,'Operations','2024-01-15');CREATE TABLE product_sales(category text,product text,sales numeric(10,2));INSERT INTO product_sales VALUES('Technology','Laptop',2700),('Technology','Monitor',1100),('Technology','Keyboard',270),('Office','Desk',1400),('Office','Chair',1440),('Home','Blender',475),('Home','Lamp',280);CREATE TABLE grades(student_id integer,course text,grade numeric(5,2),semester text);INSERT INTO grades SELECT g,'IAN 603',72+(g%24),'Fall 2024' FROM generate_series(1,60) g;INSERT INTO grades SELECT 100+g,'IAN 601',70+(g%25),'Fall 2024' FROM generate_series(1,55) g;INSERT INTO grades SELECT 200+g,'IAN 620',74+(g%20),'Fall 2024' FROM generate_series(1,45) g;INSERT INTO grades SELECT 300+g,'IAN 603',75+(g%20),'Spring 2025' FROM generate_series(1,35) g;

-- ============================================================
-- SECTION 2 - BASIC AGGREGATION CHECKS
-- ============================================================

SELECT COUNT(*) AS admissions FROM admissions;
SELECT COUNT(*) AS sales_rows FROM sales;
SELECT COUNT(*) AS employees FROM employees;
SELECT COUNT(*) AS grade_rows FROM grades;

-- ============================================================
-- SECTION 3 - RUNNABLE MODULE EXAMPLES
-- ============================================================


-- Example 01
SELECT
    COUNT(*) AS all_admissions,
    COUNT(discharge_time) AS completed_admissions,
    COUNT(DISTINCT subject_id) AS unique_patients
FROM admissions;


-- Example 02
SELECT
    COUNT(*) AS sale_rows,
    SUM(quantity) AS units_sold,
    ROUND(AVG(price), 2) AS average_price,
    MIN(price) AS lowest_price,
    MAX(price) AS highest_price
FROM sales;


-- Example 03
SELECT
    ROUND((AVG(EXTRACT(EPOCH FROM (discharge_time - admit_time)) / 86400.0))::numeric, 2) AS average_stay_days,
    COUNT(discharge_time) AS completed_admissions
FROM admissions
WHERE discharge_time IS NOT NULL;


-- Example 04
SELECT
    diagnosis,
    COUNT(*) AS admission_count
FROM admissions
GROUP BY diagnosis
ORDER BY admission_count DESC, diagnosis;


-- Example 05
SELECT
    subject_id,
    diagnosis,
    COUNT(*) AS admission_count
FROM admissions
GROUP BY subject_id, diagnosis
ORDER BY subject_id, diagnosis;


-- Example 06
SELECT
    diagnosis,
    subject_id,
    COUNT(*) AS admission_count
FROM admissions
GROUP BY diagnosis;


-- Example 07
SELECT
    category,
    SUM(quantity) AS units_sold,
    ROUND(SUM(quantity * price), 2) AS category_revenue
FROM sales
WHERE price >= 25
GROUP BY category
HAVING SUM(quantity) > 10
ORDER BY category_revenue DESC;


-- Example 08
SELECT
    subject_id,
    SUM(CASE WHEN diagnosis = 'Pneumonia' THEN 1 ELSE 0 END) AS pneumonia_admissions,
    SUM(CASE WHEN diagnosis = 'Fracture' THEN 1 ELSE 0 END) AS fracture_admissions
FROM admissions
GROUP BY subject_id
ORDER BY subject_id;


-- Example 09
SELECT
    subject_id,
    COUNT(*) FILTER (WHERE diagnosis = 'Pneumonia') AS pneumonia_admissions,
    COUNT(*) FILTER (WHERE diagnosis = 'Fracture') AS fracture_admissions
FROM admissions
GROUP BY subject_id
ORDER BY subject_id;


-- Example 10
SELECT
    CASE WHEN GROUPING(category) = 1 THEN 'All categories' ELSE category END AS category_label,
    CASE WHEN GROUPING(product) = 1 THEN 'All products' ELSE product END AS product_label,
    SUM(sales) AS total_sales,
    GROUPING(category, product) AS grouping_code
FROM product_sales
GROUP BY ROLLUP(category, product)
ORDER BY GROUPING(category), category, GROUPING(product), product;


-- Example 11
SELECT
    CASE WHEN GROUPING(category) = 1 THEN 'All categories' ELSE category END AS category_label,
    CASE WHEN GROUPING(product) = 1 THEN 'All products' ELSE product END AS product_label,
    SUM(sales) AS total_sales,
    GROUPING(category, product) AS grouping_code
FROM product_sales
GROUP BY CUBE(category, product)
ORDER BY GROUPING(category), category, GROUPING(product), product;


-- Example 12
SELECT
    CASE WHEN GROUPING(category) = 1 THEN 'All categories' ELSE category END AS category_label,
    CASE WHEN GROUPING(product) = 1 THEN 'All products' ELSE product END AS product_label,
    SUM(sales) AS total_sales
FROM product_sales
GROUP BY GROUPING SETS ((category), (product), ())
ORDER BY GROUPING(category), category, GROUPING(product), product;


-- Example 13
SELECT
    name,
    department,
    salary,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS department_rank
FROM employees
ORDER BY department, department_rank, name;


-- Example 14
SELECT
    name,
    department,
    salary,
    ROUND(AVG(salary) OVER (PARTITION BY department), 2) AS department_average,
    ROUND(AVG(salary) OVER (), 2) AS company_average
FROM employees
ORDER BY department, salary DESC;


-- Example 15
SELECT
    sale_date,
    product,
    quantity * price AS row_revenue,
    SUM(quantity * price) OVER (ORDER BY sale_date, sale_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
FROM sales
ORDER BY sale_date, sale_id;


-- Example 16
SELECT
    diagnosis,
    COUNT(*) AS admission_count
FROM admissions
GROUP BY diagnosis
HAVING COUNT(*) > 1
ORDER BY admission_count DESC, diagnosis;


-- Example 17
SELECT
    name,
    department,
    salary,
    ROUND(AVG(salary) OVER (PARTITION BY department), 2) AS department_average,
    ROUND(AVG(salary) OVER (), 2) AS company_average
FROM employees
ORDER BY department, salary DESC;


-- ============================================================
-- SECTION 4 - VALIDATION PATTERNS
-- ============================================================

-- Compare raw row count with grouped row count.
SELECT COUNT(*) AS source_rows FROM admissions;

SELECT COUNT(*) AS diagnosis_groups
FROM (
    SELECT diagnosis
    FROM admissions
    GROUP BY diagnosis
) AS g;

-- Compare source revenue with grouped revenue.
SELECT SUM(quantity * price) AS source_revenue
FROM sales;

SELECT SUM(category_revenue) AS grouped_revenue
FROM (
    SELECT category, SUM(quantity * price) AS category_revenue
    FROM sales
    GROUP BY category
) AS x;

-- ============================================================
-- SECTION 5 - PRACTICE
-- ============================================================
-- 1. Count all admissions, completed admissions, and unique patients.
-- 2. Summarize admission count by diagnosis.
-- 3. Calculate units and revenue by sales category.
-- 4. Use FILTER to count Pneumonia and Fracture per subject.
-- 5. Rank employees by salary within department.
-- 6. Compare ROLLUP, CUBE, and GROUPING SETS outputs.
--
-- CHECKLIST
-- [ ] I can state the grouping grain.
-- [ ] I know WHERE filters rows before grouping.
-- [ ] I know HAVING filters groups after aggregation.
-- [ ] I understand COUNT(*) versus COUNT(column).
-- [ ] I validate totals after aggregation.
-- ============================================================
