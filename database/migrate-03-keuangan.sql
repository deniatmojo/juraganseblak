-- =====================================================================
-- Migrasi 03 — Keuangan & Shift Kasir
-- Idempoten. Perubahan:
--   1. Tabel shifts (open/close cash drawer per kasir)
--   2. orders: shift_id (relasi shift) + kolom void (reason/at/by)
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-03-keuangan.sql
-- =====================================================================

CREATE TABLE IF NOT EXISTS shifts (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      INT UNSIGNED NOT NULL,
  opening_cash DECIMAL(14, 2) NOT NULL DEFAULT 0,
  closing_cash DECIMAL(14, 2) DEFAULT NULL,
  expected_cash DECIMAL(14, 2) DEFAULT NULL,   -- kas awal + penjualan tunai shift ini
  opened_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  closed_at    TIMESTAMP NULL DEFAULT NULL,
  note         VARCHAR(255) DEFAULT NULL,
  CONSTRAINT fk_shifts_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB;

-- orders.shift_id
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE orders
     ADD COLUMN shift_id BIGINT UNSIGNED DEFAULT NULL AFTER cashier_id,
     ADD CONSTRAINT fk_orders_shift FOREIGN KEY (shift_id) REFERENCES shifts (id)',
  'SELECT "orders: kolom shift_id sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'shift_id');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- orders: kolom void
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE orders
     ADD COLUMN void_reason VARCHAR(255) DEFAULT NULL AFTER shift_id,
     ADD COLUMN voided_at   TIMESTAMP NULL DEFAULT NULL AFTER void_reason,
     ADD COLUMN voided_by   INT UNSIGNED DEFAULT NULL AFTER voided_at',
  'SELECT "orders: kolom void sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'void_reason');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
