-- =====================================================================
-- Migrasi 13 — Harga/HPP jenis kuah + Level Pedas (Lv 1-5)
--   Kuah (harga jual / HPP = gram bumbu x Rp51):
--     Nyemek     20 g : jual 1.500, HPP 1.020
--     Sedang     30 g : jual 2.000, HPP 1.530
--     Full Kuah  40 g : jual 2.500, HPP 2.040
--   Level pedas (ditagih per porsi; 70 rupiah/gram, Lv4-5 +1.000):
--     Lv1 15 g = 1.050 | Lv2 30 g = 2.100 | Lv3 45 g = 3.150
--     Lv4 60 g + 1.000 = 5.200 | Lv5 75 g + 1.000 = 6.250
--   Level = produk di kategori 'topping-level' (kunci diawali "topping" => dikenali
--   server sebagai topping; maksimal 1 level per porsi dijaga server). HPP level
--   diisi 0 (belum diketahui) — lengkapi di halaman Menu.
-- Idempoten: dijalankan ulang menyamakan harga dengan angka di atas.
-- Jalankan manual:  mysql -u<user> -p <database> < database/migrate-13-kuah-level-pedas.sql
-- =====================================================================

UPDATE products p
JOIN categories c ON c.id = p.category_id AND c.`key` = 'kuah'
SET p.price = CASE p.name WHEN 'Seblak Nyemek' THEN 1500 WHEN 'Seblak Sedang' THEN 2000 WHEN 'Seblak Full Kuah' THEN 2500 END,
    p.hpp   = CASE p.name WHEN 'Seblak Nyemek' THEN 1020 WHEN 'Seblak Sedang' THEN 1530 WHEN 'Seblak Full Kuah' THEN 2040 END
WHERE p.name IN ('Seblak Nyemek', 'Seblak Sedang', 'Seblak Full Kuah');

INSERT INTO categories (`key`, label, sort_order)
SELECT 'topping-level', 'Level Pedas', 5
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE `key` = 'topping-level');

DROP TEMPORARY TABLE IF EXISTS tmp_level;
CREATE TEMPORARY TABLE tmp_level (name VARCHAR(100) NOT NULL, price DECIMAL(12,2) NOT NULL) ENGINE=InnoDB;
INSERT INTO tmp_level (name, price) VALUES
('Pedas Level 1', 1050),
('Pedas Level 2', 2100),
('Pedas Level 3', 3150),
('Pedas Level 4', 5200),
('Pedas Level 5', 6250);

UPDATE products p
JOIN categories c ON c.id = p.category_id AND c.`key` = 'topping-level'
JOIN tmp_level t ON t.name = p.name
SET p.price = t.price, p.is_active = 1, p.is_available = 1;

INSERT INTO products (name, category_id, price, hpp)
SELECT t.name, c.id, t.price, 0
FROM tmp_level t JOIN categories c ON c.`key` = 'topping-level'
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.name = t.name AND p.category_id = c.id);

DROP TEMPORARY TABLE tmp_level;

SELECT c.label AS kategori, p.name, p.price, p.hpp
FROM products p JOIN categories c ON c.id = p.category_id
WHERE c.`key` IN ('kuah', 'topping-level') AND p.is_active = 1
ORDER BY c.sort_order, p.price;
