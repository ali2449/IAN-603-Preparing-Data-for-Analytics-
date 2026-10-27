-- ============================================================
-- IAN 603 - MODULE 2
-- Designing Relational Databases
-- ============================================================
-- Companion file for s_module2.html
-- PostgreSQL / pgAdmin Query Tool
--
-- This file focuses on:
--   * tables and row grain
--   * primary keys
--   * foreign keys
--   * UNIQUE and CHECK constraints
--   * one-to-many and many-to-many relationships
--   * a junction table
--   * basic indexes
--
-- Run the schema section first, then the sample data.
-- ============================================================

-- ============================================================
-- SECTION 1 - MAIN RELATIONAL SCHEMA
-- ============================================================

-- Reset the five related tables so the script can be rerun.
DROP TABLE IF EXISTS appointment_service, appointment, service, provider, patient CASCADE;

-- Parent table: one row per patient.
CREATE TABLE patient (
  patient_id bigint GENERATED ALWAYS AS IDENTITY,
  mrn        text NOT NULL,
  first_name text NOT NULL,
  last_name  text NOT NULL,
  birth_date date NOT NULL,
  email      text,
  CONSTRAINT pk_patient PRIMARY KEY (patient_id),
  CONSTRAINT uq_patient_mrn UNIQUE (mrn),
  CONSTRAINT uq_patient_email UNIQUE (email)
);

-- Parent table: one row per provider.
CREATE TABLE provider (
  provider_id   bigint GENERATED ALWAYS AS IDENTITY,
  npi           text NOT NULL,
  provider_name text NOT NULL,
  specialty     text,
  is_active     boolean NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_provider PRIMARY KEY (provider_id),
  CONSTRAINT uq_provider_npi UNIQUE (npi),
  CONSTRAINT chk_provider_npi CHECK (npi ~ '^[0-9]{10}$')
);

-- Parent table: one row per reusable service.
CREATE TABLE service (
  service_id     bigint GENERATED ALWAYS AS IDENTITY,
  service_code   text NOT NULL,
  service_name   text NOT NULL,
  standard_price numeric(10,2) NOT NULL,
  CONSTRAINT pk_service PRIMARY KEY (service_id),
  CONSTRAINT uq_service_code UNIQUE (service_code),
  CONSTRAINT chk_service_price CHECK (standard_price >= 0)
);

-- Event table: one row per scheduled appointment.
CREATE TABLE appointment (
  appointment_id bigint GENERATED ALWAYS AS IDENTITY,
  patient_id     bigint NOT NULL,
  provider_id    bigint NOT NULL,
  starts_at      timestamptz NOT NULL,
  ends_at        timestamptz NOT NULL,
  status         text NOT NULL DEFAULT 'scheduled',
  CONSTRAINT pk_appointment PRIMARY KEY (appointment_id),
  CONSTRAINT fk_appointment_patient
    FOREIGN KEY (patient_id) REFERENCES patient (patient_id) ON DELETE RESTRICT,
  CONSTRAINT fk_appointment_provider
    FOREIGN KEY (provider_id) REFERENCES provider (provider_id) ON DELETE RESTRICT,
  CONSTRAINT chk_appointment_time CHECK (ends_at > starts_at),
  CONSTRAINT chk_appointment_status CHECK (
    status IN ('scheduled', 'completed', 'cancelled', 'no_show')
  )
);

-- Junction table: one row per service used in one appointment.
CREATE TABLE appointment_service (
  appointment_id bigint NOT NULL,
  service_id     bigint NOT NULL,
  quantity       smallint NOT NULL DEFAULT 1,
  unit_charge    numeric(10,2) NOT NULL,
  CONSTRAINT pk_appointment_service PRIMARY KEY (appointment_id, service_id),
  CONSTRAINT fk_appointment_service_appointment
    FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id) ON DELETE CASCADE,
  CONSTRAINT fk_appointment_service_service
    FOREIGN KEY (service_id) REFERENCES service (service_id) ON DELETE RESTRICT,
  CONSTRAINT chk_appointment_service_quantity CHECK (quantity > 0),
  CONSTRAINT chk_appointment_service_charge CHECK (unit_charge >= 0)
);

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- ============================================================
-- SECTION 2 - SAMPLE DATA
-- ============================================================

-- Teaching reset: make this sample cell safe to rerun.
TRUNCATE TABLE appointment_service, appointment, service, provider, patient
RESTART IDENTITY CASCADE;

INSERT INTO patient (mrn, first_name, last_name, birth_date, email)
VALUES
  ('MRN-1001', 'Maya', 'Brooks', DATE '1988-04-12', 'maya.brooks@example.org'),
  ('MRN-1002', 'Evan', 'Lee', DATE '1976-11-03', NULL);

INSERT INTO provider (npi, provider_name, specialty)
VALUES
  ('1234567890', 'Jordan Chen', 'Family Medicine'),
  ('2345678901', 'Priya Shah', 'Internal Medicine');

INSERT INTO service (service_code, service_name, standard_price)
VALUES
  ('S101', 'Office Visit', 95.00),
  ('L220', 'Complete Blood Count', 28.00),
  ('V310', 'Influenza Vaccine', 42.50);

INSERT INTO appointment (patient_id, provider_id, starts_at, ends_at, status)
SELECT p.patient_id, pr.provider_id,
       TIMESTAMPTZ '2026-09-08 09:00:00-04',
       TIMESTAMPTZ '2026-09-08 09:30:00-04',
       'scheduled'
FROM patient AS p
CROSS JOIN provider AS pr
WHERE p.mrn = 'MRN-1001' AND pr.npi = '1234567890';

INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_charge)
SELECT a.appointment_id, s.service_id, 1, s.standard_price
FROM appointment AS a
JOIN patient AS p ON p.patient_id = a.patient_id
CROSS JOIN service AS s
WHERE p.mrn = 'MRN-1001' AND s.service_code IN ('S101', 'L220');

SELECT
  (SELECT count(*) FROM patient) AS patients,
  (SELECT count(*) FROM provider) AS providers,
  (SELECT count(*) FROM service) AS services,
  (SELECT count(*) FROM appointment) AS appointments,
  (SELECT count(*) FROM appointment_service) AS service_lines;

-- ============================================================
-- SECTION 3 - VERIFY KEYS AND RELATIONSHIPS
-- ============================================================

SELECT patient_id, mrn, first_name, last_name
FROM patient
ORDER BY patient_id;

SELECT provider_id, npi, provider_name, specialty
FROM provider
ORDER BY provider_id;

SELECT service_id, service_code, service_name, standard_price
FROM service
ORDER BY service_id;

SELECT
    a.appointment_id,
    p.mrn,
    p.first_name,
    p.last_name,
    pr.provider_name,
    a.starts_at,
    a.ends_at,
    a.status
FROM appointment AS a
JOIN patient AS p
  ON p.patient_id = a.patient_id
JOIN provider AS pr
  ON pr.provider_id = a.provider_id
ORDER BY a.starts_at;

-- Many-to-many relationship resolved through appointment_service.
SELECT
    a.appointment_id,
    p.mrn,
    s.service_code,
    s.service_name,
    aps.quantity,
    aps.unit_charge,
    aps.quantity * aps.unit_charge AS line_total
FROM appointment AS a
JOIN patient AS p
  ON p.patient_id = a.patient_id
JOIN appointment_service AS aps
  ON aps.appointment_id = a.appointment_id
JOIN service AS s
  ON s.service_id = aps.service_id
ORDER BY a.appointment_id, s.service_code;

-- ============================================================
-- SECTION 4 - INSPECT CONSTRAINTS
-- ============================================================

SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints AS tc
WHERE tc.table_schema = 'public'
  AND tc.table_name IN (
      'patient','provider','service','appointment','appointment_service'
  )
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- ============================================================
-- SECTION 5 - INDEX EXAMPLES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_appointment_patient_time
  ON appointment (patient_id, starts_at);

CREATE INDEX IF NOT EXISTS idx_appointment_provider_time
  ON appointment (provider_id, starts_at);

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'appointment'
ORDER BY indexname;

-- ============================================================
-- SECTION 6 - DESIGN VALIDATION
-- ============================================================

-- Each MRN should identify at most one patient.
SELECT mrn, COUNT(*) AS row_count
FROM patient
GROUP BY mrn
HAVING COUNT(*) > 1;

-- Each appointment-service pair should be unique because the
-- junction table uses a composite primary key.
SELECT appointment_id, service_id, COUNT(*) AS row_count
FROM appointment_service
GROUP BY appointment_id, service_id
HAVING COUNT(*) > 1;

-- ============================================================
-- SECTION 7 - PRACTICE
-- ============================================================
-- 1. State the grain of every table.
-- 2. Identify every primary key and foreign key.
-- 3. Explain why appointment_service needs a composite key.
-- 4. Design a room table with:
--      room_id integer PRIMARY KEY
--      room_name text NOT NULL
--      capacity integer CHECK (capacity > 0)
-- 5. Add a relationship from appointments to rooms.
--
-- MODULE 2 CHECKLIST
-- [ ] Every table has a clear row grain.
-- [ ] Keys identify rows and relationships.
-- [ ] Constraints protect important rules.
-- [ ] Repeating groups are separated into related tables.
-- [ ] Many-to-many relationships use junction tables.
-- ============================================================
