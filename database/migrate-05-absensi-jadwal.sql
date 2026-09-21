-- =====================================================================
-- Migrasi 05 — Absensi: jadwal kerja per karyawan (setting owner)
-- Idempoten. Perubahan:
--   employees: shift_start TIME  = jam masuk terjadwal (penentu terlambat)
--              work_hours DECIMAL = durasi kerja (jam) → dasar auto clock-out:
--              clock_out otomatis = clock_in + work_hours.
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-05-absensi-jadwal.sql
-- =====================================================================

SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE employees
     ADD COLUMN shift_start TIME NULL DEFAULT NULL AFTER phone,
     ADD COLUMN work_hours DECIMAL(4,2) NOT NULL DEFAULT 8.00 AFTER shift_start',
  'SELECT "employees: kolom shift_start/work_hours sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'employees' AND column_name = 'shift_start');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Jadwal default untuk karyawan lama: masuk 10:00, kerja 8 jam (mengikuti
-- aturan lama "clock-in >= 10:00 terlambat"). Owner bisa ubah per karyawan
-- dari halaman Absensi.
UPDATE employees SET shift_start = COALESCE(shift_start, '10:00:00') WHERE is_active = 1;
