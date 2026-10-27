-- ============================================================
-- IAN 603 - MODULE 3
-- PostgreSQL in Action
-- ============================================================
-- Companion file for s_module3.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- SELECT, filtering, aliases, INSERT, UPDATE, DELETE, RETURNING,
-- transactions, JSONB, CREATE TABLE AS, and MERGE.
--
-- SAFETY HABIT
-- Before UPDATE or DELETE, preview the target rows with SELECT.
-- Use RETURNING when useful, and use transactions when testing.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP TABLE IF EXISTS clinical_notes, admissions, doctors, patients CASCADE;
    CREATE TABLE patients (
      patient_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      mrn text NOT NULL UNIQUE,
      full_name text NOT NULL,
      age smallint NOT NULL CHECK (age BETWEEN 0 AND 120),
      gender text NOT NULL,
      is_active boolean NOT NULL DEFAULT TRUE
    );
    CREATE TABLE doctors (
      doctor_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      full_name text NOT NULL,
      specialty text NOT NULL
    );
    CREATE TABLE admissions (
      admission_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      patient_id integer NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,
      doctor_id integer NOT NULL REFERENCES doctors(doctor_id) ON DELETE RESTRICT,
      diagnosis text NOT NULL,
      admission_date date NOT NULL,
      discharge_date date,
      status text NOT NULL DEFAULT 'Admitted',
      CHECK (discharge_date IS NULL OR discharge_date >= admission_date)
    );
    CREATE TABLE clinical_notes (
      note_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      patient_id integer NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
      note jsonb NOT NULL
    );
    INSERT INTO patients (mrn,full_name,age,gender,is_active) VALUES
      ('MRN1001','Carol Nguyen',42,'Female',TRUE),
      ('MRN1002','Bob Smith',68,'Male',TRUE),
      ('MRN1003','Elena Garcia',34,'Female',TRUE),
      ('MRN1004','David Lee',72,'Male',TRUE),
      ('MRN1005','Amina Yusuf',58,'Female',TRUE),
      ('MRN1006','Marcus Reed',27,'Male',TRUE);
    INSERT INTO doctors (full_name,specialty) VALUES
      ('Jordan Chen','Family Medicine'),
      ('Priya Shah','Internal Medicine'),
      ('Noah Bennett','Cardiology');
    INSERT INTO admissions (patient_id,doctor_id,diagnosis,admission_date,discharge_date,status) VALUES
      (1,1,'Asthma','2023-02-18','2023-02-20','Discharged'),
      (2,3,'Chest pain','2023-03-04','2023-03-07','Discharged'),
      (4,2,'Dehydration','2023-03-10',NULL,'Admitted'),
      (5,1,'Migraine','2023-04-02','2023-04-03','Discharged'),
      (3,2,'Pneumonia','2023-05-11',NULL,'Admitted');
    INSERT INTO clinical_notes (patient_id,note) VALUES
      (1,'{"symptom":"wheezing","severity":"moderate","follow_up":true}'::jsonb),
      (2,'{"symptom":"chest pain","severity":"severe","follow_up":true}'::jsonb),
      (3,'{"symptom":"cough","severity":"moderate","follow_up":true}'::jsonb),
      (5,'{"symptom":"headache","severity":"mild","follow_up":false}'::jsonb);

-- ============================================================
-- SECTION 2 - QUICK TABLE CHECK
-- ============================================================
SELECT * FROM patients ORDER BY patient_id;
SELECT * FROM doctors ORDER BY doctor_id;
SELECT * FROM admissions ORDER BY admission_id;
SELECT * FROM clinical_notes ORDER BY note_id;

-- ============================================================
-- SECTION 3 - RUNNABLE MODULE EXAMPLES
-- ============================================================
-- Run examples individually. Some examples intentionally change
-- the database state. Re-run SECTION 1 to restore the baseline.


-- ------------------------------------------------------------
-- Example 01
-- ------------------------------------------------------------
SELECT patient_id, mrn, full_name, age, gender, is_active
FROM patients
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 02
-- ------------------------------------------------------------
SELECT mrn, full_name, age
FROM patients
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 03
-- ------------------------------------------------------------
SELECT mrn,
       full_name AS patient,
       age,
       age >= 65 AS is_senior
FROM patients
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 04
-- ------------------------------------------------------------
SELECT mrn, full_name, age, is_active
FROM patients
WHERE is_active = TRUE
  AND age >= 50
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 05
-- ------------------------------------------------------------
SELECT mrn, full_name, age, gender
FROM patients
WHERE gender = 'Female'
  AND age BETWEEN 30 AND 60
ORDER BY age;


-- ------------------------------------------------------------
-- Example 06
-- ------------------------------------------------------------
SELECT mrn, full_name
FROM patients
WHERE full_name ILIKE 'c%';


-- ------------------------------------------------------------
-- Example 07
-- ------------------------------------------------------------
SELECT admission_id, patient_id, diagnosis, admission_date, discharge_date
FROM admissions
WHERE discharge_date IS NULL
ORDER BY admission_date;


-- ------------------------------------------------------------
-- Example 08
-- ------------------------------------------------------------
SELECT admission_id, patient_id, diagnosis, admission_date
FROM admissions
ORDER BY admission_date DESC, admission_id DESC
LIMIT 3;


-- ------------------------------------------------------------
-- Example 09
-- ------------------------------------------------------------
INSERT INTO patients (mrn, full_name, age, gender)
VALUES ('MRN1010', 'Ivy Carter', 50, 'Female')
RETURNING patient_id, mrn, full_name, age, gender;


-- ------------------------------------------------------------
-- Example 10
-- ------------------------------------------------------------
SELECT patient_id, mrn, full_name, age
FROM patients
WHERE mrn = 'MRN1003';

UPDATE patients
SET age = 35
WHERE mrn = 'MRN1003'
RETURNING patient_id, mrn, full_name, age;


-- ------------------------------------------------------------
-- Example 11
-- ------------------------------------------------------------
UPDATE patients
SET is_active = FALSE
WHERE mrn = 'MRN1004'
RETURNING patient_id, mrn, full_name, is_active;


-- ------------------------------------------------------------
-- Example 12
-- ------------------------------------------------------------
DELETE FROM patients
WHERE mrn = 'MRN1004';


-- ------------------------------------------------------------
-- Example 13
-- ------------------------------------------------------------
BEGIN;

UPDATE patients
SET age = 35
WHERE mrn = 'MRN1003'
RETURNING patient_id, mrn, full_name, age;

ROLLBACK;

SELECT mrn, full_name, age
FROM patients
WHERE mrn = 'MRN1003';


-- ------------------------------------------------------------
-- Example 14
-- ------------------------------------------------------------
-- 1. Start a transaction

-- 2. Update MRN1005 to age 59 and use RETURNING

-- 3. Roll back the transaction

-- 4. SELECT MRN1005 again to verify the original age;


-- ------------------------------------------------------------
-- Example 15
-- ------------------------------------------------------------
SELECT patient_id,
       note->>'symptom' AS symptom,
       note->>'severity' AS severity,
       (note->>'follow_up')::boolean AS follow_up
FROM clinical_notes
WHERE note->>'severity' IN ('moderate', 'severe')
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 16
-- ------------------------------------------------------------
CREATE TABLE senior_patients (
  patient_id integer PRIMARY KEY,
  mrn text NOT NULL,
  full_name text NOT NULL,
  age smallint NOT NULL
);

INSERT INTO senior_patients (patient_id, mrn, full_name, age)
SELECT patient_id, mrn, full_name, age
FROM patients
WHERE age >= 65;

SELECT *
FROM senior_patients
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 17
-- ------------------------------------------------------------
CREATE TEMP TABLE incoming_patients (
  mrn text,
  full_name text,
  age smallint,
  gender text
);

INSERT INTO incoming_patients VALUES
('MRN1002', 'Bob Smith', 69, 'Male'),
('MRN1007', 'Grace Hall', 55, 'Female');

MERGE INTO patients AS target
USING incoming_patients AS source
ON target.mrn = source.mrn
WHEN MATCHED THEN
  UPDATE SET full_name = source.full_name,
             age = source.age,
             gender = source.gender
WHEN NOT MATCHED THEN
  INSERT (mrn, full_name, age, gender)
  VALUES (source.mrn, source.full_name, source.age, source.gender);

SELECT mrn, full_name, age, gender
FROM patients
WHERE mrn IN ('MRN1002','MRN1007')
ORDER BY mrn;


-- ------------------------------------------------------------
-- Example 18
-- ------------------------------------------------------------
-- Choose Task A or Task B and write your SQL here.;


-- ------------------------------------------------------------
-- Example 19
-- ------------------------------------------------------------
SELECT mrn, full_name, age
FROM patients
WHERE
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 20
-- ------------------------------------------------------------
INSERT INTO patients (mrn, full_name, age, gender)
VALUES
RETURNING mrn, full_name, age, gender;


-- ------------------------------------------------------------
-- Example 21
-- ------------------------------------------------------------
UPDATE patients
SET
WHERE
RETURNING mrn, full_name, age;


-- ------------------------------------------------------------
-- Example 22
-- ------------------------------------------------------------
BEGIN;

-- UPDATE MRN1005 here

-- ROLLBACK here

SELECT mrn, full_name, age
FROM patients
WHERE mrn = 'MRN1005';


-- ------------------------------------------------------------
-- Example 23
-- ------------------------------------------------------------
SELECT patient_id,
       note->>'symptom' AS symptom,
       note->>'severity' AS severity
FROM clinical_notes
WHERE
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 24
-- ------------------------------------------------------------
${escapeText(saved)};


-- ============================================================
-- SECTION 4 - SAFE WRITE PATTERN
-- ============================================================

-- Preview.
SELECT patient_id, mrn, full_name, age
FROM patients
WHERE mrn = 'MRN1003';

-- Test inside a transaction.
BEGIN;

UPDATE patients
SET age = 35
WHERE mrn = 'MRN1003'
RETURNING patient_id, mrn, full_name, age;

ROLLBACK;

-- Verify original state.
SELECT patient_id, mrn, full_name, age
FROM patients
WHERE mrn = 'MRN1003';

-- ============================================================
-- SECTION 5 - PRACTICE
-- ============================================================
-- 1. Return active patients age 50 or older.
-- 2. Find patients whose name begins with C.
-- 3. Insert a new patient and use RETURNING.
-- 4. Test an UPDATE inside BEGIN / ROLLBACK.
-- 5. Extract symptom and severity from the JSONB note.
-- 6. Explain when MERGE is useful.
--
-- CHECKLIST
-- [ ] I know whether my statement reads, changes, or defines data.
-- [ ] I preview rows before UPDATE or DELETE.
-- [ ] I use stable identifiers in write conditions.
-- [ ] I understand COMMIT versus ROLLBACK.
-- [ ] I can query simple JSONB fields.
-- ============================================================
