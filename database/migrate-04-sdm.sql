-- =====================================================================
-- Migrasi 04 — SDM: karyawan server-side, absensi & payroll
-- Idempoten. Perubahan:
--   1. employees: daily_rate (tarif harian) + user_id (link akun login)
--   2. Tabel kasbon (pinjaman karyawan, dipotong dari gaji)
--   3. Seed beberapa karyawan demo + link akun kasir
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-04-sdm.sql
-- =====================================================================

SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE employees
     ADD COLUMN daily_rate DECIMAL(14,2) NOT NULL DEFAULT 0 AFTER role,
     ADD COLUMN user_id INT UNSIGNED DEFAULT NULL AFTER is_active,
     ADD CONSTRAINT fk_emp_user FOREIGN KEY (user_id) REFERENCES users (id)',
  'SELECT "employees: kolom daily_rate/user_id sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'employees' AND column_name = 'daily_rate');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS kasbon (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employee_id INT UNSIGNED NOT NULL,
  amount      DECIMAL(14, 2) NOT NULL,
  note        VARCHAR(255) DEFAULT NULL,
  is_settled  TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  settled_at  TIMESTAMP NULL DEFAULT NULL,
  CONSTRAINT fk_kasbon_emp FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Karyawan demo (dari halaman Absensi lama)
INSERT INTO employees (name, role, phone, daily_rate)
SELECT v.name, v.role, v.phone, v.rate
FROM (
  SELECT 'Melati Putri'   AS name, 'Kasir'    AS role, NULL AS phone, 70000 AS rate UNION ALL
  SELECT 'Dimas Ariyanto',           'Koki',     NULL,      80000 UNION ALL
  SELECT 'Ayu Lestari',              'Pelayan',  NULL,      60000
) v
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.name = v.name);

-- Link akun kasir demo -> karyawan (agar bisa clock in/out sendiri)
UPDATE employees e JOIN users u ON u.email = 'kasir@juraganseblak.id'
SET e.user_id = u.id
WHERE e.name = 'Kasir Demo' AND e.user_id IS NULL;
-- Akun kasir demo belum punya baris employees: buatkan
INSERT INTO employees (name, role, phone, daily_rate, user_id)
SELECT u.name, 'Kasir', NULL, 70000, u.id
FROM users u
WHERE u.email = 'kasir@juraganseblak.id'
  AND NOT EXISTS (SELECT 1 FROM employees e WHERE e.user_id = u.id);
