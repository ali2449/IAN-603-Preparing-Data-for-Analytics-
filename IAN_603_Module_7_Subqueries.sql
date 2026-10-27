-- ============================================================
-- IAN 603 - MODULE 7
-- Subqueries in PostgreSQL
-- ============================================================
-- Companion file for s_module7.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- scalar and multi-row subqueries, IN, EXISTS, NOT EXISTS,
-- correlated subqueries, derived tables, nested logic, and CTEs.
--
-- Choose a pattern based on the shape of the value or row set
-- needed by the outer query.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP TABLE IF EXISTS review_queue CASCADE;
DROP TABLE IF EXISTS prescriptions CASCADE;
DROP TABLE IF EXISTS lab_results CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

CREATE TABLE patients (
    patient_id integer PRIMARY KEY,
    name varchar(100) NOT NULL,
    age integer NOT NULL CHECK (age BETWEEN 0 AND 120),
    gender varchar(20),
    home_city varchar(60) NOT NULL
);

CREATE TABLE departments (
    department varchar(60) PRIMARY KEY,
    service_line varchar(80) NOT NULL
);

CREATE TABLE admissions (
    admission_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    admit_date date NOT NULL,
    discharge_date date,
    diagnosis varchar(120) NOT NULL,
    department varchar(60) NOT NULL REFERENCES departments(department),
    CHECK (discharge_date IS NULL OR discharge_date >= admit_date)
);

CREATE TABLE lab_results (
    test_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    test_name varchar(60) NOT NULL,
    result_value numeric(10,2),
    test_date date NOT NULL,
    normal_low numeric(10,2),
    normal_high numeric(10,2)
);

CREATE TABLE prescriptions (
    rx_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    medication varchar(100) NOT NULL,
    dosage varchar(50) NOT NULL,
    prescribed_date date NOT NULL,
    duration_days integer CHECK (duration_days > 0)
);

-- The NULL is deliberate: it lets students see why NOT IN can be unsafe.
CREATE TABLE review_queue (
    queue_id integer PRIMARY KEY,
    patient_id integer
);

INSERT INTO patients VALUES
(1001,'Alice Smith',45,'Female','Greensboro'),
(1002,'Bob Johnson',32,'Male','High Point'),
(1003,'Carol White',58,'Female','Greensboro'),
(1004,'David Brown',67,'Male','Burlington'),
(1005,'Eve Davis',29,'Female','Greensboro'),
(1006,'Frank Miller',71,'Male','Reidsville'),
(1007,'Grace Wilson',52,'Female','Greensboro'),
(1008,'Henry Taylor',48,'Male','High Point'),
(1009,'Ivy Clark',63,'Female','Greensboro'),
(1010,'Jack Anderson',55,'Male','Burlington'),
(1011,'Kara Young',41,'Female','Greensboro');

INSERT INTO departments VALUES
('Cardiology','Cardiovascular'),
('Endocrinology','Medicine'),
('Internal Medicine','Medicine'),
('Neurology','Neurosciences'),
('Orthopedics','Musculoskeletal'),
('Pulmonology','Medicine');

INSERT INTO admissions VALUES
(101,1001,'2026-01-15','2026-01-20','Pneumonia','Internal Medicine'),
(102,1002,'2026-01-16','2026-01-18','Fractured arm','Orthopedics'),
(103,1003,'2026-01-17','2026-01-25','Cardiac arrhythmia','Cardiology'),
(104,1001,'2026-03-05','2026-03-12','Hypertension','Internal Medicine'),
(105,1004,'2026-02-19','2026-02-26','Heart disease','Cardiology'),
(106,1005,'2026-04-20','2026-04-22','Migraine','Neurology'),
(107,1006,'2026-05-21','2026-05-28','Diabetes complications','Endocrinology'),
(108,1007,'2026-05-22','2026-05-24','Asthma','Pulmonology'),
(109,1008,'2026-06-23','2026-06-30','Cardiac monitoring','Cardiology'),
(110,1009,'2026-07-24','2026-07-27','Joint pain','Orthopedics'),
(111,1010,'2026-07-25',NULL,'Hypertension','Internal Medicine'),
(112,1006,'2026-08-01','2026-08-05','Cardiac assessment','Cardiology');

INSERT INTO lab_results VALUES
(201,1001,'Glucose',98,'2026-01-16',70,110),
(202,1002,'Cholesterol',185,'2026-01-17',0,200),
(203,1003,'Glucose',145,'2026-01-18',70,110),
(204,1004,'Systolic BP',150,'2026-02-19',90,140),
(205,1005,'Cholesterol',210,'2026-04-20',0,200),
(206,1006,'Glucose',320,'2026-05-21',70,110),
(207,1007,'Systolic BP',128,'2026-05-22',90,140),
(208,1008,'Cholesterol',195,'2026-06-23',0,200),
(209,1009,'Glucose',110,'2026-07-24',70,110),
(210,1010,'Systolic BP',142,'2026-07-25',90,140),
(211,1001,'Hemoglobin',14.2,'2026-01-16',12,16),
(212,1003,'Hemoglobin',11.8,'2026-01-18',12,16),
(213,1006,'Hemoglobin',10.9,'2026-05-21',12,16);

INSERT INTO prescriptions VALUES
(301,1001,'Amoxicillin','500mg','2026-01-16',7),
(302,1002,'Ibuprofen','400mg','2026-01-17',14),
(303,1003,'Metoprolol','25mg','2026-01-18',90),
(304,1004,'Atorvastatin','40mg','2026-02-19',30),
(305,1006,'Metformin','1000mg','2026-05-21',60),
(306,1006,'Insulin','50 units','2026-05-21',90),
(307,1001,'Lisinopril','5mg','2026-03-06',30),
(308,1007,'Albuterol','2 puffs','2026-05-22',15),
(309,1008,'Aspirin','81mg','2026-06-23',365),
(310,1009,'Ibuprofen','400mg','2026-07-24',7);

INSERT INTO review_queue VALUES
(1,1003),
(2,NULL);

-- ============================================================
-- SECTION 2 - MODULE EXAMPLES
-- ============================================================


-- ------------------------------------------------------------
-- Example 01: Preview patients
-- ------------------------------------------------------------
SELECT patient_id, name, age, home_city
FROM patients
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 02: Patients older than average
-- ------------------------------------------------------------
SELECT patient_id, name, age
FROM patients
WHERE age > (SELECT AVG(age) FROM patients)
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 03: Show the overall average beside each patient
-- ------------------------------------------------------------
SELECT patient_id, name, age,
       (SELECT ROUND(AVG(age),1) FROM patients) AS hospital_avg_age
FROM patients
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 04: No matching inner row
-- ------------------------------------------------------------
SELECT (
  SELECT result_value
  FROM lab_results
  WHERE test_id = 9999
) AS missing_scalar_result;


-- ------------------------------------------------------------
-- Example 05: Invalid scalar result
-- ------------------------------------------------------------
-- A scalar subquery must produce at most one row.
SELECT (SELECT patient_id FROM admissions) AS patient_id;


-- ------------------------------------------------------------
-- Example 06: Patient IDs in the Cardiology set
-- ------------------------------------------------------------
SELECT patient_id, name, age
FROM patients
WHERE patient_id IN (
  SELECT patient_id
  FROM admissions
  WHERE department = 'Cardiology'
)
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 07: Compare IN and JOIN
-- ------------------------------------------------------------
-- IN answers membership and returns each patient once.
SELECT p.patient_id, p.name
FROM patients AS p
WHERE p.patient_id IN (SELECT a.patient_id FROM admissions AS a)
ORDER BY p.patient_id;

-- A JOIN returns matching row combinations; repeat admissions can repeat a patient.
SELECT p.patient_id, p.name, a.admission_id
FROM patients AS p
JOIN admissions AS a ON a.patient_id = p.patient_id
ORDER BY p.patient_id, a.admission_id;


-- ------------------------------------------------------------
-- Example 08: NOT IN against review_queue
-- ------------------------------------------------------------
-- review_queue contains patient 1003 AND a NULL patient_id.
-- Because no comparison is definitively TRUE for many rows, NOT IN becomes UNKNOWN.
SELECT patient_id, name
FROM patients
WHERE patient_id NOT IN (SELECT patient_id FROM review_queue)
ORDER BY patient_id;


-- ------------------------------------------------------------
-- Example 09: Use NOT EXISTS
-- ------------------------------------------------------------
SELECT p.patient_id, p.name
FROM patients AS p
WHERE NOT EXISTS (
  SELECT 1
  FROM review_queue AS q
  WHERE q.patient_id = p.patient_id
)
ORDER BY p.patient_id;


-- ------------------------------------------------------------
-- Example 10: Abnormal lab exists
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, p.age
FROM patients AS p
WHERE EXISTS (
  SELECT 1
  FROM lab_results AS l
  WHERE l.patient_id = p.patient_id
    AND (l.result_value < l.normal_low OR l.result_value > l.normal_high)
)
ORDER BY p.age DESC;


-- ------------------------------------------------------------
-- Example 11: No prescriptions exist
-- ------------------------------------------------------------
SELECT p.patient_id, p.name
FROM patients AS p
WHERE NOT EXISTS (
  SELECT 1 FROM prescriptions AS pr
  WHERE pr.patient_id = p.patient_id
)
ORDER BY p.patient_id;


-- ------------------------------------------------------------
-- Example 12: age > ANY (...)
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, p.age
FROM patients AS p
WHERE p.age > ANY (
  SELECT p2.age
  FROM patients AS p2
  JOIN admissions AS a ON a.patient_id = p2.patient_id
  WHERE a.department = 'Cardiology'
)
ORDER BY p.age DESC;


-- ------------------------------------------------------------
-- Example 13: age > ALL (...)
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, p.age
FROM patients AS p
WHERE p.age > ALL (
  SELECT p2.age
  FROM patients AS p2
  JOIN admissions AS a ON a.patient_id = p2.patient_id
  WHERE a.department = 'Cardiology'
)
ORDER BY p.age DESC;


-- ------------------------------------------------------------
-- Example 14: Compare ANY and ALL with an empty set
-- ------------------------------------------------------------
SELECT
  45 > ANY (SELECT age FROM patients WHERE patient_id < 0) AS greater_than_any_empty,
  45 > ALL (SELECT age FROM patients WHERE patient_id < 0) AS greater_than_all_empty;


-- ------------------------------------------------------------
-- Example 15: Above the average for the same test
-- ------------------------------------------------------------
SELECT l.test_id, l.patient_id, l.test_name, l.result_value,
       ROUND((
         SELECT AVG(l2.result_value)
         FROM lab_results AS l2
         WHERE l2.test_name = l.test_name
       ),2) AS test_average
FROM lab_results AS l
WHERE l.result_value > (
  SELECT AVG(l3.result_value)
  FROM lab_results AS l3
  WHERE l3.test_name = l.test_name
)
ORDER BY l.test_name, l.result_value DESC;


-- ------------------------------------------------------------
-- Example 16: Admission count per patient
-- ------------------------------------------------------------
SELECT p.patient_id, p.name,
       (SELECT COUNT(*)
        FROM admissions AS a
        WHERE a.patient_id = p.patient_id) AS admission_count
FROM patients AS p
ORDER BY admission_count DESC, p.patient_id;


-- ------------------------------------------------------------
-- Example 17: Latest admission per patient
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, a.admission_id, a.admit_date, a.diagnosis
FROM patients AS p
JOIN admissions AS a ON a.patient_id = p.patient_id
WHERE a.admit_date = (
  SELECT MAX(a2.admit_date)
  FROM admissions AS a2
  WHERE a2.patient_id = p.patient_id
)
ORDER BY p.patient_id;


-- ------------------------------------------------------------
-- Example 18: Admission counts as a derived table
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, COALESCE(ac.admission_count,0) AS admission_count
FROM patients AS p
LEFT JOIN (
  SELECT patient_id, COUNT(*) AS admission_count
  FROM admissions
  GROUP BY patient_id
) AS ac ON ac.patient_id = p.patient_id
ORDER BY admission_count DESC, p.patient_id;


-- ------------------------------------------------------------
-- Example 19: Pre-aggregate then join
-- ------------------------------------------------------------
-- Same goal as a correlated count, expressed with pre-aggregation + join.
SELECT p.patient_id, p.name, COALESCE(a.admission_count,0) AS admission_count
FROM patients AS p
LEFT JOIN (
  SELECT patient_id, COUNT(*) AS admission_count
  FROM admissions
  GROUP BY patient_id
) AS a USING (patient_id)
ORDER BY admission_count DESC, p.patient_id;


-- ------------------------------------------------------------
-- Example 20: EXPLAIN an EXISTS query
-- ------------------------------------------------------------
EXPLAIN
SELECT p.patient_id, p.name
FROM patients AS p
WHERE EXISTS (
  SELECT 1 FROM admissions AS a
  WHERE a.patient_id = p.patient_id
);


-- ------------------------------------------------------------
-- Example 21: Average-age condition
-- ------------------------------------------------------------
SELECT patient_id, name, age
FROM patients
WHERE age > (SELECT AVG(age) FROM patients)
ORDER BY age DESC;


-- ------------------------------------------------------------
-- Example 22: Admission count per patient
-- ------------------------------------------------------------
SELECT p.patient_id, p.name,
       (SELECT COUNT(*)
        FROM admissions AS a
        WHERE a.patient_id = p.patient_id) AS admission_count
FROM patients AS p
ORDER BY admission_count DESC, p.patient_id;


-- ------------------------------------------------------------
-- Example 23: Abnormal lab exists
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, p.age
FROM patients AS p
WHERE EXISTS (
  SELECT 1
  FROM lab_results AS l
  WHERE l.patient_id = p.patient_id
    AND (l.result_value < l.normal_low OR l.result_value > l.normal_high)
)
ORDER BY p.age DESC;


-- ------------------------------------------------------------
-- Example 24: Distinct medication count
-- ------------------------------------------------------------
SELECT p.patient_id, p.name,
       (SELECT COUNT(DISTINCT pr.medication)
        FROM prescriptions AS pr
        WHERE pr.patient_id = p.patient_id) AS medication_count
FROM patients AS p
ORDER BY medication_count DESC, p.patient_id;


-- ------------------------------------------------------------
-- Example 25: Complex-patient query
-- ------------------------------------------------------------
SELECT p.patient_id, p.name, p.age
FROM patients AS p
WHERE p.age > (SELECT AVG(age) FROM patients)
  AND (SELECT COUNT(*) FROM admissions AS a WHERE a.patient_id = p.patient_id) > 1
  AND EXISTS (
      SELECT 1 FROM lab_results AS l
      WHERE l.patient_id = p.patient_id
        AND (l.result_value < l.normal_low OR l.result_value > l.normal_high)
  )
  AND (SELECT COUNT(DISTINCT pr.medication)
       FROM prescriptions AS pr
       WHERE pr.patient_id = p.patient_id) > 1
ORDER BY p.age DESC;


-- ------------------------------------------------------------
-- Example 26: Patient feature table
-- ------------------------------------------------------------
WITH patient_features AS (
  SELECT p.patient_id, p.name, p.age,
         (SELECT COUNT(*) FROM admissions a WHERE a.patient_id=p.patient_id) AS admissions,
         (SELECT COUNT(*) FROM lab_results l WHERE l.patient_id=p.patient_id AND (l.result_value<l.normal_low OR l.result_value>l.normal_high)) AS abnormal_labs,
         (SELECT COUNT(DISTINCT medication) FROM prescriptions pr WHERE pr.patient_id=p.patient_id) AS medications
  FROM patients p
)
SELECT *,
       (CASE WHEN age >= 65 THEN 3 WHEN age >= 50 THEN 2 ELSE 1 END
        + CASE WHEN admissions >= 2 THEN 2 WHEN admissions = 1 THEN 1 ELSE 0 END
        + LEAST(abnormal_labs,2)
        + LEAST(medications,2)) AS risk_score
FROM patient_features
ORDER BY risk_score DESC, patient_id;


-- ------------------------------------------------------------
-- Example 27: Department dashboard
-- ------------------------------------------------------------
SELECT a.department,
       COUNT(*) AS admissions,
       COUNT(DISTINCT a.patient_id) AS patients,
       ROUND(AVG(a.discharge_date - a.admit_date),1) AS avg_stay_days,
       (SELECT COUNT(*)
        FROM admissions AS x
        WHERE x.department = a.department
          AND x.discharge_date IS NULL) AS current_open_admissions
FROM admissions AS a
GROUP BY a.department
ORDER BY admissions DESC, a.department;


-- ------------------------------------------------------------
-- Example 28: Assessment starter
-- ------------------------------------------------------------
-- Assessment: return patients whose admission count is above
-- the average admission count among patients who have at least one admission.
-- Use a derived table and at least one subquery.

SELECT p.patient_id, p.name
FROM patients AS p
-- complete the query
ORDER BY p.patient_id;


-- ============================================================
-- SECTION 3 - SUBQUERY DECISION GUIDE
-- ============================================================
-- Need one value?          -> scalar subquery
-- Need a list of values?   -> IN or a multi-row subquery
-- Need existence only?     -> EXISTS / NOT EXISTS
-- Need row-specific logic? -> correlated subquery
-- Need a named stage?      -> CTE
-- Need a temporary relation in FROM? -> derived table

-- ============================================================
-- SECTION 4 - VALIDATION HABITS
-- ============================================================
-- [ ] Know whether the subquery should return one value or many.
-- [ ] Test the inner query by itself first.
-- [ ] Watch for NULL behavior with NOT IN.
-- [ ] Prefer EXISTS / NOT EXISTS for existence logic.
-- [ ] Confirm the outer-query grain after correlation.
-- ============================================================
