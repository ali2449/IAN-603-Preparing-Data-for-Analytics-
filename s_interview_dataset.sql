-- IAN 603 Interview Practice Studio
-- Synthetic teaching data. PostgreSQL-compatible; no real patient/customer records.
CREATE TABLE departments (
  department_id integer PRIMARY KEY,
  department_name text NOT NULL,
  location text
);
CREATE TABLE patients (
  patient_id integer PRIMARY KEY,
  full_name text NOT NULL,
  age integer,
  city text,
  email text,
  registered_on date
);
CREATE TABLE admissions (
  admission_id integer PRIMARY KEY,
  patient_id integer NOT NULL REFERENCES patients(patient_id),
  admitted_on date NOT NULL,
  discharged_on date,
  diagnosis text,
  department_id integer REFERENCES departments(department_id),
  cost numeric(10,2)
);
CREATE TABLE labs (
  lab_id integer PRIMARY KEY,
  patient_id integer NOT NULL REFERENCES patients(patient_id),
  collected_on date NOT NULL,
  test_name text NOT NULL,
  result_value numeric(8,2),
  unit text
);
CREATE TABLE prescriptions (
  rx_id integer PRIMARY KEY,
  patient_id integer NOT NULL REFERENCES patients(patient_id),
  drug_name text NOT NULL,
  quantity integer,
  prescribed_on date NOT NULL
);
CREATE TABLE customers (
  customer_id integer PRIMARY KEY,
  customer_name text NOT NULL,
  email text,
  region text,
  joined_on date
);
CREATE TABLE products (
  product_id integer PRIMARY KEY,
  product_name text NOT NULL,
  category text NOT NULL,
  list_price numeric(10,2),
  stock_qty integer NOT NULL DEFAULT 0
);
CREATE TABLE orders (
  order_id integer PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES customers(customer_id),
  ordered_on date NOT NULL,
  status text NOT NULL,
  total numeric(10,2)
);
CREATE TABLE order_items (
  item_id integer PRIMARY KEY,
  order_id integer NOT NULL REFERENCES orders(order_id),
  product_id integer NOT NULL REFERENCES products(product_id),
  quantity integer NOT NULL,
  unit_price numeric(10,2) NOT NULL
);
CREATE TABLE payments (
  payment_id integer PRIMARY KEY,
  order_id integer NOT NULL REFERENCES orders(order_id),
  paid_on date NOT NULL,
  amount numeric(10,2) NOT NULL,
  method text
);
CREATE TABLE employees (
  employee_id integer PRIMARY KEY,
  employee_name text NOT NULL,
  department_id integer REFERENCES departments(department_id),
  salary numeric(10,2) NOT NULL,
  hired_on date NOT NULL,
  manager_id integer REFERENCES employees(employee_id)
);
CREATE TABLE events (
  event_id integer PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES customers(customer_id),
  event_type text NOT NULL,
  occurred_at timestamp NOT NULL,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE raw_contacts (
  contact_id integer PRIMARY KEY,
  raw_name text,
  raw_email text,
  raw_phone text,
  raw_city text,
  updated_on date
);
CREATE TABLE monthly_metrics (
  metric_id integer PRIMARY KEY,
  product_id integer NOT NULL REFERENCES products(product_id),
  month_start date NOT NULL,
  revenue numeric(10,2),
  units integer
);
CREATE TABLE survey_responses (
  response_id integer PRIMARY KEY,
  patient_id integer NOT NULL REFERENCES patients(patient_id),
  question text NOT NULL,
  score integer
);
CREATE TABLE claims (
  claim_id integer PRIMARY KEY,
  patient_id integer NOT NULL REFERENCES patients(patient_id),
  submitted_on date,
  amount numeric(10,2),
  status text
);
INSERT INTO departments VALUES
 (1,'Cardiology','North'),(2,'Emergency','Central'),(3,'Oncology','South'),(4,'Primary Care','North'),(5,'Research','West');
INSERT INTO patients VALUES
 (1,'Ava Johnson',34,'Greensboro','ava@example.test','2025-01-12'),
 (2,'Noah Kim',67,'Raleigh','noah@example.test','2024-11-04'),
 (3,'Mia Patel',28,'Greensboro',NULL,'2025-03-05'),
 (4,'Liam Davis',45,'Durham','liam@example.test','2024-05-16'),
 (5,'Sofia Garcia',53,'Raleigh','sofia@example.test','2025-01-20'),
 (6,'Ethan Brown',19,'Greensboro','ethan@example.test','2025-06-02'),
 (7,'Olivia Wilson',72,'Charlotte',NULL,'2023-09-14'),
 (8,'James Lee',38,'Durham','james@example.test','2025-04-21'),
 (9,'Emma Clark',61,'Greensboro','emma@example.test','2024-08-30'),
 (10,'Lucas Hall',42,'Asheville','lucas@example.test','2025-02-10'),
 (11,'Grace Chen',31,NULL,'grace@example.test','2025-07-01'),
 (12,'Henry Scott',56,'Greensboro','henry@example.test','2024-02-13');
INSERT INTO admissions VALUES
 (101,1,'2025-01-14','2025-01-16','Pneumonia',2,1800),
 (102,1,'2025-04-10','2025-04-11','Fracture',2,900),
 (103,2,'2025-02-01','2025-02-07','Pneumonia',1,5200),
 (104,2,'2025-07-03',NULL,'Hypertension',1,2400),
 (105,3,'2025-03-06','2025-03-07','Fracture',2,1100),
 (106,4,'2025-01-09','2025-01-12','Pneumonia',2,2400),
 (107,5,'2025-04-03','2025-04-06','Diabetes',4,1600),
 (108,5,'2025-05-08','2025-05-12','Pneumonia',2,3600),
 (109,5,'2025-07-01',NULL,'Diabetes',4,2100),
 (110,7,'2025-02-10','2025-02-11','Fracture',2,1500),
 (111,7,'2025-03-20','2025-03-25','Pneumonia',1,6100),
 (112,8,'2025-03-03','2025-03-04','Asthma',4,800),
 (113,8,'2025-03-10','2025-03-12','Asthma',4,1100),
 (114,9,'2025-08-02',NULL,'Hypertension',1,2700),
 (115,10,'2025-04-16','2025-04-17','Fracture',2,1750),
 (116,12,'2025-06-01','2025-06-06','Pneumonia',2,4200),
 (117,12,'2025-08-09',NULL,NULL,3,NULL),
 (118,2,'2025-08-10',NULL,'Pneumonia',2,5300);
INSERT INTO labs VALUES
 (1,1,'2025-01-14','Glucose',95,'mg/dL'),(2,2,'2025-02-02','Glucose',148,'mg/dL'),
 (3,2,'2025-02-02','LDL',155,'mg/dL'),(4,3,'2025-03-06','Glucose',89,'mg/dL'),
 (5,4,'2025-01-09','LDL',121,'mg/dL'),(6,5,'2025-04-03','Glucose',185,'mg/dL'),
 (7,5,'2025-05-08','Glucose',173,'mg/dL'),(8,7,'2025-02-10','LDL',170,'mg/dL'),
 (9,8,'2025-03-03','Glucose',NULL,'mg/dL'),(10,9,'2025-08-02','Glucose',132,'mg/dL'),
 (11,12,'2025-06-02','LDL',110,'mg/dL'),(12,12,'2025-06-03','Glucose',105,'mg/dL'),
 (13,1,'2025-04-10','LDL',111,'mg/dL'),(14,10,'2025-04-16','Glucose',101,'mg/dL');
INSERT INTO prescriptions VALUES
 (1,1,'Amoxicillin',14,'2025-01-14'),(2,2,'Metformin',30,'2025-02-01'),
 (3,2,'Lisinopril',30,'2025-07-03'),(4,4,'Amoxicillin',10,'2025-01-10'),
 (5,5,'Metformin',60,'2025-04-03'),(6,5,'Metformin',30,'2025-05-08'),
 (7,7,'Lisinopril',30,'2025-03-20'),(8,8,'Albuterol',1,'2025-03-03'),
 (9,9,'Lisinopril',30,'2025-08-02'),(10,12,'Amoxicillin',10,'2025-06-02');
INSERT INTO customers VALUES
 (1,'Alice Adams','alice@example.test','East','2024-12-01'),
 (2,'Bob Baker','bob@example.test','West','2025-01-14'),
 (3,'Cara Cruz','cara@example.test','East','2025-02-03'),
 (4,'Daniel Diaz','daniel@example.test','South','2025-02-15'),
 (5,'Elena Evans','elena@example.test','North','2025-03-10'),
 (6,'Farah Fox','farah@example.test','West','2025-04-12'),
 (7,'George Green',NULL,'East','2025-05-01'),
 (8,'Hana Hill','hana@example.test','South','2025-05-05'),
 (9,'Ivan Iqbal','ivan@example.test',NULL,'2025-06-01'),
 (10,'Julia Jones','julia@example.test','North','2025-06-22'),
 (11,'Kai King','kai@example.test','West','2025-07-04'),
 (12,'Leah Lane','leah@example.test','South','2025-07-19');
INSERT INTO products VALUES
 (1,'Laptop','Electronics',899.00,8),(2,'Mouse','Electronics',29.00,60),
 (3,'Keyboard','Electronics',69.00,25),(4,'Desk','Furniture',249.00,10),
 (5,'Chair','Furniture',189.00,14),(6,'Notebook','Office',5.00,100),
 (7,'Pen Set','Office',12.00,45),(8,'Monitor','Electronics',229.00,7),
 (9,'Lamp','Furniture',42.00,0),(10,'Webcam','Electronics',79.00,18);
INSERT INTO orders VALUES
 (1001,1,'2025-01-03','completed',928.00),(1002,1,'2025-02-14','completed',69.00),
 (1003,2,'2025-01-11','completed',249.00),(1004,2,'2025-05-08','refunded',189.00),
 (1005,3,'2025-02-18','completed',29.00),(1006,4,'2025-03-09','pending',229.00),
 (1007,5,'2025-03-20','completed',120.00),(1008,5,'2025-04-22','completed',899.00),
 (1009,5,'2025-06-11','completed',249.00),(1010,6,'2025-06-20','cancelled',79.00),
 (1011,7,'2025-07-02','completed',69.00),(1012,8,'2025-07-10','completed',189.00),
 (1013,8,'2025-08-12','completed',189.00),(1014,9,'2025-07-22','pending',42.00),
 (1015,10,'2025-08-01','completed',928.00),(1016,3,'2025-08-04','completed',249.00),
 (1017,2,'2025-08-04','completed',249.00),(1018,11,'2025-08-22','pending',12.00);
INSERT INTO order_items VALUES
 (1,1001,1,1,899),(2,1001,2,1,29),(3,1002,3,1,69),(4,1003,4,1,249),
 (5,1004,5,1,189),(6,1005,2,1,29),(7,1006,8,1,229),
 (8,1007,6,12,5),(9,1007,7,5,12),(10,1008,1,1,899),(11,1009,4,1,249),
 (12,1010,10,1,79),(13,1011,3,1,69),(14,1012,5,1,189),
 (15,1013,5,1,189),(16,1014,9,1,42),(17,1015,1,1,899),
 (18,1015,2,1,29),(19,1016,4,1,249),(20,1017,4,1,249),
 (21,1018,7,1,12);
INSERT INTO payments VALUES
 (1,1001,'2025-01-03',928,'card'),(2,1002,'2025-02-14',69,'card'),
 (3,1003,'2025-01-11',249,'cash'),(4,1004,'2025-05-09',189,'card'),
 (5,1005,'2025-02-18',29,'card'),(6,1007,'2025-03-20',120,'cash'),
 (7,1008,'2025-04-22',899,'card'),(8,1009,'2025-06-11',249,'card'),
 (9,1011,'2025-07-02',69,'card'),(10,1012,'2025-07-10',189,'cash'),
 (11,1013,'2025-08-12',189,'card'),(12,1015,'2025-08-01',928,'card'),
 (13,1016,'2025-08-04',249,'card'),(14,1017,'2025-08-04',249,'cash');
INSERT INTO employees VALUES
 (1,'Morgan Reed',5,150000,'2018-01-15',NULL),
 (2,'Taylor Quinn',1,112000,'2019-05-01',1),
 (3,'Jordan Bell',2,108000,'2020-06-11',1),
 (4,'Casey Park',3,105000,'2021-03-25',1),
 (5,'Sam Rivera',1,95000,'2022-07-14',2),
 (6,'Riley Brooks',1,95000,'2023-01-02',2),
 (7,'Drew Ellis',2,84000,'2022-09-09',3),
 (8,'Alex Foster',2,78000,'2024-02-20',3),
 (9,'Jamie Moore',4,72000,'2025-01-05',1),
 (10,'Robin Young',4,72000,'2024-07-12',9),
 (11,'Parker Stone',3,88000,'2023-04-01',4),
 (12,'Avery West',NULL,65000,'2025-02-02',1);
INSERT INTO events VALUES
 (1,1,'page_view','2025-01-01 08:00','{"device":"mobile","campaign":"winter"}'),
 (2,1,'add_to_cart','2025-01-02 09:00','{"device":"mobile","campaign":"winter"}'),
 (3,1,'purchase','2025-01-03 10:00','{"device":"desktop"}'),
 (4,2,'page_view','2025-01-05 09:00','{"device":"desktop"}'),
 (5,2,'purchase','2025-01-11 10:00','{"device":"desktop","campaign":"spring"}'),
 (6,3,'page_view','2025-02-10 09:00','{"device":"mobile"}'),
 (7,3,'purchase','2025-02-18 13:00','{"device":"mobile"}'),
 (8,4,'page_view','2025-03-01 10:00','{"device":"tablet"}'),
 (9,5,'page_view','2025-03-15 10:00','{"device":"mobile"}'),
 (10,5,'purchase','2025-03-20 16:00','{"device":"mobile"}'),
 (11,5,'purchase','2025-04-22 11:00','{"device":"desktop"}'),
 (12,6,'page_view','2025-06-18 15:00','{"device":"mobile"}'),
 (13,7,'page_view','2025-07-01 11:00','{"device":"desktop"}'),
 (14,7,'purchase','2025-07-02 09:00','{"device":"desktop"}'),
 (15,8,'page_view','2025-07-09 17:00','{"device":"mobile"}'),
 (16,8,'purchase','2025-07-10 12:00','{"device":"mobile"}'),
 (17,9,'page_view','2025-07-21 08:00','{"device":"tablet"}'),
 (18,10,'purchase','2025-08-01 10:00','{"device":"mobile"}'),
 (19,11,'page_view','2025-08-20 10:00','{"device":"desktop"}');
INSERT INTO raw_contacts VALUES
 (1,'  Alice  Adams ','ALICE@EXAMPLE.TEST','(336) 555-0101','Greensboro','2025-01-10'),
 (2,'Alice Adams','alice@example.test','3365550101','greensboro','2025-01-11'),
 (3,'BOB BAKER','BOB@EXAMPLE.TEST','336 555 0202','Raleigh','2025-01-12'),
 (4,'Cara Cruz',' ','',' Durham ','2025-01-13'),
 (5,' Daniel Diaz ',NULL,'555-0303','DURHAM','2025-01-14'),
 (6,'Elena Evans','elena@example.test',NULL,'Winston-Salem','2025-02-01'),
 (7,'George Green','george@example.test','not given','Greensboro','2025-02-02'),
 (8,'  Hanna Hill  ','hana@example.test','336-555-0404','Charlotte','2025-03-01'),
 (9,'Hana Hill','HANA@EXAMPLE.TEST','3365550404','CHARLOTTE','2025-03-02'),
 (10,'Ivan Iqbal','','3365550505','  ','2025-03-03'),
 (11,'Julia Jones','julia@EXAMPLE.test','336-555-0606','Raleigh','2025-04-01'),
 (12,'Leah Lane','leah@example.test','3365550707','Durham','2025-04-02');
INSERT INTO monthly_metrics VALUES
 (1,1,'2025-01-01',1800,2),(2,1,'2025-02-01',900,1),(3,1,'2025-03-01',2700,3),
 (4,2,'2025-01-01',290,10),(5,2,'2025-02-01',435,15),(6,2,'2025-03-01',580,20),
 (7,4,'2025-01-01',498,2),(8,4,'2025-02-01',747,3),(9,4,'2025-03-01',996,4),
 (10,5,'2025-01-01',189,1),(11,5,'2025-02-01',378,2),(12,5,'2025-03-01',567,3),
 (13,8,'2025-01-01',458,2),(14,8,'2025-03-01',687,3);
INSERT INTO survey_responses VALUES
 (1,1,'satisfaction',5),(2,2,'satisfaction',3),(3,3,'satisfaction',4),
 (4,5,'satisfaction',2),(5,7,'satisfaction',3),(6,8,'satisfaction',5),
 (7,9,'satisfaction',NULL),(8,12,'satisfaction',4),
 (9,1,'recommendation',5),(10,5,'recommendation',2);
INSERT INTO claims VALUES
 (1,1,'2025-01-20',1800,'paid'),(2,2,'2025-02-14',5200,'paid'),
 (3,2,'2025-07-08',2400,'pending'),(4,3,'2025-03-09',1100,'denied'),
 (5,5,'2025-04-20',1600,'paid'),(6,5,'2025-06-01',3600,'pending'),
 (7,7,'2025-02-18',1500,'paid'),(8,8,'2025-03-18',1100,'denied'),
 (9,9,'2025-08-05',2700,'pending'),(10,12,'2025-06-14',4200,'paid');
-- A normal view is available for read-only practice.
CREATE VIEW v_patient_admission_counts AS
SELECT p.patient_id, p.full_name, COUNT(a.admission_id) AS admission_count
FROM patients p LEFT JOIN admissions a ON p.patient_id = a.patient_id
GROUP BY p.patient_id, p.full_name;
