-- =====================================================================
-- Migrasi 06 — Absensi berbasis lokasi cabang (GPS radius)
-- Idempoten. Perubahan:
--   branches (tabel baru)  : titik lokasi cabang (lat/lng) + radius absen
--   employees.branch_id    : penugasan karyawan ke satu cabang
--   attendance.clock_lat/lng/distance_m : jejak GPS saat clock-in/out
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-06-absensi-cabang.sql
-- =====================================================================

CREATE TABLE IF NOT EXISTS branches (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  address    VARCHAR(255) DEFAULT NULL,
  lat        DECIMAL(10, 7) NOT NULL,           -- lintang (dari Google Maps)
  lng        DECIMAL(10, 7) NOT NULL,           -- bujur (dari Google Maps)
  radius_m   INT UNSIGNED NOT NULL DEFAULT 100, -- radius absen maksimum (meter)
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- employees.branch_id (kolom + FK)
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE employees
     ADD COLUMN branch_id INT UNSIGNED NULL DEFAULT NULL AFTER user_id,
     ADD CONSTRAINT fk_emp_branch FOREIGN KEY (branch_id) REFERENCES branches (id)',
  'SELECT "employees: kolom branch_id sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'employees' AND column_name = 'branch_id');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- attendance: jejak GPS saat absen
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE attendance
     ADD COLUMN clock_lat DECIMAL(10, 7) NULL DEFAULT NULL AFTER note,
     ADD COLUMN clock_lng DECIMAL(10, 7) NULL DEFAULT NULL AFTER clock_lat,
     ADD COLUMN clock_distance_m INT UNSIGNED NULL DEFAULT NULL AFTER clock_lng',
  'SELECT "attendance: kolom GPS sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'attendance' AND column_name = 'clock_lat');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
