-- =====================================================================
-- Migrasi 02 — Manajemen Menu & Stok
-- Idempoten. Perubahan:
--   1. stock_items: kolom category (Protein/Bumbu/Pokok/Pelengkap/...)
--   2. products: mapping bahan baku (stock_item_id + stock_qty_per_unit)
--   3. Seed 14 bahan baku dari halaman Stock
--   4. Contoh mapping produk -> bahan (opsional, bisa diubah dari UI Menu)
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-02-stock.sql
-- =====================================================================

-- 1) stock_items.category
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE stock_items ADD COLUMN category VARCHAR(50) NOT NULL DEFAULT ''Lain-lain'' AFTER name',
  'SELECT "stock_items: kolom category sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'stock_items' AND column_name = 'category');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) products: kolom mapping bahan
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE products
     ADD COLUMN stock_item_id INT UNSIGNED DEFAULT NULL AFTER is_available,
     ADD COLUMN stock_qty_per_unit DECIMAL(12,3) NOT NULL DEFAULT 1 AFTER stock_item_id,
     ADD CONSTRAINT fk_products_stock FOREIGN KEY (stock_item_id) REFERENCES stock_items (id)',
  'SELECT "products: kolom stock_item_id sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'stock_item_id');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3) Seed bahan baku (dari initialStock halaman Stock.jsx)
INSERT INTO stock_items (name, category, unit, qty, min_qty)
SELECT v.name, v.category, v.unit, v.qty, v.min_qty
FROM (
  SELECT 'Daging Ayam'        AS name, 'Protein'    AS category, 'kg'    AS unit,  8  AS qty, 15 AS min_qty UNION ALL
  SELECT 'Daging Sapi',                   'Protein',    'kg',    22, 10 UNION ALL
  SELECT 'Cabai Rawit',                    'Bumbu',      'kg',    3,  8  UNION ALL
  SELECT 'Cabai Merah Besar',              'Bumbu',      'kg',    5,  6  UNION ALL
  SELECT 'Bawang Merah',                   'Bumbu',      'kg',    14, 8  UNION ALL
  SELECT 'Bawang Putih',                   'Bumbu',      'kg',    11, 6  UNION ALL
  SELECT 'Beras',                          'Pokok',      'kg',    60, 30 UNION ALL
  SELECT 'Mie Basah',                      'Pokok',      'kg',    4,  10 UNION ALL
  SELECT 'Minyak Goreng',                  'Pelengkap',  'liter', 18, 10 UNION ALL
  SELECT 'Telur Ayam',                     'Protein',    'kg',    25, 10 UNION ALL
  SELECT 'Kerupuk Mentah',                 'Pelengkap',  'kg',    6,  5  UNION ALL
  SELECT 'Gula Pasir',                     'Bumbu',      'kg',    9,  5  UNION ALL
  SELECT 'Kecap Manis',                    'Pelengkap',  'liter', 12, 6  UNION ALL
  SELECT 'Jeruk Nipis',                    'Bumbu',      'kg',    2,  4
) v
WHERE NOT EXISTS (SELECT 1 FROM stock_items s WHERE s.name = v.name);

-- 4) Contoh mapping produk -> bahan (1 unit produk memakai stock_qty_per_unit bahan)
UPDATE products p JOIN stock_items s ON s.name = 'Kerupuk Mentah'
SET p.stock_item_id = s.id, p.stock_qty_per_unit = 0.05
WHERE p.name = 'Kerupuk' AND p.stock_item_id IS NULL;
UPDATE products p JOIN stock_items s ON s.name = 'Telur Ayam'
SET p.stock_item_id = s.id, p.stock_qty_per_unit = 0.06
WHERE p.name = 'Telur Ceplok' AND p.stock_item_id IS NULL;
UPDATE products p JOIN stock_items s ON s.name = 'Beras'
SET p.stock_item_id = s.id, p.stock_qty_per_unit = 0.15
WHERE p.name = 'Tambah Nasi' AND p.stock_item_id IS NULL;
