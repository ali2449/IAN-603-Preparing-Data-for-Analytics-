-- ============================================================
-- IAN 603 - MODULE 6
-- Joining Data in PostgreSQL
-- ============================================================
-- Companion file for s_module6.html
-- PostgreSQL / pgAdmin Query Tool
--
-- Topics:
-- INNER, LEFT, RIGHT, FULL OUTER JOIN, anti-joins, ON vs WHERE,
-- USING, self joins, cross joins, cardinality, pre-aggregation,
-- and join validation.
--
-- Main habit: define what one output row should represent before
-- choosing and writing the join.
-- ============================================================

-- ============================================================
-- SECTION 1 - CREATE / RESET TEACHING DATABASE
-- ============================================================

DROP TABLE IF EXISTS appointment_slots CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS patient_vitals CASCADE;
DROP TABLE IF EXISTS prescriptions CASCADE;
DROP TABLE IF EXISTS lab_results CASCADE;
DROP TABLE IF EXISTS admissions_stage CASCADE;
DROP TABLE IF EXISTS admissions CASCADE;
DROP TABLE IF EXISTS medical_staff CASCADE;
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
    floor_no integer NOT NULL,
    service_line varchar(80) NOT NULL
);

CREATE TABLE medical_staff (
    staff_id integer PRIMARY KEY,
    name varchar(100) NOT NULL,
    department varchar(60) REFERENCES departments(department),
    specialization varchar(80) NOT NULL,
    hire_date date NOT NULL
);

CREATE TABLE admissions (
    admission_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    admit_date date NOT NULL,
    discharge_date date,
    diagnosis varchar(120) NOT NULL,
    department varchar(60) NOT NULL REFERENCES departments(department),
    attending_staff_id integer REFERENCES medical_staff(staff_id),
    CHECK (discharge_date IS NULL OR discharge_date >= admit_date)
);

-- Staging data intentionally has no foreign key so students can see an orphan row.
CREATE TABLE admissions_stage (
    import_row_id integer PRIMARY KEY,
    patient_id integer,
    diagnosis varchar(120),
    source_file varchar(80)
);

CREATE TABLE lab_results (
    test_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    test_name varchar(60) NOT NULL,
    result_value numeric(10,2),
    test_date date NOT NULL,
    normal_range varchar(30)
);

CREATE TABLE prescriptions (
    rx_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    medication varchar(100) NOT NULL,
    dosage varchar(50) NOT NULL,
    prescribed_date date NOT NULL,
    duration_days integer CHECK (duration_days > 0)
);

CREATE TABLE patient_vitals (
    vital_id integer PRIMARY KEY,
    patient_id integer NOT NULL REFERENCES patients(patient_id),
    vital_name varchar(50) NOT NULL,
    vital_value numeric(10,2),
    recorded_date date NOT NULL
);

CREATE TABLE appointment_slots (
    slot_label varchar(30) PRIMARY KEY
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
('Cardiology',3,'Cardiovascular'),
('Endocrinology',4,'Medicine'),
('Internal Medicine',2,'Medicine'),
('Neurology',5,'Neurosciences'),
('Orthopedics',1,'Musculoskeletal'),
('Pulmonology',4,'Medicine'),
('Dermatology',6,'Specialty Care');

INSERT INTO medical_staff VALUES
(501,'Dr. Sarah Chen','Cardiology','Cardiologist','2020-03-15'),
(502,'Dr. Michael Rodriguez','Internal Medicine','Internist','2019-07-22'),
(503,'Dr. Emily Watson','Orthopedics','Orthopedic Surgeon','2021-01-10'),
(504,'Dr. James Kim','Neurology','Neurologist','2018-11-30'),
(505,'Dr. Lisa Thompson','Endocrinology','Endocrinologist','2022-05-18'),
(506,'Dr. Robert Brown','Pulmonology','Pulmonologist','2020-09-05'),
(507,'Dr. Amanda Garcia','Cardiology','Cardiac Electrophysiologist','2021-08-12');

INSERT INTO admissions VALUES
(101,1001,'2026-01-15','2026-01-20','Pneumonia','Internal Medicine',502),
(102,1002,'2026-01-16','2026-01-18','Fractured arm','Orthopedics',503),
(103,1003,'2026-01-17','2026-01-25','Cardiac arrhythmia','Cardiology',501),
(104,1001,'2026-03-05','2026-03-12','Hypertension','Internal Medicine',502),
(105,1004,'2026-02-19','2026-02-26','Heart disease','Cardiology',507),
(106,1005,'2026-04-20','2026-04-22','Migraine','Neurology',504),
(107,1006,'2026-05-21','2026-05-28','Diabetes complications','Endocrinology',505),
(108,1007,'2026-05-22','2026-05-24','Asthma','Pulmonology',506),
(109,1008,'2026-06-23','2026-06-30','Cardiac monitoring','Cardiology',501),
(110,1009,'2026-07-24','2026-07-27','Joint pain','Orthopedics',503),
(111,1010,'2026-07-25',NULL,'Hypertension','Internal Medicine',502),
(112,1006,'2026-08-01','2026-08-05','Cardiac assessment','Cardiology',507);

INSERT INTO admissions_stage VALUES
(9001,1001,'Pneumonia','july_import.csv'),
(9002,1010,'Hypertension','july_import.csv'),
(9003,1999,'External transfer','july_import.csv');

INSERT INTO lab_results VALUES
(201,1001,'Glucose',98,'2026-01-16','70-110'),
(202,1002,'Cholesterol',185,'2026-01-17','<200'),
(203,1003,'Glucose',145,'2026-01-18','70-110'),
(204,1004,'Blood Pressure',150,'2026-02-19','<140'),
(205,1005,'Cholesterol',210,'2026-04-20','<200'),
(206,1006,'Glucose',320,'2026-05-21','70-110'),
(207,1007,'Blood Pressure',128,'2026-05-22','<140'),
(208,1008,'Cholesterol',195,'2026-06-23','<200'),
(209,1009,'Glucose',110,'2026-07-24','70-110'),
(210,1010,'Blood Pressure',142,'2026-07-25','<140'),
(211,1001,'Hemoglobin',14.2,'2026-01-16','12-16'),
(212,1003,'Hemoglobin',11.8,'2026-01-18','12-16');

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

INSERT INTO patient_vitals VALUES
(401,1001,'Heart Rate',88,'2026-01-15'),
(402,1001,'Temperature C',38.4,'2026-01-15'),
(403,1003,'Heart Rate',104,'2026-01-17'),
(404,1004,'Systolic BP',150,'2026-02-19'),
(405,1006,'Glucose',320,'2026-05-21');

INSERT INTO appointment_slots VALUES
('08:00'),('10:00'),('13:00');

-- ============================================================
-- SECTION 2 - RELATIONSHIP / GRAIN GUIDE
-- ============================================================
-- patients          : one row per patient
-- admissions        : one row per admission
-- lab_results       : one row per lab test
-- prescriptions     : one row per prescription
-- medical_staff     : one row per staff member
-- departments       : one row per department
-- admissions_stage  : imported rows; may contain unmatched IDs
--
-- Joining patients to admissions changes grain from patient
-- to admission detail when a patient has multiple admissions.

-- ============================================================
-- SECTION 3 - RUNNABLE MODULE EXAMPLES
-- ============================================================


-- Example 01
SELECT p.patient_id, p.name, a.admission_id, a.diagnosis, a.department
FROM patients AS p
INNER JOIN admissions AS a
  ON a.patient_id = p.patient_id
ORDER BY p.patient_id, a.admit_date;


-- Example 02
SELECT p.patient_id, p.name, a.admission_id, a.diagnosis
FROM patients AS p
LEFT JOIN admissions AS a
  ON a.patient_id = p.patient_id
ORDER BY p.patient_id, a.admission_id;


-- Example 03
SELECT p.patient_id, p.name
FROM patients AS p
LEFT JOIN lab_results AS l
  ON l.patient_id = p.patient_id
WHERE l.test_id IS NULL
ORDER BY p.patient_id;


-- Example 04
SELECT d.department, d.floor_no, s.name AS staff_name, s.specialization
FROM medical_staff AS s
RIGHT JOIN departments AS d
  ON d.department = s.department
ORDER BY d.department, s.name;


-- Example 05
SELECT COALESCE(p.patient_id, s.patient_id) AS patient_id,
       p.name,
       s.import_row_id,
       s.diagnosis,
       CASE
         WHEN p.patient_id IS NULL THEN 'Staging row has no patient master'
         WHEN s.import_row_id IS NULL THEN 'Patient has no staging row'
         ELSE 'Matched'
       END AS match_status
FROM patients AS p
FULL OUTER JOIN admissions_stage AS s
  ON s.patient_id = p.patient_id
ORDER BY COALESCE(p.patient_id, s.patient_id);


-- Example 06
SELECT p.patient_id, p.name, l.test_id, l.result_value
FROM patients AS p
LEFT JOIN lab_results AS l
  ON l.patient_id = p.patient_id
 AND l.test_name = 'Glucose'
ORDER BY p.patient_id;


-- Example 07
SELECT p.patient_id, p.name, l.test_id, l.result_value
FROM patients AS p
LEFT JOIN lab_results AS l
  ON l.patient_id = p.patient_id
WHERE l.test_name = 'Glucose'
ORDER BY p.patient_id;


-- Example 08
SELECT patient_id, p.name, a.admission_id, a.diagnosis
FROM patients AS p
JOIN admissions AS a USING (patient_id)
ORDER BY patient_id, a.admission_id;


-- Example 09
SELECT s1.department,
       s1.name AS staff_member,
       s2.name AS colleague
FROM medical_staff AS s1
JOIN medical_staff AS s2
  ON s1.department = s2.department
 AND s1.staff_id < s2.staff_id
ORDER BY s1.department, s1.name;


-- Example 10
SELECT a1.patient_id, p.name,
       a1.admission_id AS earlier_admission,
       a2.admission_id AS later_admission,
       a2.admit_date - a1.discharge_date AS days_between
FROM admissions AS a1
JOIN admissions AS a2
  ON a1.patient_id = a2.patient_id
 AND a1.admission_id < a2.admission_id
JOIN patients AS p
  ON p.patient_id = a1.patient_id
WHERE a1.discharge_date IS NOT NULL
  AND a2.admit_date - a1.discharge_date BETWEEN 1 AND 90
ORDER BY days_between;


-- Example 11
SELECT d.department, s.slot_label
FROM departments AS d
CROSS JOIN appointment_slots AS s
WHERE d.department IN ('Cardiology','Internal Medicine')
ORDER BY d.department, s.slot_label;


-- Example 12
SELECT p.patient_id, p.name,
       COUNT(*) AS joined_rows,
       COUNT(DISTINCT a.admission_id) AS admissions,
       COUNT(DISTINCT l.test_id) AS labs,
       COUNT(DISTINCT pr.rx_id) AS prescriptions
FROM patients AS p
LEFT JOIN admissions AS a ON a.patient_id = p.patient_id
LEFT JOIN lab_results AS l ON l.patient_id = p.patient_id
LEFT JOIN prescriptions AS pr ON pr.patient_id = p.patient_id
GROUP BY p.patient_id, p.name
ORDER BY joined_rows DESC, p.patient_id;


-- Example 13
WITH admission_counts AS (
  SELECT patient_id, COUNT(*) AS admissions
  FROM admissions
  GROUP BY patient_id
),
lab_counts AS (
  SELECT patient_id, COUNT(*) AS labs
  FROM lab_results
  GROUP BY patient_id
),
rx_counts AS (
  SELECT patient_id, COUNT(*) AS prescriptions
  FROM prescriptions
  GROUP BY patient_id
)
SELECT p.patient_id, p.name,
       COALESCE(a.admissions,0) AS admissions,
       COALESCE(l.labs,0) AS labs,
       COALESCE(r.prescriptions,0) AS prescriptions
FROM patients AS p
LEFT JOIN admission_counts AS a USING (patient_id)
LEFT JOIN lab_counts AS l USING (patient_id)
LEFT JOIN rx_counts AS r USING (patient_id)
ORDER BY p.patient_id;


-- Example 14
SELECT p.name,
       a.admission_id,
       a.diagnosis,
       a.department,
       ms.name AS attending_clinician,
       ms.specialization
FROM patients AS p
JOIN admissions AS a
  ON a.patient_id = p.patient_id
LEFT JOIN medical_staff AS ms
  ON ms.staff_id = a.attending_staff_id
ORDER BY a.admit_date, p.name;


-- Example 15
SELECT d.department,
       COUNT(DISTINCT a.admission_id) AS admissions,
       COUNT(DISTINCT a.patient_id) AS patients,
       COUNT(DISTINCT s.staff_id) AS staff_count,
       ROUND(AVG(a.discharge_date - a.admit_date),1) AS avg_stay_days,
       string_agg(DISTINCT s.specialization, ', ' ORDER BY s.specialization) AS specializations
FROM departments AS d
LEFT JOIN admissions AS a
  ON a.department = d.department
LEFT JOIN medical_staff AS s
  ON s.department = d.department
GROUP BY d.department
ORDER BY admissions DESC, d.department;


-- Example 16
SELECT p.patient_id, p.name,
       COUNT(*) AS joined_rows,
       COUNT(a.admission_id) AS naive_admission_count,
       COUNT(DISTINCT a.admission_id) AS true_admissions
FROM patients AS p
LEFT JOIN admissions AS a ON a.patient_id = p.patient_id
LEFT JOIN lab_results AS l ON l.patient_id = p.patient_id
LEFT JOIN prescriptions AS pr ON pr.patient_id = p.patient_id
GROUP BY p.patient_id, p.name
ORDER BY joined_rows DESC, p.patient_id;


-- Example 17
SELECT p.patient_id, p.name, l.test_id, l.result_value
FROM patients AS p
LEFT JOIN lab_results AS l
  ON l.patient_id = p.patient_id
 AND l.test_name = 'Glucose'
ORDER BY p.patient_id;


-- Example 18
WITH patient_timeline AS (
    SELECT patient_id, admit_date AS event_date, 'Admission'::text AS event_type,
           diagnosis::text AS event_details
    FROM admissions
    UNION ALL
    SELECT patient_id, test_date, 'Lab Test',
           test_name || ': ' || COALESCE(result_value::text,'NULL')
    FROM lab_results
    UNION ALL
    SELECT patient_id, prescribed_date, 'Prescription',
           medication || ' - ' || dosage
    FROM prescriptions
)
SELECT p.name, t.event_date, t.event_type, t.event_details
FROM patient_timeline AS t
JOIN patients AS p USING (patient_id)
ORDER BY p.name, t.event_date, t.event_type;


-- Example 19
WITH seq AS (
    SELECT patient_id, department, admit_date,
           LEAD(department) OVER (PARTITION BY patient_id ORDER BY admit_date) AS next_department,
           LEAD(admit_date) OVER (PARTITION BY patient_id ORDER BY admit_date) AS next_admit_date
    FROM admissions
)
SELECT department AS from_department,
       next_department AS to_department,
       COUNT(*) AS transitions,
       ROUND(AVG(next_admit_date - admit_date),1) AS avg_days_between
FROM seq
WHERE next_department IS NOT NULL
  AND department IS DISTINCT FROM next_department
GROUP BY department, next_department
ORDER BY transitions DESC, from_department, to_department;


-- Example 20
WITH admission_counts AS (
  SELECT patient_id, COUNT(*) AS admissions
  FROM admissions
  GROUP BY patient_id
),
lab_counts AS (
  SELECT patient_id, COUNT(*) AS labs
  FROM lab_results
  GROUP BY patient_id
),
rx_counts AS (
  SELECT patient_id, COUNT(*) AS prescriptions
  FROM prescriptions
  GROUP BY patient_id
)
SELECT p.patient_id, p.name,
       COALESCE(a.admissions,0) AS admissions,
       COALESCE(l.labs,0) AS labs,
       COALESCE(r.prescriptions,0) AS prescriptions
FROM patients AS p
LEFT JOIN admission_counts AS a USING (patient_id)
LEFT JOIN lab_counts AS l USING (patient_id)
LEFT JOIN rx_counts AS r USING (patient_id)
ORDER BY p.patient_id;


-- ============================================================
-- SECTION 4 - JOIN VALIDATION
-- ============================================================

-- Compare source admissions with patient-admission INNER JOIN.
SELECT COUNT(*) AS admission_rows
FROM admissions;

SELECT COUNT(*) AS joined_rows
FROM patients AS p
JOIN admissions AS a
  ON a.patient_id = p.patient_id;

-- Find patient IDs with no admission.
SELECT p.patient_id, p.name
FROM patients AS p
LEFT JOIN admissions AS a
  ON a.patient_id = p.patient_id
WHERE a.admission_id IS NULL
ORDER BY p.patient_id;

-- Detect staging records without a patient master.
SELECT s.*
FROM admissions_stage AS s
LEFT JOIN patients AS p
  ON p.patient_id = s.patient_id
WHERE p.patient_id IS NULL
ORDER BY s.import_row_id;

-- Demonstrate row multiplication when multiple child tables are
-- joined directly at patient level.
SELECT p.patient_id, p.name,
       COUNT(*) AS joined_rows,
       COUNT(DISTINCT a.admission_id) AS admissions,
       COUNT(DISTINCT l.test_id) AS labs,
       COUNT(DISTINCT r.rx_id) AS prescriptions
FROM patients AS p
LEFT JOIN admissions AS a ON a.patient_id = p.patient_id
LEFT JOIN lab_results AS l ON l.patient_id = p.patient_id
LEFT JOIN prescriptions AS r ON r.patient_id = p.patient_id
GROUP BY p.patient_id, p.name
ORDER BY joined_rows DESC, p.patient_id;

-- ============================================================
-- SECTION 5 - PRACTICE
-- ============================================================
-- 1. INNER JOIN patients to admissions.
-- 2. LEFT JOIN patients to admissions and preserve all patients.
-- 3. Find patients with no lab result.
-- 4. Keep all patients while matching only Glucose labs.
-- 5. Pre-aggregate admissions, labs, and prescriptions by patient
--    before joining the summaries.
-- 6. Summarize admissions and staff counts by department.
--
-- CHECKLIST
-- [ ] I can state the target grain.
-- [ ] I know which side/population must be preserved.
-- [ ] I understand one-to-many row expansion.
-- [ ] I distinguish filtering in ON from filtering in WHERE.
-- [ ] I validate counts and unmatched rows after joining.
-- ============================================================
