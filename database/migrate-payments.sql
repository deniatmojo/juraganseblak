-- Migrasi: kolom pembayaran gateway di tabel orders (fitur QRIS / payment gateway).
-- Aman dijalankan berulang (MySQL 8: IF NOT EXISTS didukung di 8.0.29+;
-- bila versi lebih lama, abaikan error 1060 Duplicate column).
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS payment_provider   VARCHAR(30)  DEFAULT NULL COMMENT 'tripay | duitku | midtrans | manual',
  ADD COLUMN IF NOT EXISTS payment_ref        VARCHAR(100) DEFAULT NULL COMMENT 'reference/id transaksi dari gateway',
  ADD COLUMN IF NOT EXISTS payment_url        VARCHAR(500) DEFAULT NULL COMMENT 'halaman checkout gateway',
  ADD COLUMN IF NOT EXISTS payment_qr         TEXT         DEFAULT NULL COMMENT 'qr_string QRIS dinamis dari gateway',
  ADD COLUMN IF NOT EXISTS paid_at            TIMESTAMP    NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS payment_confirmed_by INT UNSIGNED DEFAULT NULL COMMENT 'user id bila dilunasi manual, bukan webhook';
