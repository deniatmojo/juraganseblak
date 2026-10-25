-- =====================================================================
-- Migrasi 12 — Hitungan cetak struk per pesanan (anti struk ganda)
--   orders.print_count : berapa kali struk pelanggan dicetak; cetakan ke-2 dst
--   diberi tanda besar "CETAKAN KE-N" di struk. Server juga menambahkan kolom
--   ini otomatis saat start (routes/orders.js); file ini hanya catatan/manual.
-- Idempoten.
-- =====================================================================
SET @ddl = IF(
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'print_count') = 0,
  'ALTER TABLE orders ADD COLUMN print_count INT UNSIGNED NOT NULL DEFAULT 0',
  'SELECT "orders.print_count sudah ada" AS info');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;
