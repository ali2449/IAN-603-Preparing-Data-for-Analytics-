-- ============================================================
-- IAN 603 - MODULE 8
-- Strings and Dates in PostgreSQL
-- ============================================================
-- Companion file for s_module8.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- trimming, case normalization, splitting, replacing, regex,
-- date parsing, DATE_TRUNC, intervals, AGE, formatting,
-- duration calculations, and time-zone reasoning.
--
-- Preserve raw values when a transformation is interpretive,
-- and validate before converting messy text into typed values.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP TABLE IF EXISTS staging_dates CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

CREATE TABLE patients (
    subject_id integer PRIMARY KEY,
    name text NOT NULL,
    email text,
    address text,
    admission_date date
);

CREATE TABLE admissions (
    hadm_id integer PRIMARY KEY,
    subject_id integer NOT NULL REFERENCES patients(subject_id),
    admit_time timestamp NOT NULL,
    discharge_time timestamp,
    diagnosis text NOT NULL,
    CHECK (discharge_time IS NULL OR discharge_time >= admit_time)
);

CREATE TABLE products (
    product_id integer PRIMARY KEY,
    product_name text NOT NULL,
    description text,
    price numeric(10,2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    name text NOT NULL,
    email text,
    address text,
    signup_at timestamp NOT NULL
);

CREATE TABLE orders (
    order_id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(customer_id),
    order_ts timestamptz NOT NULL,
    total_amount numeric(10,2) NOT NULL CHECK (total_amount >= 0)
);

CREATE TABLE staging_dates (
    row_id integer PRIMARY KEY,
    raw_date text,
    raw_timestamp text
);

INSERT INTO patients VALUES
(1001,'Alice Smith','alice.smith@email.com','123 Main St, Greensboro',DATE '2026-01-10'),
(1002,'bob JOHNSON','BOB.JOHNSON@EMAIL.COM','456 Oak Ave, greensboro',DATE '2026-02-01'),
(1003,'  Carol   White  ','carol.white@email.com','789 Pine Rd, GSO',DATE '2026-01-20'),
(1004,'DAVID  Brown  ',' david.brown@email.com ','101 Elm St, Greensboro',DATE '2026-02-15'),
(1005,'EVE DAVIS',NULL,'202 Maple Dr, GSO',DATE '2026-03-02'),
(1006,'Frank Miller','frank.miller@sample.org','  88 Market St, High Point  ',DATE '2026-05-11');

INSERT INTO admissions VALUES
(101,1001,TIMESTAMP '2026-01-10 08:15:00',TIMESTAMP '2026-01-15 14:30:00','Pneumonia'),
(102,1002,TIMESTAMP '2026-02-01 19:42:00',TIMESTAMP '2026-02-03 10:10:00','Fracture'),
(103,1001,TIMESTAMP '2026-03-05 09:05:00',TIMESTAMP '2026-03-12 11:45:00','Hypertension'),
(104,1003,TIMESTAMP '2026-01-20 23:10:00',TIMESTAMP '2026-01-25 09:00:00','Infection'),
(105,1004,TIMESTAMP '2026-02-15 06:35:00',TIMESTAMP '2026-02-20 16:20:00','Surgery'),
(106,1005,TIMESTAMP '2026-04-20 13:00:00',NULL,'Observation');

INSERT INTO products VALUES
(1,'Laptop','High-performance laptop',999.99),
(2,'MOUSE','Wireless Mouse',29.99),
(3,'Keyboard','Mechanical KB',79.99),
(4,'Monitor','27-inch 4K monitor',399.99),
(5,'  Headphones  ','Noise-cancelling headphones',199.99);

INSERT INTO customers VALUES
(1,'John Doe','john.doe@email.com','123 Main St, Greensboro',TIMESTAMP '2025-11-15 10:00:00'),
(2,'JANE SMITH','jane.smith@email.com','456 Oak Ave, High Point',TIMESTAMP '2025-12-20 15:30:00'),
(3,'  Bob Johnson ','bob.johnson@email.com','789 Pine Rd, Greensboro',TIMESTAMP '2026-01-10 09:20:00'),
(4,'Maya Patel','maya.patel@example.org','55 Spring St, Burlington',TIMESTAMP '2026-02-14 12:00:00');

INSERT INTO orders VALUES
(201,1,TIMESTAMPTZ '2026-01-15 10:20:00-05',150.00),
(202,2,TIMESTAMPTZ '2026-02-20 16:05:00-05',300.00),
(203,1,TIMESTAMPTZ '2026-03-10 09:15:00-05',200.00),
(204,3,TIMESTAMPTZ '2026-01-25 20:10:00-05',450.00),
(205,2,TIMESTAMPTZ '2026-02-28 08:00:00-05',125.00),
(206,4,TIMESTAMPTZ '2026-03-18 14:40:00-04',510.00),
(207,1,TIMESTAMPTZ '2026-04-05 11:25:00-04',80.00),
(208,3,TIMESTAMPTZ '2026-04-22 17:55:00-04',225.00);

INSERT INTO staging_dates VALUES
(1,'2026-08-01','2026-08-01 14:30:00'),
(2,'08/05/2026','08/05/2026 09:15'),
(3,'20260807','20260807 1645'),
(4,'',''),
(5,'not-a-date','not-a-timestamp');

-- ============================================================
-- SECTION 2 - MODULE EXAMPLES
-- ============================================================


-- ------------------------------------------------------------
-- Example 01: Inspect patient text
-- ------------------------------------------------------------
SELECT subject_id, name, email, address
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 02: Case, trim, and length
-- ------------------------------------------------------------
SELECT subject_id, name,
       UPPER(name) AS upper_name,
       LOWER(name) AS lower_name,
       INITCAP(BTRIM(name)) AS display_name,
       LENGTH(name) AS raw_length,
       LENGTH(BTRIM(name)) AS trimmed_length
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 03: Normalize names
-- ------------------------------------------------------------
SELECT subject_id, name,
       REGEXP_REPLACE(BTRIM(name), '[[:space:]]+', ' ', 'g') AS normalized_name
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 04: CONCAT_WS contact line
-- ------------------------------------------------------------
SELECT subject_id,
       CONCAT_WS(' | ',
         REGEXP_REPLACE(BTRIM(name), '[[:space:]]+', ' ', 'g'),
         NULLIF(BTRIM(email), ''),
         BTRIM(address)
       ) AS contact_line
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 05: Parse email components
-- ------------------------------------------------------------
SELECT subject_id, email,
       SPLIT_PART(LOWER(BTRIM(email)), '@', 1) AS email_user,
       SPLIT_PART(LOWER(BTRIM(email)), '@', 2) AS email_domain,
       POSITION('@' IN COALESCE(email,'')) AS at_position
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 06: Reproducible product code
-- ------------------------------------------------------------
SELECT product_id, product_name,
       UPPER(SUBSTRING(BTRIM(product_name) FROM 1 FOR 3)) || '-' || LPAD(product_id::text, 3, '0') AS product_code
FROM products
ORDER BY product_id;


-- ------------------------------------------------------------
-- Example 07: Replace KB with keyboard
-- ------------------------------------------------------------
SELECT product_id, description,
       REPLACE(description, 'KB', 'keyboard') AS expanded_description
FROM products
ORDER BY product_id;


-- ------------------------------------------------------------
-- Example 08: Teaching-level email cleanup
-- ------------------------------------------------------------
SELECT subject_id, email,
       LOWER(REGEXP_REPLACE(BTRIM(email), '[^[:alnum:]@._+-]', '', 'g')) AS clean_email
FROM patients
WHERE email IS NOT NULL
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 09: Email shape check
-- ------------------------------------------------------------
SELECT subject_id, email,
       CASE
         WHEN LOWER(BTRIM(email)) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN 'valid shape'
         ELSE 'review'
       END AS email_shape_check
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 10: Extract admission components
-- ------------------------------------------------------------
SELECT hadm_id, admit_time,
       EXTRACT(YEAR FROM admit_time) AS year,
       EXTRACT(MONTH FROM admit_time) AS month,
       EXTRACT(DOW FROM admit_time) AS dow,
       EXTRACT(HOUR FROM admit_time) AS hour
FROM admissions
ORDER BY admit_time;


-- ------------------------------------------------------------
-- Example 11: Truncate order timestamps
-- ------------------------------------------------------------
SELECT order_id, order_ts,
       DATE_TRUNC('day', order_ts) AS order_day,
       DATE_TRUNC('week', order_ts) AS order_week,
       DATE_TRUNC('month', order_ts) AS order_month,
       DATE_TRUNC('quarter', order_ts) AS order_quarter
FROM orders
ORDER BY order_ts;


-- ------------------------------------------------------------
-- Example 12: Monthly order summary
-- ------------------------------------------------------------
SELECT DATE_TRUNC('month', order_ts)::date AS month,
       COUNT(*) AS order_count,
       SUM(total_amount) AS revenue
FROM orders
GROUP BY DATE_TRUNC('month', order_ts)
ORDER BY month;


-- ------------------------------------------------------------
-- Example 13: Stay interval and stay_days
-- ------------------------------------------------------------
SELECT hadm_id, subject_id, admit_time, discharge_time,
       discharge_time - admit_time AS stay_interval,
       ROUND(EXTRACT(EPOCH FROM (discharge_time - admit_time))/86400.0, 2) AS stay_days
FROM admissions
WHERE discharge_time IS NOT NULL
ORDER BY stay_days DESC;


-- ------------------------------------------------------------
-- Example 14: Create follow-up timestamps
-- ------------------------------------------------------------
SELECT hadm_id, discharge_time,
       discharge_time + INTERVAL '14 days' AS followup_14d,
       discharge_time + INTERVAL '30 days' AS followup_30d
FROM admissions
WHERE discharge_time IS NOT NULL
ORDER BY discharge_time;


-- ------------------------------------------------------------
-- Example 15: AGE versus exact elapsed interval
-- ------------------------------------------------------------
SELECT hadm_id,
       AGE(discharge_time, admit_time) AS calendar_interval,
       discharge_time - admit_time AS exact_elapsed_interval
FROM admissions
WHERE discharge_time IS NOT NULL
ORDER BY hadm_id;


-- ------------------------------------------------------------
-- Example 16: Parse staging date strings
-- ------------------------------------------------------------
SELECT row_id, raw_date,
       CASE
         WHEN NULLIF(BTRIM(raw_date),'') IS NULL THEN NULL
         WHEN raw_date ~ '^\d{4}-\d{2}-\d{2}$' THEN raw_date::date
         WHEN raw_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(raw_date,'MM/DD/YYYY')
         WHEN raw_date ~ '^\d{8}$' THEN TO_DATE(raw_date,'YYYYMMDD')
         ELSE NULL
       END AS parsed_date
FROM staging_dates
ORDER BY row_id;


-- ------------------------------------------------------------
-- Example 17: Format dates for display
-- ------------------------------------------------------------
SELECT hadm_id, admit_time,
       TO_CHAR(admit_time, 'FMMonth DD, YYYY HH24:MI') AS formatted_admit,
       TO_CHAR(admit_time, 'YYYY-MM-DD') AS iso_date_text
FROM admissions
ORDER BY admit_time;


-- ------------------------------------------------------------
-- Example 18: Time-zone conversion
-- ------------------------------------------------------------
SELECT order_id, order_ts,
       order_ts AT TIME ZONE 'America/New_York' AS eastern_local,
       order_ts AT TIME ZONE 'UTC' AS utc_clock
FROM orders
ORDER BY order_id;


-- ------------------------------------------------------------
-- Example 19: Clean patient/admission profile
-- ------------------------------------------------------------
SELECT p.subject_id,
       INITCAP(REGEXP_REPLACE(BTRIM(p.name), '[[:space:]]+', ' ', 'g')) AS clean_name,
       SPLIT_PART(LOWER(BTRIM(p.email)), '@', 2) AS email_domain,
       a.hadm_id,
       DATE_TRUNC('month', a.admit_time)::date AS admit_month,
       ROUND(EXTRACT(EPOCH FROM (a.discharge_time-a.admit_time))/86400.0,2) AS stay_days
FROM patients AS p
JOIN admissions AS a USING (subject_id)
ORDER BY p.subject_id, a.admit_time;


-- ------------------------------------------------------------
-- Example 20: Contact-data quality project
-- ------------------------------------------------------------
SELECT subject_id,
       name AS raw_name,
       INITCAP(REGEXP_REPLACE(BTRIM(name), '[[:space:]]+', ' ', 'g')) AS clean_name,
       LOWER(BTRIM(email)) AS clean_email,
       SPLIT_PART(LOWER(BTRIM(email)), '@', 2) AS email_domain,
       CASE WHEN email IS NULL THEN 'missing'
            WHEN LOWER(BTRIM(email)) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN 'valid shape'
            ELSE 'review' END AS email_status,
       BTRIM(REPLACE(address, 'GSO', 'Greensboro')) AS clean_address
FROM patients
ORDER BY subject_id;


-- ------------------------------------------------------------
-- Example 21: Monthly order project
-- ------------------------------------------------------------
SELECT DATE_TRUNC('month', order_ts)::date AS month,
       COUNT(*) AS orders,
       COUNT(DISTINCT customer_id) AS customers,
       SUM(total_amount) AS revenue,
       ROUND(AVG(total_amount),2) AS avg_order
FROM orders
GROUP BY DATE_TRUNC('month', order_ts)
ORDER BY month;


-- ------------------------------------------------------------
-- Example 22: Assessment starter
-- ------------------------------------------------------------
-- Assessment: produce one row per admission with a cleaned patient name,
-- email domain, admission month, formatted admission label, and stay in hours.
SELECT
    -- add columns here
FROM patients AS p
JOIN admissions AS a USING (subject_id)
ORDER BY a.admit_time;


-- ============================================================
-- SECTION 3 - VALIDATION PATTERNS
-- ============================================================

-- Check text before and after normalization.
SELECT subject_id,
       name AS raw_name,
       BTRIM(name) AS trimmed_name,
       LOWER(BTRIM(email)) AS normalized_email
FROM patients
ORDER BY subject_id;

-- Inspect date-text values before parsing.
SELECT raw_date, COUNT(*) AS occurrences
FROM staging_dates
GROUP BY raw_date
ORDER BY occurrences DESC, raw_date;

-- Find rows that cannot be parsed by the module's accepted rules.
SELECT row_id, raw_date
FROM staging_dates
WHERE NULLIF(BTRIM(raw_date),'') IS NOT NULL
  AND raw_date !~ '^\d{4}-\d{2}-\d{2}$'
  AND raw_date !~ '^\d{2}/\d{2}/\d{4}$'
  AND raw_date !~ '^\d{8}$'
ORDER BY row_id;

-- ============================================================
-- SECTION 4 - PRACTICE
-- ============================================================
-- 1. Normalize names and email addresses.
-- 2. Extract email domains.
-- 3. Parse multiple date-text formats safely.
-- 4. Summarize orders by month with DATE_TRUNC.
-- 5. Calculate hospital length of stay in days.
-- 6. Compare local and UTC timestamp representations.
--
-- CHECKLIST
-- [ ] I distinguish text from typed dates/timestamps.
-- [ ] I validate before parsing.
-- [ ] I understand DATE_TRUNC changes analytical grain.
-- [ ] I distinguish duration from calendar age.
-- [ ] I keep raw values when traceability matters.
-- ============================================================
