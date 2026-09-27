-- Migrasi: kolom pesanan online (fitur pemesanan online dari landing page).
-- MySQL tidak mendukung ADD COLUMN IF NOT EXISTS — bila dijalankan ulang akan
-- muncul error 1060 (Duplicate column), aman diabaikan.
ALTER TABLE orders
  ADD COLUMN customer_phone     VARCHAR(30)  DEFAULT NULL COMMENT 'HP/WA pemesan (pesanan online)',
  ADD COLUMN order_type         ENUM('dinein','delivery','pickup') NULL DEFAULT NULL COMMENT 'tipe pesanan online',
  ADD COLUMN schedule_at        DATETIME     NULL DEFAULT NULL COMMENT 'jadwal dine-in pre-order',
  ADD COLUMN delivery_address   TEXT         NULL COMMENT 'alamat pengiriman (order delivery)',
  ADD COLUMN customer_note      VARCHAR(255) DEFAULT NULL COMMENT 'catatan pemesan',
  ADD COLUMN progress           ENUM('queue','processing','ready','done') NULL DEFAULT NULL COMMENT 'tahap pesanan online setelah lunas: antrian > diproses > siap/diantar > selesai',
  ADD COLUMN progress_updated_at TIMESTAMP   NULL DEFAULT NULL,
  ADD COLUMN track_code         VARCHAR(16)  DEFAULT NULL COMMENT 'kode acak untuk lacak pesanan dari halaman publik';

ALTER TABLE orders ADD INDEX idx_orders_track_code (track_code);
