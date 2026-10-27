-- ============================================================
-- IAN 603 - MODULE 9
-- Data Cleaning in PostgreSQL
-- ============================================================
-- Companion file for s_module9.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- profiling, NULL/blank/sentinel values, standardization,
-- validation, regex checks, quality flags, duplicate detection,
-- survivor rules, quarantine/review, and safe updates.
--
-- Main principle: cleaning is evidence-based decision making.
-- Standardize representation when justified; do not invent facts.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP VIEW IF EXISTS customers_clean_preview CASCADE;
DROP VIEW IF EXISTS customer_quality_issues CASCADE;
DROP TABLE IF EXISTS validated_contacts CASCADE;
DROP TABLE IF EXISTS messy_customers CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    id integer PRIMARY KEY,
    name text,
    email text,
    phone text,
    address text,
    signup_date date
);

CREATE TABLE products (
    id integer PRIMARY KEY,
    product_name text,
    category text,
    description text,
    price numeric(10,2),
    stock_quantity integer
);

CREATE TABLE orders (
    id integer PRIMARY KEY,
    customer_id integer REFERENCES customers(id),
    order_date date NOT NULL,
    total_amount numeric(10,2) CHECK (total_amount >= 0),
    status text
);

CREATE TABLE messy_customers (
    id integer PRIMARY KEY,
    full_name text,
    email text,
    phone text,
    signup_date_raw text
);

INSERT INTO customers VALUES
(1,'John Doe','john.doe@email.com','(336) 555-1201','123 Main St',DATE '2023-01-15'),
(2,'  JANE   SMITH  ',' JANE.SMITH@EMAIL.COM ','336.555.1202','456 Oak Ave',DATE '2023-02-20'),
(3,'Bob Johnson',NULL,'3365551203',NULL,DATE '2023-03-10'),
(4,'Alice Brown','alice.brown@test.com',NULL,'789 Pine Rd',DATE '2023-04-05'),
(5,'CAROL WILSON','CAROL@TEST.COM','(336) 555-1205','101 Elm St',DATE '2023-05-12'),
(6,'  David Lee  ','david.lee@example.com','336-555-1206','202 Maple Dr',DATE '2023-06-18'),
(7,NULL,'empty.name@test.com','3365551207','303 Birch Ln',DATE '2023-07-22'),
(8,'Duplicate User','duplicate@test.com','3365551208','404 Spruce St',DATE '2023-08-30'),
(9,' Duplicate   User ',' DUPLICATE@TEST.COM ','(336) 555-1208',NULL,DATE '2023-09-01'),
(10,'Test User','invalid-email','123','','2023-09-15'),
(11,'Sentinel Phone','sentinel@example.com','0000000000','505 Cedar St',DATE '2023-10-01'),
(12,'Blank Contact',' ',' ','',NULL);

INSERT INTO products VALUES
(1,'Laptop Computer','Electronics','High-performance laptop with 16GB RAM',999.99,10),
(2,'Wireless Mouse','electronics','Ergonomic wireless mouse',29.99,25),
(3,'Keyboard',NULL,'Mechanical keyboard',79.99,15),
(4,'Monitor','Electronics','27 inch 4K monitor',-399.99,8),
(5,'Headphones','AUDIO','Noise-cancelling headphones',199.99,NULL),
(6,'','Electronics','Tablet device',299.99,5),
(7,'Desk Lamp','Home Office','LED desk lamp',49.99,30),
(8,'Notebook','stationery','Spiral notebook',NULL,100),
(9,'Pen Set','Stationery','Set of 5 pens',12.99,50);

INSERT INTO orders VALUES
(101,1,DATE '2026-01-05',150.00,'shipped'),
(102,2,DATE '2026-01-20',300.00,'pending'),
(103,1,DATE '2026-02-10',200.00,'delivered'),
(104,3,DATE '2026-03-04',450.00,'shipped'),
(105,2,DATE '2026-03-18',125.00,'cancelled');

INSERT INTO messy_customers VALUES
(1,'  JOHN DOE  ','JOHN@EXAMPLE.COM','(555) 123-4567','2023-01-15'),
(2,'jane smith','jane.smith@email.com','555.987.6543','01/20/2023'),
(3,'bob johnson',NULL,'5551112233','2023-02-28'),
(4,'Alice Brown','alice.brown@test.com',NULL,'03/15/2023'),
(5,'  carol  wilson  ','CAROL@TEST.COM','(555) 444-5555','invalid_date'),
(6,'David Lee','david.lee@example.com','555-999-8888','2023-04-01'),
(7,'  ','empty.name@test.com','5550001111','2023-05-10'),
(8,'Duplicate User','duplicate@test.com','5551112222','2023-06-15'),
(9,' Duplicate   User ',' DUPLICATE@TEST.COM ','(555)111-2222','2023-06-15');

-- ============================================================
-- SECTION 2 - MODULE EXAMPLES
-- ============================================================


-- ------------------------------------------------------------
-- Example 01: Inspect customer source rows
-- ------------------------------------------------------------
SELECT id, name, email, phone, address, signup_date
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 02: Missingness profile
-- ------------------------------------------------------------
SELECT COUNT(*) AS total_rows,
       COUNT(name) AS nonnull_name,
       COUNT(NULLIF(BTRIM(name),'')) AS nonblank_name,
       COUNT(email) AS nonnull_email,
       COUNT(NULLIF(BTRIM(email),'')) AS nonblank_email,
       COUNT(phone) AS nonnull_phone,
       COUNT(NULLIF(BTRIM(phone),'')) AS nonblank_phone
FROM customers;


-- ------------------------------------------------------------
-- Example 03: Classify phone states
-- ------------------------------------------------------------
SELECT id, phone,
       CASE
         WHEN phone IS NULL THEN 'NULL'
         WHEN BTRIM(phone) = '' THEN 'blank'
         WHEN REGEXP_REPLACE(phone, '[^0-9]', '', 'g') IN ('0000000000','9999999999') THEN 'sentinel'
         ELSE 'candidate value'
       END AS phone_state
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 04: Normalize blank addresses
-- ------------------------------------------------------------
SELECT id, address,
       NULLIF(BTRIM(address),'') AS normalized_address
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 05: Preferred contact fallback
-- ------------------------------------------------------------
SELECT id, name,
       COALESCE(NULLIF(BTRIM(email),''), NULLIF(BTRIM(phone),''), 'no contact method') AS preferred_contact
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 06: Standardize customer names
-- ------------------------------------------------------------
SELECT id, name AS raw_name,
       INITCAP(REGEXP_REPLACE(BTRIM(name), '[[:space:]]+', ' ', 'g')) AS clean_name
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 07: Standardize customer emails
-- ------------------------------------------------------------
SELECT id, email AS raw_email,
       LOWER(NULLIF(BTRIM(email),'')) AS clean_email
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 08: Standardize phone digits
-- ------------------------------------------------------------
SELECT id, phone AS raw_phone,
       NULLIF(REGEXP_REPLACE(COALESCE(phone,''), '[^0-9]', '', 'g'),'') AS digits_only,
       CASE
         WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone,''), '[^0-9]', '', 'g')) = 10
         THEN REGEXP_REPLACE(COALESCE(phone,''), '[^0-9]', '', 'g')
         ELSE NULL
       END AS valid_10_digit_phone
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 09: Map product categories
-- ------------------------------------------------------------
SELECT id, product_name, category AS raw_category,
       CASE
         WHEN NULLIF(BTRIM(category),'') IS NULL THEN NULL
         WHEN LOWER(BTRIM(category)) IN ('electronics','electronic','tech') THEN 'Electronics'
         WHEN LOWER(BTRIM(category)) IN ('audio','headphones') THEN 'Audio'
         WHEN LOWER(BTRIM(category)) IN ('stationery','office supplies') THEN 'Stationery'
         WHEN LOWER(BTRIM(category)) IN ('home office','home & garden') THEN 'Home Office'
         ELSE INITCAP(BTRIM(category))
       END AS standard_category
FROM products
ORDER BY id;


-- ------------------------------------------------------------
-- Example 10: Flag product prices
-- ------------------------------------------------------------
SELECT id, product_name, price,
       CASE
         WHEN price IS NULL THEN 'missing'
         WHEN price <= 0 THEN 'invalid - review'
         ELSE 'valid candidate'
       END AS price_status
FROM products
ORDER BY id;


-- ------------------------------------------------------------
-- Example 11: Email validation
-- ------------------------------------------------------------
SELECT id, email,
       CASE
         WHEN NULLIF(BTRIM(email),'') IS NULL THEN 'missing'
         WHEN LOWER(BTRIM(email)) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN 'valid shape'
         ELSE 'review'
       END AS email_status
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 12: Phone validation
-- ------------------------------------------------------------
SELECT id, phone,
       REGEXP_REPLACE(COALESCE(phone,''),'[^0-9]','','g') AS digits,
       CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone,''),'[^0-9]','','g')) = 10 THEN 'valid shape'
            WHEN NULLIF(BTRIM(phone),'') IS NULL THEN 'missing'
            ELSE 'review' END AS phone_status
FROM customers
ORDER BY id;


-- ------------------------------------------------------------
-- Example 13: Product validation
-- ------------------------------------------------------------
SELECT id, product_name, category, price, stock_quantity,
       CASE
         WHEN NULLIF(BTRIM(product_name),'') IS NULL THEN 'missing product name'
         WHEN price IS NULL THEN 'missing price'
         WHEN price <= 0 THEN 'invalid price'
         WHEN stock_quantity IS NOT NULL AND stock_quantity < 0 THEN 'negative stock'
         ELSE 'passes selected rules'
       END AS validation_status
FROM products
ORDER BY id;


-- ------------------------------------------------------------
-- Example 14: Quality issue report
-- ------------------------------------------------------------
WITH issues AS (
  SELECT id, 'customer' AS entity, 'invalid_email' AS issue
  FROM customers WHERE NULLIF(BTRIM(email),'') IS NOT NULL AND LOWER(BTRIM(email)) !~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'
  UNION ALL
  SELECT id, 'customer', 'invalid_phone'
  FROM customers WHERE NULLIF(BTRIM(phone),'') IS NOT NULL AND LENGTH(REGEXP_REPLACE(phone,'[^0-9]','','g')) <> 10
  UNION ALL
  SELECT id, 'product', 'invalid_price'
  FROM products WHERE price IS NULL OR price <= 0
)
SELECT entity, issue, COUNT(*) AS issue_count
FROM issues
GROUP BY entity, issue
ORDER BY issue_count DESC, entity, issue;


-- ------------------------------------------------------------
-- Example 15: Illustrative customer quality score
-- ------------------------------------------------------------
SELECT id, name,
       (CASE WHEN NULLIF(BTRIM(name),'') IS NOT NULL THEN 25 ELSE 0 END +
        CASE WHEN LOWER(COALESCE(BTRIM(email),'')) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN 25 ELSE 0 END +
        CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone,''),'[^0-9]','','g')) = 10 THEN 25 ELSE 0 END +
        CASE WHEN signup_date IS NOT NULL AND signup_date <= DATE '2026-08-12' THEN 25 ELSE 0 END) AS illustrative_quality_score
FROM customers
ORDER BY illustrative_quality_score, id;


-- ------------------------------------------------------------
-- Example 16: Quality band summary
-- ------------------------------------------------------------
WITH scored AS (
 SELECT id,
       (CASE WHEN NULLIF(BTRIM(name),'') IS NOT NULL THEN 25 ELSE 0 END +
        CASE WHEN LOWER(COALESCE(BTRIM(email),'')) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN 25 ELSE 0 END +
        CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone,''),'[^0-9]','','g')) = 10 THEN 25 ELSE 0 END +
        CASE WHEN signup_date IS NOT NULL AND signup_date <= DATE '2026-08-12' THEN 25 ELSE 0 END) AS score
 FROM customers
)
SELECT CASE WHEN score=100 THEN 'Excellent'
            WHEN score>=75 THEN 'Good'
            WHEN score>=50 THEN 'Fair'
            ELSE 'Poor' END AS quality_band,
       COUNT(*) AS customer_count
FROM scored
GROUP BY 1
ORDER BY MIN(score) DESC;


-- ------------------------------------------------------------
-- Example 17: Detect normalized duplicate groups
-- ------------------------------------------------------------
SELECT LOWER(BTRIM(email)) AS email_key,
       INITCAP(REGEXP_REPLACE(BTRIM(name), '[[:space:]]+', ' ', 'g')) AS name_key,
       COUNT(*) AS row_count,
       ARRAY_AGG(id ORDER BY id) AS source_ids
FROM customers
WHERE NULLIF(BTRIM(email),'') IS NOT NULL
GROUP BY LOWER(BTRIM(email)), INITCAP(REGEXP_REPLACE(BTRIM(name), '[[:space:]]+', ' ', 'g'))
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- Example 18: Rank duplicate candidates
-- ------------------------------------------------------------
WITH scored AS (
  SELECT c.*,
         (CASE WHEN NULLIF(BTRIM(name),'') IS NOT NULL THEN 1 ELSE 0 END +
          CASE WHEN NULLIF(BTRIM(email),'') IS NOT NULL THEN 1 ELSE 0 END +
          CASE WHEN NULLIF(BTRIM(phone),'') IS NOT NULL THEN 1 ELSE 0 END +
          CASE WHEN NULLIF(BTRIM(address),'') IS NOT NULL THEN 1 ELSE 0 END) AS completeness_score
  FROM customers AS c
), ranked AS (
  SELECT *, ROW_NUMBER() OVER (
      PARTITION BY LOWER(BTRIM(email)), INITCAP(REGEXP_REPLACE(BTRIM(name),'[[:space:]]+',' ','g'))
      ORDER BY completeness_score DESC, signup_date DESC NULLS LAST, id
  ) AS survivor_rank
  FROM scored
)
SELECT id, name, email, completeness_score, survivor_rank
FROM ranked
WHERE LOWER(BTRIM(email)) = 'duplicate@test.com'
ORDER BY survivor_rank;


-- ------------------------------------------------------------
-- Example 19: Possible duplicates by phone
-- ------------------------------------------------------------
SELECT a.id AS left_id, b.id AS right_id,
       a.name AS left_name, b.name AS right_name,
       a.email AS left_email, b.email AS right_email
FROM customers AS a
JOIN customers AS b ON a.id < b.id
WHERE LOWER(REGEXP_REPLACE(COALESCE(a.phone,''),'[^0-9]','','g')) = LOWER(REGEXP_REPLACE(COALESCE(b.phone,''),'[^0-9]','','g'))
  AND NULLIF(REGEXP_REPLACE(COALESCE(a.phone,''),'[^0-9]','','g'),'') IS NOT NULL
ORDER BY a.id,b.id;


-- ------------------------------------------------------------
-- Example 20: Customer quality issue view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW customer_quality_issues AS
SELECT id, name, email, phone,
       CASE WHEN NULLIF(BTRIM(name),'') IS NULL THEN true ELSE false END AS missing_name,
       CASE WHEN NULLIF(BTRIM(email),'') IS NOT NULL AND LOWER(BTRIM(email)) !~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN true ELSE false END AS invalid_email,
       CASE WHEN NULLIF(BTRIM(phone),'') IS NOT NULL AND LENGTH(REGEXP_REPLACE(phone,'[^0-9]','','g')) <> 10 THEN true ELSE false END AS invalid_phone
FROM customers;
SELECT * FROM customer_quality_issues
WHERE missing_name OR invalid_email OR invalid_phone
ORDER BY id;


-- ------------------------------------------------------------
-- Example 21: Create customers_clean_preview
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW customers_clean_preview AS
SELECT id,
       INITCAP(REGEXP_REPLACE(BTRIM(name),'[[:space:]]+',' ','g')) AS clean_name,
       LOWER(NULLIF(BTRIM(email),'')) AS clean_email,
       CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone,''),'[^0-9]','','g'))=10
            THEN REGEXP_REPLACE(phone,'[^0-9]','','g') ELSE NULL END AS clean_phone,
       NULLIF(BTRIM(address),'') AS clean_address,
       signup_date
FROM customers;
SELECT * FROM customers_clean_preview ORDER BY id;


-- ------------------------------------------------------------
-- Example 22: Validated contacts with constraints
-- ------------------------------------------------------------
DROP TABLE IF EXISTS validated_contacts;
CREATE TABLE validated_contacts (
  contact_id integer PRIMARY KEY,
  email text NOT NULL,
  phone text,
  CONSTRAINT email_shape_chk CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT phone_digits_chk CHECK (phone IS NULL OR phone ~ '^[0-9]{10}$'),
  CONSTRAINT email_unique UNIQUE (email)
);
INSERT INTO validated_contacts VALUES (1,'student@example.com','3365551212');
SELECT * FROM validated_contacts;


-- ------------------------------------------------------------
-- Example 23: Transaction + UPDATE RETURNING
-- ------------------------------------------------------------
BEGIN;
UPDATE customers
SET email = LOWER(BTRIM(email))
WHERE email IS NOT NULL
  AND email IS DISTINCT FROM LOWER(BTRIM(email))
RETURNING id, email;
ROLLBACK;


-- ------------------------------------------------------------
-- Example 24: Project: full cleaning pipeline
-- ------------------------------------------------------------
WITH normalized AS (
 SELECT id,
        NULLIF(REGEXP_REPLACE(BTRIM(full_name),'[[:space:]]+',' ','g'),'') AS name_norm,
        LOWER(NULLIF(BTRIM(email),'')) AS email_norm,
        NULLIF(REGEXP_REPLACE(COALESCE(phone,''),'[^0-9]','','g'),'') AS phone_digits,
        signup_date_raw
 FROM messy_customers
), typed AS (
 SELECT *,
        CASE WHEN signup_date_raw ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN signup_date_raw::date
             WHEN signup_date_raw ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN TO_DATE(signup_date_raw,'MM/DD/YYYY')
             ELSE NULL END AS signup_date_clean
 FROM normalized
), ranked AS (
 SELECT *, ROW_NUMBER() OVER (
   PARTITION BY email_norm, INITCAP(name_norm)
   ORDER BY (CASE WHEN name_norm IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN email_norm IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN LENGTH(phone_digits)=10 THEN 1 ELSE 0 END + CASE WHEN signup_date_clean IS NOT NULL THEN 1 ELSE 0 END) DESC, id
 ) AS duplicate_rank
 FROM typed
)
SELECT id, INITCAP(name_norm) AS clean_name, email_norm AS clean_email,
       CASE WHEN LENGTH(phone_digits)=10 THEN phone_digits ELSE NULL END AS clean_phone,
       signup_date_clean,
       duplicate_rank,
       CASE WHEN name_norm IS NULL OR email_norm IS NULL OR signup_date_clean IS NULL OR (phone_digits IS NOT NULL AND LENGTH(phone_digits)<>10) THEN 'review' ELSE 'candidate clean row' END AS row_status
FROM ranked
ORDER BY duplicate_rank, id;


-- ------------------------------------------------------------
-- Example 25: Assessment starter
-- ------------------------------------------------------------
-- Assessment: return one row per customer with cleaned name/email/phone,
-- a row-level quality status, and a duplicate rank. Do not overwrite the source table.
WITH normalized AS (
  SELECT id, name, email, phone, address, signup_date
  FROM customers
)
SELECT
  -- build the cleaned analytical output here
FROM normalized;


-- ============================================================
-- SECTION 3 - BEFORE/AFTER VALIDATION
-- ============================================================

-- Profile missing and blank contact fields.
SELECT
    COUNT(*) AS rows,
    COUNT(*) FILTER (WHERE name IS NULL) AS null_names,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(name),'') IS NULL) AS unusable_names,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(email),'') IS NULL) AS unusable_emails,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(phone),'') IS NULL) AS unusable_phones
FROM customers;

-- Detect duplicate normalized email values.
SELECT
    LOWER(BTRIM(email)) AS normalized_email,
    COUNT(*) AS row_count,
    ARRAY_AGG(id ORDER BY id) AS source_ids
FROM customers
WHERE NULLIF(BTRIM(email),'') IS NOT NULL
GROUP BY LOWER(BTRIM(email))
HAVING COUNT(*) > 1
ORDER BY normalized_email;

-- Keep invalid rows visible for review rather than silently fixing.
SELECT id, name, email, phone
FROM customers
WHERE NULLIF(BTRIM(name),'') IS NULL
   OR (NULLIF(BTRIM(email),'') IS NOT NULL
       AND LOWER(BTRIM(email)) !~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$')
   OR (NULLIF(BTRIM(phone),'') IS NOT NULL
       AND LENGTH(REGEXP_REPLACE(phone,'[^0-9]','','g')) <> 10)
ORDER BY id;

-- ============================================================
-- SECTION 4 - SAFE CLEANING WORKFLOW
-- ============================================================
-- 1. PROFILE raw values.
-- 2. PRESERVE source evidence.
-- 3. NORMALIZE representation.
-- 4. VALIDATE against documented rules.
-- 5. RESOLVE duplicates/invalid records with explicit policy.
-- 6. PREVENT recurrence with constraints or upstream controls.

-- ============================================================
-- SECTION 5 - PRACTICE
-- ============================================================
-- 1. Standardize customer names and emails.
-- 2. Normalize phone numbers to digits-only candidates.
-- 3. Validate product price and stock rules.
-- 4. Build a quality-issue summary by issue type.
-- 5. Detect duplicates using normalized keys.
-- 6. Explain which records require human review instead of repair.
--
-- CHECKLIST
-- [ ] I profile before changing values.
-- [ ] I distinguish NULL, blank, sentinel, and invalid values.
-- [ ] I preserve raw evidence when cleaning.
-- [ ] I document deduplication/survivor rules.
-- [ ] I validate results after cleaning.
-- ============================================================
