-- =====================================================================
-- Migrasi 11 — Topping seblak: 3 kategori (Top Frozen, Bakso, Top Kering)
--   * kategori baru: topping-frozen, topping-bakso, topping-kering
--     (kunci diawali "topping" => dikenali sebagai topping oleh server/POS/Order)
--   * daftar topping sesuai list toko (harga per item)
--   * topping lama (kategori 'topping') DINONAKTIFKAN, tidak dihapus —
--     riwayat order_items tetap terhubung. Aktifkan lagi dari halaman Menu bila perlu.
--   * HPP diisi 0 (belum diketahui) & belum terhubung ke stok — lengkapi di halaman Menu.
-- Idempoten: dijalankan ulang akan menyamakan kategori & harga dengan list ini.
-- Jalankan manual:  mysql -u<user> -p <database> < database/migrate-11-topping-kategori.sql
-- =====================================================================

INSERT INTO categories (`key`, label, sort_order)
SELECT v.k, v.l, v.s FROM (
  SELECT 'topping-frozen' AS k, 'Top Frozen' AS l, 2 AS s UNION ALL
  SELECT 'topping-bakso',        'Bakso',           3 UNION ALL
  SELECT 'topping-kering',       'Top Kering',      4
) v
WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.`key` = v.k);

DROP TEMPORARY TABLE IF EXISTS tmp_topping;
CREATE TEMPORARY TABLE tmp_topping (
  name VARCHAR(100) NOT NULL,
  ck   VARCHAR(50)  NOT NULL,
  price DECIMAL(12,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_topping (name, ck, price) VALUES
-- TOP FROZEN
('Sosis Oren',          'topping-frozen', 5000),
('Sosis Merah',         'topping-frozen', 5000),
('Tofu Besar',          'topping-frozen', 2500),
('Dumpling Ikan',       'topping-frozen', 2500),
('Dumpling Keju',       'topping-frozen', 2500),
('Dumpling Ayam',       'topping-frozen', 2500),
('Ekor Udang',          'topping-frozen', 2500),
('Fishroll',            'topping-frozen', 2500),
('Otak-otak Singapore', 'topping-frozen', 2500),
('Kembang Cumi',        'topping-frozen', 2500),
('Chikuwa',             'topping-frozen', 2500),
('Odeng',               'topping-frozen', 2000),
('Scalop',              'topping-frozen', 2000),
('Twist Merah',         'topping-frozen', 2000),
('Twist Putih',         'topping-frozen', 2000),
('Sosis Kecil',         'topping-frozen', 2000),
('Tempura Beger',       'topping-frozen', 2000),
('Twist Hijau',         'topping-frozen', 2000),
('Tofu Sedang',         'topping-frozen', 2000),
('Capit Kepiting',      'topping-frozen', 2000),
('Naruto',              'topping-frozen', 2000),
('Tempura Lonjong',     'topping-frozen', 1000),
('Tofu Kecil',          'topping-frozen', 1000),
('Fishball',            'topping-frozen', 1000),
-- BAKSO
('Bakso Beranak',             'topping-bakso', 20000),
('Bakso Keju',          'topping-bakso',  5000),
('Bakso Tetelan',             'topping-bakso',  5000),
('Bakso Puyuh',               'topping-bakso',  5000),
('Tahu Ori',            'topping-bakso',  3000),
('Tahu Spicy',          'topping-bakso',  3000),
('Somay Bakso',         'topping-bakso',  3000),
('A. Ori',              'topping-bakso',  2000),
('A. Spicy',            'topping-bakso',  2000),
('S. Kubis',            'topping-bakso',  1000),
-- TOP KERING
('K. Udang',            'topping-kering', 3000),
('K. Mawar',            'topping-kering', 3000),
('K. Sanjung',          'topping-kering', 3000),
('Bihun Putih',         'topping-kering', 2500),
('Pilus',               'topping-kering', 2000),
('C. Tahu',             'topping-kering', 1500),
('Otak-otak',           'topping-kering', 1500),
('C. Lidah',            'topping-kering', 1000),
('Tahu Bulat',          'topping-kering', 1000),
('Smy Kering',          'topping-kering', 1000),
('Mie Kuning',          'topping-kering', 1000);

-- Topping lama (kategori 'topping') -> nonaktif
UPDATE products p
JOIN categories c ON c.id = p.category_id AND c.`key` = 'topping'
SET p.is_active = 0
WHERE p.name NOT IN (SELECT name FROM tmp_topping);

-- Produk yang sudah ada dengan nama sama: samakan kategori, harga, aktif
UPDATE products p
JOIN categories cur ON cur.id = p.category_id AND cur.`key` IN ('topping', 'topping-frozen', 'topping-bakso', 'topping-kering')
JOIN tmp_topping t ON t.name = p.name
JOIN categories c ON c.`key` = t.ck
SET p.category_id = c.id, p.price = t.price, p.is_active = 1, p.is_available = 1;

-- Produk baru
INSERT INTO products (name, category_id, price, hpp)
SELECT t.name, c.id, t.price, 0
FROM tmp_topping t
JOIN categories c ON c.`key` = t.ck
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.name = t.name AND p.category_id = c.id);

DROP TEMPORARY TABLE tmp_topping;

SELECT c.label AS kategori, COUNT(*) AS jumlah
FROM products p JOIN categories c ON c.id = p.category_id
WHERE c.`key` LIKE 'topping-%' AND p.is_active = 1
GROUP BY c.label;
