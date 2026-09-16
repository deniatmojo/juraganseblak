-- =====================================================================
-- Migrasi 01 — POS dinamis (categories + settings + HPP)
-- Idempoten: aman dijalankan berulang kali, untuk instalasi lama yang
-- masih memakai products.category ENUM. Instalasi baru (schema.sql
-- terbaru) tidak memerlukan file ini.
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-01-pos.sql
-- =====================================================================

-- 1) Kategori & settings
CREATE TABLE IF NOT EXISTS categories (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `key`      VARCHAR(50)  NOT NULL UNIQUE,
  label      VARCHAR(100) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settings (
  `key`   VARCHAR(50) PRIMARY KEY,
  `value` VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

INSERT INTO categories (`key`, label, sort_order) VALUES
  ('paket',   'Paket AYCE', 1),
  ('minuman', 'Minuman',    2),
  ('ekstra',  'Ekstra',     3)
ON DUPLICATE KEY UPDATE label = VALUES(label), sort_order = VALUES(sort_order);

INSERT INTO settings (`key`, `value`) VALUES
  ('tax_rate',       '0.10'),
  ('service_rate',   '0.05'),
  ('store_name',     'Juragan Seblak'),
  ('receipt_footer', 'Terima kasih sudah mampir!')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);

-- 2) products: kolom baru (diabaikan bila sudah ada)
SET @ddl = (SELECT IF(
  COUNT(*) = 0,
  'ALTER TABLE products
     DROP INDEX idx_products_category,
     ADD COLUMN category_id  INT UNSIGNED NOT NULL DEFAULT 1 AFTER name,
     ADD COLUMN hpp          DECIMAL(12,2) NOT NULL DEFAULT 0 AFTER price,
     ADD COLUMN is_available TINYINT(1) NOT NULL DEFAULT 1 AFTER is_active,
     ADD CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (id),
     ADD INDEX idx_products_category (category_id)',
  'SELECT "products: kolom category_id sudah ada" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'category_id');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3) Pindahkan data ENUM lama -> category_id
UPDATE products p
JOIN categories c ON c.`key` = p.category
SET p.category_id = c.id
WHERE EXISTS (
  SELECT 1 FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'category'
);

-- 4) Hapus kolom ENUM lama bila masih ada
SET @ddl = (SELECT IF(
  COUNT(*) > 0,
  'ALTER TABLE products DROP COLUMN category',
  'SELECT "products: kolom category lama sudah dihapus" AS info'
) FROM information_schema.COLUMNS
  WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'category');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
