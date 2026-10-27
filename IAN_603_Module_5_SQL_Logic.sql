-- ============================================================
-- IAN 603 - MODULE 5
-- Reasoning with SQL Logic
-- ============================================================
-- Companion file for s_module5.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- AND, OR, NOT, operator precedence, three-valued logic,
-- NULL handling, IS TRUE / FALSE / UNKNOWN, IS DISTINCT FROM,
-- COALESCE, NULLIF, CASE, and applied decision rules.
--
-- Important: WHERE keeps only TRUE. FALSE and UNKNOWN rows are
-- both filtered out unless the rule explicitly handles them.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP VIEW IF EXISTS patient_case CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS patient_billing CASCADE;
DROP TABLE IF EXISTS diagnostics CASCADE;
DROP TABLE IF EXISTS patient_info CASCADE;

CREATE TABLE patient_info (
    patient_id integer PRIMARY KEY,
    patient_name varchar(100) NOT NULL,
    age integer NOT NULL CHECK (age BETWEEN 0 AND 120),
    email_address varchar(150),
    mobile_phone varchar(30),
    home_phone varchar(30),
    active boolean NOT NULL DEFAULT true,
    consent_to_contact boolean,
    preferred_language varchar(40)
);

INSERT INTO patient_info
    (patient_id, patient_name, age, email_address, mobile_phone, home_phone, active, consent_to_contact, preferred_language)
VALUES
    (101, 'John Doe', 65, 'john.doe@email.com', '336-555-0101', NULL, true, true, 'English'),
    (102, 'Jane Smith', 32, 'jane.smith@email.com', '336-555-0102', NULL, true, false, 'English'),
    (103, 'Robert Lee', 48, NULL, NULL, '336-555-0103', true, true, 'English'),
    (104, 'Lisa Ray', 71, '', NULL, '336-555-0104', true, false, 'English'),
    (105, 'Peter Chen', 25, 'peter.chen@email.com', '336-555-0105', NULL, false, true, 'Mandarin'),
    (106, 'Susan Gray', 58, 'susan.gray@email.com', NULL, NULL, true, NULL, NULL),
    (107, 'Maria Torres', 44, '   ', '336-555-0107', NULL, true, true, 'Spanish'),
    (108, 'Andre Green', 16, NULL, NULL, NULL, true, false, 'English');

CREATE TABLE diagnostics (
    patient_id integer PRIMARY KEY REFERENCES patient_info(patient_id),
    diagnosis varchar(100),
    severity varchar(20) CHECK (severity IN ('Low', 'Moderate', 'High')),
    confirmed boolean
);
INSERT INTO diagnostics (patient_id, diagnosis, severity, confirmed) VALUES
    (101, 'Pneumonia', 'High', true), (102, 'Fever', 'Moderate', true),
    (103, 'Kidney Disease', 'High', true), (104, 'Diabetes', 'High', true),
    (105, 'Sprained Ankle', 'Low', true), (106, 'Kidney Disease', 'High', NULL),
    (107, 'Asthma', 'Moderate', true), (108, 'Flu', 'Moderate', false);

CREATE TABLE patient_billing (
    patient_id integer PRIMARY KEY REFERENCES patient_info(patient_id),
    bill_amount numeric(10,2) CHECK (bill_amount IS NULL OR bill_amount >= 0),
    amount_paid numeric(10,2) CHECK (amount_paid IS NULL OR amount_paid >= 0),
    payment_status varchar(30)
);
INSERT INTO patient_billing (patient_id, bill_amount, amount_paid, payment_status) VALUES
    (101, 12000.00, 4000.00, 'Open'), (102, 7500.00, 7500.00, 'Paid'),
    (103, NULL, 0.00, 'Pending Review'), (104, 9800.00, NULL, 'Open'),
    (105, 850.00, 850.00, 'Paid'), (106, 5200.00, 1000.00, NULL),
    (107, 0.00, 0.00, 'No Charge'), (108, 2300.00, 0.00, 'Open');

CREATE TABLE admissions (
    admission_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patient_info(patient_id),
    admission_date date NOT NULL,
    discharge_date date,
    diagnosis varchar(100) NOT NULL
);
INSERT INTO admissions (admission_id, patient_id, admission_date, discharge_date, diagnosis) VALUES
    (201, 101, '2026-07-15', '2026-07-21', 'Pneumonia'),
    (202, 102, '2026-07-25', '2026-07-27', 'Fever'),
    (203, 103, '2026-08-01', NULL, 'Kidney Disease'),
    (204, 104, '2026-06-10', '2026-06-22', 'Diabetes'),
    (205, 105, '2026-08-05', '2026-08-06', 'Sprained Ankle'),
    (206, 106, '2026-07-30', '2026-08-04', 'Kidney Disease'),
    (207, 107, '2026-08-08', NULL, 'Asthma'),
    (208, 108, '2026-08-09', '2026-08-11', 'Flu');

CREATE VIEW patient_case AS
SELECT p.patient_id, p.patient_name, p.age, p.email_address, p.mobile_phone, p.home_phone,
       p.active, p.consent_to_contact, p.preferred_language,
       d.diagnosis, d.severity, d.confirmed,
       b.bill_amount, b.amount_paid, b.payment_status
FROM patient_info AS p
LEFT JOIN diagnostics AS d USING (patient_id)
LEFT JOIN patient_billing AS b USING (patient_id);

-- ============================================================
-- SECTION 2 - INSPECT EDGE CASES
-- ============================================================

SELECT * FROM patient_info ORDER BY patient_id;
SELECT * FROM diagnostics ORDER BY patient_id;
SELECT * FROM patient_billing ORDER BY patient_id;
SELECT * FROM admissions ORDER BY admission_id;

-- ============================================================
-- SECTION 3 - RUNNABLE MODULE EXAMPLES
-- ============================================================


-- Example 01
SELECT patient_id, patient_name, age, diagnosis, severity
FROM patient_case
WHERE active IS TRUE
  AND age >= 40
  AND severity = 'High'
ORDER BY patient_id;


-- Example 02
SELECT patient_id, patient_name, diagnosis
FROM patient_case
WHERE diagnosis = 'Pneumonia'
   OR diagnosis = 'Flu'
   OR diagnosis = 'Asthma'
ORDER BY patient_id;


-- Example 03
SELECT patient_id, patient_name, diagnosis, active
FROM patient_case
WHERE active IS TRUE
  AND NOT (diagnosis IN ('Sprained Ankle', 'Flu'))
ORDER BY patient_id;


-- Example 04
-- Version A: AND binds before OR
SELECT patient_id, patient_name, age, diagnosis, consent_to_contact
FROM patient_case
WHERE age >= 65
   OR diagnosis = 'Kidney Disease' AND consent_to_contact IS TRUE
ORDER BY patient_id;

-- Version B: consent applies to the whole rule
SELECT patient_id, patient_name, age, diagnosis, consent_to_contact
FROM patient_case
WHERE (age >= 65 OR diagnosis = 'Kidney Disease')
  AND consent_to_contact IS TRUE
ORDER BY patient_id;


-- Example 05
WITH bools(label, value, sort_order) AS (
    VALUES
        ('TRUE', TRUE, 1),
        ('FALSE', FALSE, 2),
        ('UNKNOWN', NULL::boolean, 3)
)
SELECT a.label AS a,
       b.label AS b,
       COALESCE((a.value AND b.value)::text, 'unknown') AS a_and_b,
       COALESCE((a.value OR b.value)::text, 'unknown') AS a_or_b
FROM bools AS a
CROSS JOIN bools AS b
ORDER BY a.sort_order, b.sort_order;


-- Example 06
SELECT label, flag
FROM (VALUES
    ('TRUE row', TRUE),
    ('FALSE row', FALSE),
    ('UNKNOWN row', NULL::boolean)
) AS states(label, flag)
WHERE flag;


-- Example 07
SELECT patient_id,
       email_address,
       email_address = NULL AS equals_null,
       email_address <> NULL AS not_equals_null
FROM patient_info
ORDER BY patient_id;


-- Example 08
SELECT patient_id, patient_name, email_address
FROM patient_info
WHERE NULLIF(BTRIM(email_address), '') IS NULL
ORDER BY patient_id;


-- Example 09
SELECT patient_id, patient_name, consent_to_contact,
       consent_to_contact IS TRUE AS explicitly_yes,
       consent_to_contact IS FALSE AS explicitly_no,
       consent_to_contact IS UNKNOWN AS not_recorded
FROM patient_info
ORDER BY patient_id;


-- Example 10
SELECT patient_id, bill_amount, amount_paid,
       bill_amount IS DISTINCT FROM amount_paid AS amounts_differ,
       bill_amount IS NOT DISTINCT FROM amount_paid AS amounts_match_null_safely
FROM patient_billing
ORDER BY patient_id;


-- Example 11
SELECT patient_id,
       email_address AS original_email,
       NULLIF(BTRIM(email_address), '') AS normalized_email
FROM patient_info
ORDER BY patient_id;


-- Example 12
SELECT patient_id,
       patient_name,
       COALESCE(
           NULLIF(BTRIM(email_address), ''),
           NULLIF(BTRIM(mobile_phone), ''),
           NULLIF(BTRIM(home_phone), ''),
           'No contact provided'
       ) AS preferred_contact
FROM patient_info
ORDER BY patient_id;


-- Example 13
SELECT patient_id, bill_amount, amount_paid,
       ROUND(
           100.0 * COALESCE(amount_paid, 0) / NULLIF(bill_amount, 0),
           1
       ) AS percent_paid
FROM patient_billing
ORDER BY patient_id;


-- Example 14
SELECT patient_id, bill_amount,
       CASE
           WHEN bill_amount IS NULL THEN 'Unknown'
           WHEN bill_amount >= 10000 THEN 'High-Value'
           WHEN bill_amount >= 5000 THEN 'Standard'
           ELSE 'Low-Value'
       END AS billing_tier
FROM patient_billing
ORDER BY patient_id;


-- Example 15
SELECT patient_id, payment_status,
       CASE payment_status
           WHEN 'Paid' THEN 'Closed'
           WHEN 'No Charge' THEN 'Closed'
           WHEN 'Open' THEN 'Follow up'
           WHEN 'Pending Review' THEN 'Investigate'
           ELSE 'Status missing'
       END AS action
FROM patient_billing
ORDER BY patient_id;


-- Example 16
-- Wrong order: senior branch is unreachable
SELECT patient_id, patient_name, age,
       CASE
           WHEN age >= 18 THEN 'Adult'
           WHEN age >= 65 THEN 'Senior'
           ELSE 'Minor'
       END AS age_group
FROM patient_info
ORDER BY patient_id;

-- Correct order
SELECT patient_id, patient_name, age,
       CASE
           WHEN age >= 65 THEN 'Senior'
           WHEN age >= 18 THEN 'Adult'
           ELSE 'Minor'
       END AS age_group
FROM patient_info
ORDER BY patient_id;


-- Example 17
SELECT patient_id, diagnosis,
       CASE
           WHEN diagnosis IN ('Pneumonia', 'Flu', 'Asthma')
               THEN 'Respiratory'
       END AS diagnosis_group
FROM diagnostics
ORDER BY patient_id;


-- Example 18
SELECT patient_id, payment_status
FROM patient_billing
WHERE payment_status NOT IN ('Paid', NULL)
ORDER BY patient_id;


-- Example 19
-- Ordinary inequality excludes NULL status
SELECT patient_id, payment_status
FROM patient_billing
WHERE payment_status <> 'Paid'
ORDER BY patient_id;

-- NULL-safe inequality intentionally includes missing status
SELECT patient_id, payment_status
FROM patient_billing
WHERE payment_status IS DISTINCT FROM 'Paid'
ORDER BY patient_id;


-- Example 20
SELECT patient_id, patient_name, diagnosis, consent_to_contact, email_address
FROM patient_case
WHERE active IS TRUE
  AND consent_to_contact IS TRUE
  AND diagnosis IN ('Diabetes', 'Kidney Disease')
  AND NULLIF(BTRIM(email_address), '') IS NULL
ORDER BY patient_id;


-- Example 21
SELECT patient_id, patient_name,
       COALESCE(NULLIF(BTRIM(email_address), ''),
                NULLIF(BTRIM(mobile_phone), ''),
                NULLIF(BTRIM(home_phone), ''),
                'No contact provided') AS preferred_contact,
       bill_amount,
       CASE
           WHEN bill_amount IS NULL THEN 'Needs review'
           WHEN bill_amount = 0 THEN 'No Charge'
           WHEN bill_amount >= 10000 THEN 'High-Value'
           WHEN bill_amount >= 5000 THEN 'Standard'
           ELSE 'Low-Value'
       END AS billing_tier
FROM patient_case
ORDER BY patient_id;


-- Example 22
SELECT admission_id, patient_id, admission_date, discharge_date,
       discharge_date - admission_date AS length_of_stay_days,
       CASE
           WHEN discharge_date - admission_date < 5 THEN 'Short'
           WHEN discharge_date - admission_date <= 10 THEN 'Medium'
           ELSE 'Long'
       END AS stay_category
FROM admissions
WHERE discharge_date IS NOT NULL
ORDER BY admission_id;


-- Example 23
SELECT a.admission_id, p.patient_name, p.age, a.admission_date, a.diagnosis,
       CASE
           WHEN a.diagnosis IN ('Pneumonia', 'Flu') AND p.age >= 60
               THEN 'High-Risk Respiratory'
           WHEN a.diagnosis IN ('Pneumonia', 'Flu')
               THEN 'Respiratory'
           ELSE 'Other'
       END AS diagnosis_category
FROM admissions AS a
JOIN patient_info AS p USING (patient_id)
WHERE a.admission_date BETWEEN DATE '2026-08-11' - 30 AND DATE '2026-08-11'
  AND a.diagnosis IN ('Pneumonia', 'Flu')
ORDER BY a.admission_date;


-- Example 24
SELECT patient_id, patient_name, preferred_language,
       COALESCE(NULLIF(BTRIM(preferred_language), ''), 'Language not recorded') AS language_display
FROM patient_info
ORDER BY patient_id;


-- Example 25
SELECT patient_id, bill_amount,
       CASE
           WHEN bill_amount IS NULL THEN 'Unknown'
           WHEN bill_amount = 0 THEN 'No Charge'
           WHEN bill_amount >= 10000 THEN 'High-Value'
           WHEN bill_amount >= 5000 THEN 'Standard'
           ELSE 'Low-Value'
       END AS billing_tier
FROM patient_billing
ORDER BY patient_id;


-- ============================================================
-- SECTION 4 - NULL / BLANK NORMALIZATION PATTERNS
-- ============================================================

SELECT
    patient_id,
    email_address AS raw_email,
    NULLIF(BTRIM(email_address), '') AS normalized_email
FROM patient_info
ORDER BY patient_id;

SELECT
    patient_id,
    patient_name,
    COALESCE(
        NULLIF(BTRIM(email_address), ''),
        NULLIF(BTRIM(mobile_phone), ''),
        NULLIF(BTRIM(home_phone), ''),
        'No contact provided'
    ) AS preferred_contact
FROM patient_info
ORDER BY patient_id;

-- ============================================================
-- SECTION 5 - PRACTICE
-- ============================================================
-- 1. Write a rule requiring explicit consent for an entire
--    age/diagnosis condition. Use parentheses.
-- 2. Build preferred contact: email -> mobile -> home -> fallback.
-- 3. Classify bills into Unknown, No Charge, High-Value,
--    Standard, and Low-Value.
-- 4. Include statuses that are not definitely Paid using a
--    NULL-safe predicate.
-- 5. Classify completed admissions by length of stay.
--
-- CHECKLIST
-- [ ] I use parentheses when AND and OR are mixed.
-- [ ] I distinguish NULL from blank text and FALSE.
-- [ ] I understand UNKNOWN in WHERE conditions.
-- [ ] I order CASE branches from specific/high-priority to broad.
-- [ ] I test boundary values and NULL cases.
-- ============================================================
