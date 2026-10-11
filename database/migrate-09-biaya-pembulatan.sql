-- =====================================================================
-- Migrasi 09 — Biaya layanan (service charge) & pembulatan total
-- Idempoten. Perubahan:
--   1. orders.rounding_amount : selisih pembulatan ke atas (0 bila tidak dibulatkan)
--   2. settings: rounding_step ('0' = mati, '1000' = bulatkan ke atas per Rp1.000)
--      Persen biaya layanan = settings.service_rate (mis. 0.05 = 5%), pajak = tax_rate;
--      keduanya diatur dari halaman Pembayaran > Biaya & Pembulatan.
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-09-biaya-pembulatan.sql
-- =====================================================================

SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE orders ADD COLUMN rounding_amount DECIMAL(14, 2) NOT NULL DEFAULT 0 AFTER discount',
  'SELECT "orders: kolom rounding_amount sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'rounding_amount');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT INTO settings (`key`, `value`) VALUES ('rounding_step', '0')
ON DUPLICATE KEY UPDATE `key` = `key`;
