-- =====================================================================
-- Migrasi 07 — Seblak Prasmanan (porsi custom per jenis kuah)
-- Idempoten. Perubahan:
--   1. order_items: kolom porsi_no + item_role (kuah | topping)
--   2. Kategori baru: 'kuah' (Jenis Kuah) & 'topping' (Topping Seblak)
--   3. Bahan baku baru untuk topping (Sosis, Sayur Kol, Jamur, Bakso, ...)
--   4. Menu seblak prasmanan:
--      - 3 jenis kuah (Seblak Nyemek / Sedang / Full Kuah), masing-masing
--        terhubung MULTI bahan baku via product_stock_items (HPP kuah) —
--        porsi Full Kuah memakai bumbu lebih banyak dari Nyemek
--      - 10 topping seblak, masing-masing terhubung ke bahan stoknya
--   5. Produk template lama (Paket AYCE 'paket' & 'ekstra') dinonaktifkan
--      (is_active=0, TIDAK dihapus — aktifkan kembali bila perlu).
--   6. Minuman tetap aktif (dipesan sebagai item biasa, bukan porsi).
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-07-prasmanan.sql
-- =====================================================================

-- 1) order_items: porsi_no + item_role -----------------------------------
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE order_items ADD COLUMN porsi_no INT UNSIGNED DEFAULT NULL AFTER note, ADD COLUMN item_role ENUM(''kuah'',''topping'') DEFAULT NULL AFTER porsi_no',
  'SELECT "order_items: kolom porsi_no sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'order_items' AND column_name = 'porsi_no');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) Kategori kuah & topping ---------------------------------------------
INSERT INTO categories (`key`, label, sort_order)
SELECT 'kuah', 'Jenis Kuah', 1
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE `key` = 'kuah');
INSERT INTO categories (`key`, label, sort_order)
SELECT 'topping', 'Topping Seblak', 2
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE `key` = 'topping');
-- Urutan tampil: Jenis Kuah, Topping, lalu Minuman
UPDATE categories SET sort_order = 3 WHERE `key` = 'minuman' AND sort_order < 3;

-- 3) Bahan baku baru ------------------------------------------------------
INSERT INTO stock_items (name, category, unit, qty, min_qty)
SELECT v.name, v.category, v.unit, v.qty, v.min_qty
FROM (
  SELECT 'Sosis Ayam'    AS name, 'Protein'   AS category, 'pcs'  AS unit, 60 AS qty, 20 AS min_qty UNION ALL
  SELECT 'Sayur Kol',             'Sayuran',   'kg',          10,        4 UNION ALL
  SELECT 'Jamur Merang',          'Sayuran',   'kg',           8,        3 UNION ALL
  SELECT 'Bakso Kasar',           'Protein',   'pcs',         60,       20 UNION ALL
  SELECT 'Bakso Halus',           'Protein',   'pcs',         60,       20 UNION ALL
  SELECT 'Makaroni',              'Pokok',     'kg',          10,        4 UNION ALL
  SELECT 'Ceker Ayam',            'Protein',   'pcs',         40,       15
) v
WHERE NOT EXISTS (SELECT 1 FROM stock_items s WHERE s.name = v.name);

-- 4) Produk jenis kuah (harga = dasar porsi sebelum topping) --------------
INSERT INTO products (name, category_id, price, hpp, image_url)
SELECT v.name, c.id, v.price, v.hpp, v.image_url
FROM (
  SELECT 'Seblak Nyemek'     AS name, 'kuah' AS ck, 8000  AS price, 3500 AS hpp, '/images/kuah-nyemek.jpg'    AS image_url UNION ALL
  SELECT 'Seblak Sedang',             'kuah',       10000,       4500,      '/images/kuah-sedang.jpg'           UNION ALL
  SELECT 'Seblak Full Kuah',          'kuah',       12000,       5500,      '/images/kuah-full.jpg'
) v
JOIN categories c ON c.`key` = v.ck
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.name = v.name);

-- 4b) Konversi produk "Kerupuk" template lama (kategori 'ekstra', bila ada)
--     menjadi topping seblak — nama sama dipertahankan agar riwayat
--     order_items lama tetap terhubung; hanya kategori/harga/aktif yang
--     diubah. Skip bila sudah jadi topping.
UPDATE products p
JOIN categories cold ON cold.id = p.category_id AND cold.`key` = 'ekstra'
JOIN categories cnew ON cnew.`key` = 'topping'
SET p.category_id = cnew.id, p.price = 2000, p.hpp = 800,
    p.image_url = '/images/top-kerupuk.jpg', p.is_active = 1, p.is_available = 1
WHERE p.name = 'Kerupuk' AND cold.`key` = 'ekstra';

-- 5) Produk topping --------------------------------------------------------
INSERT INTO products (name, category_id, price, hpp, image_url)
SELECT v.name, c.id, v.price, v.hpp, v.image_url
FROM (
  SELECT 'Kerupuk'     AS name, 'topping' AS ck, 2000 AS price,  800 AS hpp, '/images/top-kerupuk.jpg'  AS image_url UNION ALL
  SELECT 'Sosis Ayam',          'topping',       3000,       1500,      '/images/top-sosis.jpg'             UNION ALL
  SELECT 'Sayur Kol',           'topping',       1000,        400,      '/images/top-kol.jpg'               UNION ALL
  SELECT 'Jamur',               'topping',       2000,        800,      '/images/top-jamur.jpg'             UNION ALL
  SELECT 'Telur Rebus',         'topping',       3000,       1200,      '/images/top-telur.jpg'             UNION ALL
  SELECT 'Bakso Kasar',         'topping',       4000,       1800,      '/images/top-bakso-kasar.jpg'       UNION ALL
  SELECT 'Bakso Halus',         'topping',       4000,       1800,      '/images/top-bakso-halus.jpg'       UNION ALL
  SELECT 'Mie Basah',           'topping',       3000,       1000,      '/images/top-mie.jpg'               UNION ALL
  SELECT 'Makaroni',            'topping',       2000,        700,      '/images/top-makaroni.jpg'          UNION ALL
  SELECT 'Ceker Ayam',          'topping',       4000,       2000,      '/images/top-ceker.jpg'
) v
JOIN categories c ON c.`key` = v.ck
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.name = v.name);

-- 6) Link MULTI bahan per JENIS KUAH (pola products.stock_items — makin
--    penuh kuahnya makin banyak bumbu per porsi). Bahan lama yang belum ada
--    dijamin lewat WHERE NOT EXISTS di seed stock_items lama.
INSERT INTO product_stock_items (product_id, stock_item_id, qty_per_unit)
SELECT p.id, s.id, v.qty_per_unit
FROM (
  SELECT 'Seblak Nyemek'    AS pname, 'Cabai Rawit'      AS sname, 0.040 AS qty_per_unit UNION ALL
  SELECT 'Seblak Nyemek',             'Bawang Putih',            0.015 UNION ALL
  SELECT 'Seblak Nyemek',             'Bawang Merah',            0.015 UNION ALL
  SELECT 'Seblak Nyemek',             'Minyak Goreng',           0.020 UNION ALL
  SELECT 'Seblak Nyemek',             'Kecap Manis',             0.005 UNION ALL
  SELECT 'Seblak Sedang',             'Cabai Rawit',             0.060 UNION ALL
  SELECT 'Seblak Sedang',             'Bawang Putih',            0.020 UNION ALL
  SELECT 'Seblak Sedang',             'Bawang Merah',            0.020 UNION ALL
  SELECT 'Seblak Sedang',             'Minyak Goreng',           0.030 UNION ALL
  SELECT 'Seblak Sedang',             'Kecap Manis',             0.010 UNION ALL
  SELECT 'Seblak Full Kuah',          'Cabai Rawit',             0.080 UNION ALL
  SELECT 'Seblak Full Kuah',          'Bawang Putih',            0.030 UNION ALL
  SELECT 'Seblak Full Kuah',          'Bawang Merah',            0.030 UNION ALL
  SELECT 'Seblak Full Kuah',          'Minyak Goreng',           0.040 UNION ALL
  SELECT 'Seblak Full Kuah',          'Kecap Manis',             0.015
) v
JOIN products p ON p.name = v.pname
JOIN stock_items s ON s.name = v.sname
WHERE NOT EXISTS (
  SELECT 1 FROM product_stock_items psi
  WHERE psi.product_id = p.id AND psi.stock_item_id = s.id);

-- 7) Link bahan per TOPPING ------------------------------------------------
INSERT INTO product_stock_items (product_id, stock_item_id, qty_per_unit)
SELECT p.id, s.id, v.qty_per_unit
FROM (
  SELECT 'Kerupuk'     AS pname, 'Kerupuk Mentah' AS sname, 0.050 AS qty_per_unit UNION ALL
  SELECT 'Sosis Ayam',           'Sosis Ayam',             1.000 UNION ALL
  SELECT 'Sayur Kol',            'Sayur Kol',              0.100 UNION ALL
  SELECT 'Jamur',                'Jamur Merang',           0.100 UNION ALL
  SELECT 'Telur Rebus',          'Telur Ayam',             0.060 UNION ALL
  SELECT 'Bakso Kasar',          'Bakso Kasar',            1.000 UNION ALL
  SELECT 'Bakso Halus',          'Bakso Halus',            1.000 UNION ALL
  SELECT 'Mie Basah',            'Mie Basah',              0.250 UNION ALL
  SELECT 'Makaroni',             'Makaroni',               0.100 UNION ALL
  SELECT 'Ceker Ayam',           'Ceker Ayam',             1.000
) v
JOIN products p ON p.name = v.pname
JOIN stock_items s ON s.name = v.sname
WHERE NOT EXISTS (
  SELECT 1 FROM product_stock_items psi
  WHERE psi.product_id = p.id AND psi.stock_item_id = s.id);

-- 8) Nonaktifkan menu template lama (Paket AYCE & ekstra geprek) —
--    TIDAK dihapus; riwayat order lama tetap utuh. Aktifkan kembali dengan
--    UPDATE products SET is_active = 1 WHERE ... bila dibutuhkan.
UPDATE products p
JOIN categories c ON c.id = p.category_id
SET p.is_active = 0, p.is_available = 0
WHERE c.`key` IN ('paket', 'ekstra') AND p.is_active = 1;

-- 9) Sinkron kolom lama products.stock_item_id (bahan pertama) utk produk
--    baru, menjaga kompatibilitas aplikasi lama.
UPDATE products p
JOIN (
  SELECT psi.product_id, MIN(psi.id) AS first_link_id
  FROM product_stock_items psi
  JOIN products pp ON pp.id = psi.product_id
  JOIN categories c ON c.id = pp.category_id
  WHERE c.`key` IN ('kuah', 'topping')
  GROUP BY psi.product_id
) f ON f.product_id = p.id
JOIN product_stock_items psi2 ON psi2.id = f.first_link_id
SET p.stock_item_id = psi2.stock_item_id, p.stock_qty_per_unit = psi2.qty_per_unit
WHERE p.stock_item_id IS NULL;
