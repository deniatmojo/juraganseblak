-- =====================================================================
-- Juragan Seblak — Skema Database MySQL
-- Jalankan di server: mysql -u root -p < database/schema.sql
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
-- Menu / produk (data awal di-seed dari POS: paket, minuman, ekstra)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  category   ENUM('paket', 'minuman', 'ekstra') NOT NULL,
  price      DECIMAL(12, 2) NOT NULL,
  image_url  VARCHAR(255) DEFAULT NULL,
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_products_category (category)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Pesanan (POS & halaman Order)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_no       VARCHAR(30) NOT NULL UNIQUE,           -- mis. JS-20260905-0001
  channel        ENUM('pos', 'online') NOT NULL DEFAULT 'pos',
  customer_name  VARCHAR(100) DEFAULT NULL,
  table_no       VARCHAR(10)  DEFAULT NULL,
  subtotal       DECIMAL(14, 2) NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(14, 2) NOT NULL DEFAULT 0,     -- PPN 10%
  service_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,     -- service 5%
  discount       DECIMAL(14, 2) NOT NULL DEFAULT 0,
  total          DECIMAL(14, 2) NOT NULL DEFAULT 0,
  pay_method     ENUM('cash', 'qris', 'debit') NOT NULL DEFAULT 'cash',
  paid_amount    DECIMAL(14, 2) DEFAULT NULL,
  status         ENUM('pending', 'paid', 'canceled') NOT NULL DEFAULT 'pending',
  cashier_id     INT UNSIGNED DEFAULT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_cashier FOREIGN KEY (cashier_id) REFERENCES users (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id   BIGINT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  qty        INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(12, 2) NOT NULL,          -- harga saat transaksi
  note       VARCHAR(255) DEFAULT NULL,
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Stok bahan baku (halaman Stock)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_items (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  unit       VARCHAR(20)  NOT NULL DEFAULT 'pcs',
  qty        DECIMAL(12, 3) NOT NULL DEFAULT 0,
  min_qty    DECIMAL(12, 3) NOT NULL DEFAULT 0,   -- batas minimum (alert)
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

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
CREATE TABLE IF NOT EXISTS employees (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(100) NOT NULL,
  role      VARCHAR(50)  DEFAULT NULL,
  phone     VARCHAR(20)  DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employee_id INT UNSIGNED NOT NULL,
  work_date   DATE NOT NULL,
  clock_in    DATETIME DEFAULT NULL,
  clock_out   DATETIME DEFAULT NULL,
  status      ENUM('hadir', 'terlambat', 'izin', 'sakit', 'alpa') NOT NULL DEFAULT 'hadir',
  note        VARCHAR(255) DEFAULT NULL,
  CONSTRAINT fk_att_emp FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT uq_att_day UNIQUE (employee_id, work_date)
) ENGINE=InnoDB;

-- =====================================================================
-- Data awal (seed)
-- =====================================================================
INSERT INTO products (name, category, price, image_url) VALUES
  ('Paket Reguler',        'paket',   75000, '/images/menu-geprek.jpg'),
  ('Paket Pedas Jagoan',   'paket',   95000, '/images/menu-mie.jpg'),
  ('Paket Extreme Lv.10',  'paket',  115000, '/images/pos-extreme.jpg'),
  ('Paket Keluarga (4px)', 'paket',  340000, '/images/pos-keluarga.jpg'),
  ('Es Teh Manis',         'minuman',  8000, '/images/pos-esteh.jpg'),
  ('Es Jeruk Peras',       'minuman', 12000, '/images/pos-esjeruk.jpg'),
  ('Es Campur Segar',      'minuman', 18000, '/images/pos-escampur.jpg'),
  ('Air Mineral',          'minuman',  5000, '/images/pos-air.jpg'),
  ('Tambah Nasi',          'ekstra',   5000, '/images/pos-nasi.jpg'),
  ('Kerupuk',              'ekstra',   5000, '/images/pos-kerupuk.jpg'),
  ('Extra Sambal',         'ekstra',   7000, '/images/pos-sambal.jpg'),
  ('Telur Ceplok',         'ekstra',   6000, '/images/pos-telur.jpg')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Owner default (ganti password setelah login pertama!)
-- Hash di bawah = 'seblak123' (bcrypt). Generate ulang dengan app nanti.
INSERT INTO users (name, email, password_hash, role) VALUES
  ('Owner', 'owner@juraganseblak.id', '$2y$10$Q9Pq0W2yXK3ZmN7vJ5h6Su1GQAE9mR8tL4wVcB2dUuYfC6sH0jKaO', 'owner')
ON DUPLICATE KEY UPDATE name = VALUES(name);
