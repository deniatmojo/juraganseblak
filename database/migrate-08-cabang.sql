-- =====================================================================
-- Migrasi 08 — Sistem multi-cabang (stok, kasir, keuangan, meja QR)
-- Idempoten. Perubahan:
--   1. branches: pastikan minimal ada satu cabang ('Cabang 1' bila kosong)
--   2. stock_branch_items : qty & min_qty bahan PER CABANG (katalog bahan
--      tetap satu di stock_items; kolom stock_items.qty lama TIDAK dipakai lagi)
--   3. branch_id di: stock_movements, orders, shifts, transactions,
--      dining_tables, users (users.branch_id = penguncian cabang admin)
--   4. stock_movements.type + 'transfer_in' / 'transfer_out' (transfer antar cabang)
--   5. Backfill: semua data & stok lama → cabang utama (id terkecil)
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-08-cabang.sql
-- =====================================================================

-- 1. Cabang utama
INSERT INTO branches (name, address, lat, lng, radius_m)
SELECT 'Cabang 1', NULL, 0, 0, 100 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM branches);

SET @main := (SELECT MIN(id) FROM branches);

-- 2. Stok per cabang
CREATE TABLE IF NOT EXISTS stock_branch_items (
  item_id   INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  qty       DECIMAL(12, 3) NOT NULL DEFAULT 0,
  min_qty   DECIMAL(12, 3) NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id, branch_id),
  CONSTRAINT fk_sbi_item   FOREIGN KEY (item_id)   REFERENCES stock_items (id) ON DELETE CASCADE,
  CONSTRAINT fk_sbi_branch FOREIGN KEY (branch_id) REFERENCES branches (id)
) ENGINE=InnoDB;

-- Backfill hanya untuk bahan yang belum punya baris di cabang utama
-- (aman diulang: tidak menimpa qty yang sudah berjalan).
INSERT INTO stock_branch_items (item_id, branch_id, qty, min_qty)
SELECT s.id, @main, s.qty, s.min_qty FROM stock_items s
WHERE NOT EXISTS (SELECT 1 FROM stock_branch_items b WHERE b.item_id = s.id AND b.branch_id = @main);

-- 3. branch_id di tabel-tabel transaksional ----------------------------
DROP PROCEDURE IF EXISTS add_branch_col;
DELIMITER //
CREATE PROCEDURE add_branch_col(IN tbl VARCHAR(64))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE table_schema = DATABASE() AND table_name = tbl AND column_name = 'branch_id') THEN
    SET @ddl = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN branch_id INT UNSIGNED NULL DEFAULT NULL, ',
                      'ADD INDEX idx_', tbl, '_branch (branch_id), ',
                      'ADD CONSTRAINT fk_', tbl, '_branch FOREIGN KEY (branch_id) REFERENCES branches (id)');
    PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END//
DELIMITER ;

CALL add_branch_col('stock_movements');
CALL add_branch_col('orders');
CALL add_branch_col('shifts');
CALL add_branch_col('transactions');
CALL add_branch_col('dining_tables');
CALL add_branch_col('users');
DROP PROCEDURE add_branch_col;

-- 4. Tipe pergerakan transfer
ALTER TABLE stock_movements
  MODIFY type ENUM('in', 'out', 'adjust', 'transfer_in', 'transfer_out') NOT NULL;

-- 5. Backfill data lama ke cabang utama (users: hanya admin/kasir tidak perlu;
--    users.branch_id sengaja dibiarkan NULL — diatur owner per admin)
UPDATE stock_movements SET branch_id = @main WHERE branch_id IS NULL;
UPDATE orders          SET branch_id = @main WHERE branch_id IS NULL;
UPDATE shifts          SET branch_id = @main WHERE branch_id IS NULL;
UPDATE transactions    SET branch_id = @main WHERE branch_id IS NULL;
UPDATE dining_tables   SET branch_id = @main WHERE branch_id IS NULL;
