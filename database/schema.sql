-- =====================================================================
-- Juragan Seblak — Skema Database MySQL
-- Jalankan di server: mysql -u root -p < database/schema.sql
-- Instalasi lama (sebelum ada categories/settings): jalankan juga
-- database/migrate-01-pos.sql; untuk menu seblak prasmanan pada
-- instalasi lama: database/migrate-07-prasmanan.sql (semuanya idempoten).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS juragan_seblak
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE juragan_seblak;

-- ---------------------------------------------------------------------
-- Pengguna admin/kasir (login)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('owner', 'admin', 'kasir') NOT NULL DEFAULT 'kasir',
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Kategori menu (CRUD dari dashboard)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `key`      VARCHAR(50)  NOT NULL UNIQUE,       -- 'paket', 'minuman', 'ekstra', ...
  label      VARCHAR(100) NOT NULL,              -- 'Paket AYCE', 'Minuman', ...
  sort_order INT NOT NULL DEFAULT 0,
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Stok bahan baku (halaman Stock) — sebelum products karena direferensikan
-- FK stock_item_id
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_items (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  category   VARCHAR(50)  NOT NULL DEFAULT 'Lain-lain',
  unit       VARCHAR(20)  NOT NULL DEFAULT 'pcs',
  qty        DECIMAL(12, 3) NOT NULL DEFAULT 0,
  min_qty    DECIMAL(12, 3) NOT NULL DEFAULT 0,   -- batas minimum (alert)
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Menu / produk (data awal di-seed dari POS)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name              VARCHAR(150) NOT NULL,
  category_id       INT UNSIGNED NOT NULL,
  price             DECIMAL(12, 2) NOT NULL,
  hpp               DECIMAL(12, 2) NOT NULL DEFAULT 0,   -- harga pokok produksi
  image_url         VARCHAR(255) DEFAULT NULL,
  is_active         TINYINT(1) NOT NULL DEFAULT 1,
  is_available      TINYINT(1) NOT NULL DEFAULT 1,       -- habis / tersedia hari ini
  stock_item_id     INT UNSIGNED DEFAULT NULL,           -- bahan yang dikurangi saat terjual (opsional)
  stock_qty_per_unit DECIMAL(12, 3) NOT NULL DEFAULT 1,  -- pemakaian bahan per 1 unit produk
  created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (id),
  CONSTRAINT fk_products_stock FOREIGN KEY (stock_item_id) REFERENCES stock_items (id),
  INDEX idx_products_category (category_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Relasi menu ↔ bahan (multi-bahan per menu; dikelola halaman Menu).
-- products.stock_item_id hanya menyimpan bahan pertama (kompatibilitas).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_stock_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT UNSIGNED NOT NULL,
  stock_item_id INT UNSIGNED NOT NULL,
  qty_per_unit DECIMAL(12,3) NOT NULL DEFAULT 1,
  UNIQUE KEY uniq_pair (product_id, stock_item_id),
  INDEX idx_product (product_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Pengaturan toko (pajak, service, branding struk)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
  `key`   VARCHAR(50) PRIMARY KEY,
  `value` VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Pesanan (POS & halaman Order)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shifts (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      INT UNSIGNED NOT NULL,
  opening_cash DECIMAL(14, 2) NOT NULL DEFAULT 0,
  closing_cash DECIMAL(14, 2) DEFAULT NULL,
  expected_cash DECIMAL(14, 2) DEFAULT NULL,   -- kas awal + penjualan tunai shift ini
  opened_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  closed_at    TIMESTAMP NULL DEFAULT NULL,
  note         VARCHAR(255) DEFAULT NULL,
  CONSTRAINT fk_shifts_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_no       VARCHAR(30) NOT NULL UNIQUE,           -- mis. JS-20260905-0001
  channel        ENUM('pos', 'online') NOT NULL DEFAULT 'pos',
  customer_name  VARCHAR(100) DEFAULT NULL,
  table_no       VARCHAR(10)  DEFAULT NULL,
  subtotal       DECIMAL(14, 2) NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(14, 2) NOT NULL DEFAULT 0,     -- dari settings.tax_rate
  service_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,     -- dari settings.service_rate
  discount       DECIMAL(14, 2) NOT NULL DEFAULT 0,
  total          DECIMAL(14, 2) NOT NULL DEFAULT 0,
  pay_method     ENUM('cash', 'qris', 'debit') NOT NULL DEFAULT 'cash',
  paid_amount    DECIMAL(14, 2) DEFAULT NULL,
  status         ENUM('pending', 'paid', 'canceled') NOT NULL DEFAULT 'pending',
  payment_provider VARCHAR(30)  DEFAULT NULL,           -- tripay | duitku | midtrans | manual
  payment_ref      VARCHAR(100) DEFAULT NULL,           -- reference/id transaksi dari gateway
  payment_url      VARCHAR(500) DEFAULT NULL,           -- halaman checkout gateway
  payment_qr       TEXT         DEFAULT NULL,           -- qr_string QRIS dinamis dari gateway
  paid_at          TIMESTAMP    NULL DEFAULT NULL,
  payment_confirmed_by INT UNSIGNED DEFAULT NULL,     -- user id bila dilunasi manual
  cashier_id     INT UNSIGNED DEFAULT NULL,
  shift_id       BIGINT UNSIGNED DEFAULT NULL,
  void_reason    VARCHAR(255) DEFAULT NULL,
  voided_at      TIMESTAMP NULL DEFAULT NULL,
  voided_by      INT UNSIGNED DEFAULT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_cashier FOREIGN KEY (cashier_id) REFERENCES users (id),
  CONSTRAINT fk_orders_shift FOREIGN KEY (shift_id) REFERENCES shifts (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id   BIGINT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  qty        INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(12, 2) NOT NULL,          -- harga saat transaksi
  note       VARCHAR(255) DEFAULT NULL,
  porsi_no   INT UNSIGNED DEFAULT NULL,        -- nomor porsi (seblak prasmanan)
  item_role  ENUM('kuah', 'topping') DEFAULT NULL,  -- peran baris dalam porsi
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Pergerakan stok (restock/waste/penjualan)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_movements (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  item_id     INT UNSIGNED NOT NULL,
  type        ENUM('in', 'out', 'adjust') NOT NULL,
  qty         DECIMAL(12, 3) NOT NULL,
  note        VARCHAR(255) DEFAULT NULL,
  created_by  INT UNSIGNED DEFAULT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_moves_item FOREIGN KEY (item_id) REFERENCES stock_items (id) ON DELETE CASCADE,
  CONSTRAINT fk_moves_user FOREIGN KEY (created_by) REFERENCES users (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Keuangan (halaman Keuangan: pemasukan/pengeluaran)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  type       ENUM('income', 'expense') NOT NULL,
  category   VARCHAR(50) NOT NULL,           -- penjualan, belanja bahan, gaji, dll
  amount     DECIMAL(14, 2) NOT NULL,
  note       VARCHAR(255) DEFAULT NULL,
  ref_order  BIGINT UNSIGNED DEFAULT NULL,   -- relasi opsional ke orders
  created_by INT UNSIGNED DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tx_order FOREIGN KEY (ref_order) REFERENCES orders (id) ON DELETE SET NULL,
  CONSTRAINT fk_tx_user  FOREIGN KEY (created_by) REFERENCES users (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Karyawan & absensi (halaman Absensi)
-- ---------------------------------------------------------------------
-- Cabang: titik lokasi absen (lat/lng) + radius, dikelola owner (Super Admin)
CREATE TABLE IF NOT EXISTS branches (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  address    VARCHAR(255) DEFAULT NULL,
  lat        DECIMAL(10, 7) NOT NULL,           -- lintang (dari Google Maps)
  lng        DECIMAL(10, 7) NOT NULL,           -- bujur (dari Google Maps)
  radius_m   INT UNSIGNED NOT NULL DEFAULT 100, -- radius absen maksimum (meter)
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS employees (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  role       VARCHAR(50)  DEFAULT NULL,
  phone      VARCHAR(20)  DEFAULT NULL,
  shift_start TIME NULL DEFAULT NULL,                  -- jam masuk terjadwal (penentu terlambat)
  work_hours DECIMAL(4, 2) NOT NULL DEFAULT 8.00,      -- durasi kerja jam → auto clock-out
  daily_rate DECIMAL(14, 2) NOT NULL DEFAULT 0,  -- tarif gaji harian
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  user_id    INT UNSIGNED DEFAULT NULL,           -- link akun login (opsional)
  branch_id  INT UNSIGNED DEFAULT NULL,           -- penugasan cabang (lokasi absen GPS)
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_emp_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_emp_branch FOREIGN KEY (branch_id) REFERENCES branches (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kasbon (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employee_id INT UNSIGNED NOT NULL,
  amount      DECIMAL(14, 2) NOT NULL,
  note        VARCHAR(255) DEFAULT NULL,
  is_settled  TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  settled_at  TIMESTAMP NULL DEFAULT NULL,
  CONSTRAINT fk_kasbon_emp FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employee_id INT UNSIGNED NOT NULL,
  work_date   DATE NOT NULL,
  clock_in    DATETIME DEFAULT NULL,
  clock_out   DATETIME DEFAULT NULL,
  status      ENUM('hadir', 'terlambat', 'izin', 'sakit', 'alpa') NOT NULL DEFAULT 'hadir',
  note        VARCHAR(255) DEFAULT NULL,
  clock_lat   DECIMAL(10, 7) DEFAULT NULL,  -- jejak GPS saat absen
  clock_lng   DECIMAL(10, 7) DEFAULT NULL,
  clock_distance_m INT UNSIGNED DEFAULT NULL, -- jarak ke titik cabang (meter)
  CONSTRAINT fk_att_emp FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT uq_att_day UNIQUE (employee_id, work_date)
) ENGINE=InnoDB;

-- =====================================================================
-- Data awal (seed)
-- =====================================================================
-- Menu = seblak prasmanan: porsi custom per jenis kuah (wajib pilih satu:
-- Nyemek / Sedang / Full Kuah) + topping bebas (kerupuk, sosis, kol, dst.).
-- Jenis kuah & topping adalah products dengan kategori 'kuah' / 'topping';
-- masing-masing terhubung ke bahan stok via product_stock_items (HPP).
INSERT INTO categories (`key`, label, sort_order) VALUES
  ('kuah',    'Jenis Kuah',     1),
  ('topping', 'Topping Seblak', 2),
  ('minuman', 'Minuman',        3)
ON DUPLICATE KEY UPDATE label = VALUES(label), sort_order = VALUES(sort_order);

INSERT INTO settings (`key`, `value`) VALUES
  ('tax_rate',       '0.10'),
  ('service_rate',   '0.05'),
  ('store_name',     'Juragan Seblak'),
  ('store_address',  'Jl. Raya Darmo No. 12, Surabaya'),
  ('store_phone',    '0812-3456-7890'),
  ('receipt_footer', 'Terima kasih sudah mampir!')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);

INSERT INTO products (name, category_id, price, hpp, image_url)
SELECT v.name, c.id, v.price, v.hpp, v.image_url
FROM (
  -- Jenis kuah (dasar porsi — HPP multi bahan via product_stock_items)
  SELECT 'Seblak Nyemek'    AS name, 'kuah'    AS ck,  8000  AS price, 3500 AS hpp, '/images/kuah-nyemek.jpg'  AS image_url UNION ALL
  SELECT 'Seblak Sedang',            'kuah',           10000,       4500,      '/images/kuah-sedang.jpg'           UNION ALL
  SELECT 'Seblak Full Kuah',         'kuah',           12000,       5500,      '/images/kuah-full.jpg'             UNION ALL
  -- Topping seblak (diisi per porsi sesuai keinginan pelanggan)
  SELECT 'Kerupuk',                  'topping',         2000,        800,      '/images/top-kerupuk.jpg'           UNION ALL
  SELECT 'Sosis Ayam',               'topping',         3000,       1500,      '/images/top-sosis.jpg'             UNION ALL
  SELECT 'Sayur Kol',                'topping',         1000,        400,      '/images/top-kol.jpg'               UNION ALL
  SELECT 'Jamur',                    'topping',         2000,        800,      '/images/top-jamur.jpg'             UNION ALL
  SELECT 'Telur Rebus',              'topping',         3000,       1200,      '/images/top-telur.jpg'             UNION ALL
  SELECT 'Bakso Kasar',              'topping',         4000,       1800,      '/images/top-bakso-kasar.jpg'       UNION ALL
  SELECT 'Bakso Halus',              'topping',         4000,       1800,      '/images/top-bakso-halus.jpg'       UNION ALL
  SELECT 'Mie Basah',                'topping',         3000,       1000,      '/images/top-mie.jpg'               UNION ALL
  SELECT 'Makaroni',                 'topping',         2000,        700,      '/images/top-makaroni.jpg'          UNION ALL
  SELECT 'Ceker Ayam',               'topping',         4000,       2000,      '/images/top-ceker.jpg'             UNION ALL
  -- Minuman (item biasa, bukan porsi)
  SELECT 'Es Teh Manis',             'minuman',         8000,       2500,      '/images/pos-esteh.jpg'             UNION ALL
  SELECT 'Es Jeruk Peras',           'minuman',        12000,       4500,      '/images/pos-esjeruk.jpg'           UNION ALL
  SELECT 'Es Campur Segar',          'minuman',        18000,       7000,      '/images/pos-escampur.jpg'          UNION ALL
  SELECT 'Air Mineral',              'minuman',         5000,       2000,      '/images/pos-air.jpg'
) v
JOIN categories c ON c.`key` = v.ck
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.name = v.name);

-- Owner default (ganti password setelah login pertama!)
-- Hash di bawah = 'seblak123' (bcrypt, cost 10).
INSERT INTO users (name, email, password_hash, role) VALUES
  ('Owner', 'owner@juraganseblak.id', '$2b$10$rVNzW5wlhYDJ2ZxX1WllYuY8rkUpCFbl.VNA8WNfm0SnuhyblJ2ie', 'owner')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Bahan baku awal (dari halaman Stock)
INSERT INTO stock_items (name, category, unit, qty, min_qty)
SELECT v.name, v.category, v.unit, v.qty, v.min_qty
FROM (
  SELECT 'Cabai Rawit'       AS name, 'Bumbu'     AS category, 'kg'    AS unit, 3  AS qty, 8  AS min_qty UNION ALL
  SELECT 'Cabai Merah Besar',         'Bumbu',     'kg',    5,        6  UNION ALL
  SELECT 'Bawang Merah',              'Bumbu',     'kg',   14,        8  UNION ALL
  SELECT 'Bawang Putih',              'Bumbu',     'kg',   11,        6  UNION ALL
  SELECT 'Gula Pasir',                'Bumbu',     'kg',    9,        5  UNION ALL
  SELECT 'Jeruk Nipis',               'Bumbu',     'kg',    2,        4  UNION ALL
  SELECT 'Mie Basah',                 'Pokok',     'kg',    4,       10  UNION ALL
  SELECT 'Makaroni',                  'Pokok',     'kg',   10,        4  UNION ALL
  SELECT 'Minyak Goreng',             'Pelengkap', 'liter',18,       10  UNION ALL
  SELECT 'Kecap Manis',               'Pelengkap', 'liter',12,        6  UNION ALL
  SELECT 'Kerupuk Mentah',            'Pelengkap', 'kg',    6,        5  UNION ALL
  SELECT 'Telur Ayam',                'Protein',   'kg',   25,       10  UNION ALL
  SELECT 'Sosis Ayam',                'Protein',   'pcs',  60,       20  UNION ALL
  SELECT 'Bakso Kasar',               'Protein',   'pcs',  60,       20  UNION ALL
  SELECT 'Bakso Halus',               'Protein',   'pcs',  60,       20  UNION ALL
  SELECT 'Ceker Ayam',                'Protein',   'pcs',  40,       15  UNION ALL
  SELECT 'Sayur Kol',                 'Sayuran',   'kg',   10,        4  UNION ALL
  SELECT 'Jamur Merang',              'Sayuran',   'kg',    8,        3
) v
WHERE NOT EXISTS (SELECT 1 FROM stock_items s WHERE s.name = v.name);

-- Link MULTI bahan per JENIS KUAH (HPP kuah — makin penuh makin banyak bumbu)
INSERT INTO product_stock_items (product_id, stock_item_id, qty_per_unit)
SELECT p.id, s.id, v.qty_per_unit
FROM (
  SELECT 'Seblak Nyemek'   AS pname, 'Cabai Rawit'   AS sname, 0.040 AS qty_per_unit UNION ALL
  SELECT 'Seblak Nyemek',            'Bawang Putih',          0.015 UNION ALL
  SELECT 'Seblak Nyemek',            'Bawang Merah',          0.015 UNION ALL
  SELECT 'Seblak Nyemek',            'Minyak Goreng',         0.020 UNION ALL
  SELECT 'Seblak Nyemek',            'Kecap Manis',           0.005 UNION ALL
  SELECT 'Seblak Sedang',            'Cabai Rawit',           0.060 UNION ALL
  SELECT 'Seblak Sedang',            'Bawang Putih',          0.020 UNION ALL
  SELECT 'Seblak Sedang',            'Bawang Merah',          0.020 UNION ALL
  SELECT 'Seblak Sedang',            'Minyak Goreng',         0.030 UNION ALL
  SELECT 'Seblak Sedang',            'Kecap Manis',           0.010 UNION ALL
  SELECT 'Seblak Full Kuah',         'Cabai Rawit',           0.080 UNION ALL
  SELECT 'Seblak Full Kuah',         'Bawang Putih',          0.030 UNION ALL
  SELECT 'Seblak Full Kuah',         'Bawang Merah',          0.030 UNION ALL
  SELECT 'Seblak Full Kuah',         'Minyak Goreng',         0.040 UNION ALL
  SELECT 'Seblak Full Kuah',         'Kecap Manis',           0.015 UNION ALL
  SELECT 'Kerupuk',                  'Kerupuk Mentah',        0.050 UNION ALL
  SELECT 'Sosis Ayam',               'Sosis Ayam',            1.000 UNION ALL
  SELECT 'Sayur Kol',                'Sayur Kol',             0.100 UNION ALL
  SELECT 'Jamur',                    'Jamur Merang',          0.100 UNION ALL
  SELECT 'Telur Rebus',              'Telur Ayam',            0.060 UNION ALL
  SELECT 'Bakso Kasar',              'Bakso Kasar',           1.000 UNION ALL
  SELECT 'Bakso Halus',              'Bakso Halus',           1.000 UNION ALL
  SELECT 'Mie Basah',                'Mie Basah',             0.250 UNION ALL
  SELECT 'Makaroni',                 'Makaroni',              0.100 UNION ALL
  SELECT 'Ceker Ayam',               'Ceker Ayam',            1.000
) v
JOIN products p ON p.name = v.pname
JOIN stock_items s ON s.name = v.sname
WHERE NOT EXISTS (
  SELECT 1 FROM product_stock_items psi
  WHERE psi.product_id = p.id AND psi.stock_item_id = s.id);
