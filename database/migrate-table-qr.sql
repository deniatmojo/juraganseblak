-- Migrasi: QR pesan dari meja — tabel daftar meja dine-in.
-- Setiap meja punya QR sendiri (/order?meja=ID) untuk ditempel di meja;
-- pesanan dari QR masuk sebagai pesanan online dgn order_type='dinein'
-- dan table_no = label meja (pelayan tahu antar ke meja mana).
CREATE TABLE IF NOT EXISTS dining_tables (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  label     VARCHAR(50) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Meja awal siap pakai (bisa dihapus/diubah lewat menu Pesanan Online > QR Meja)
INSERT INTO dining_tables (label)
SELECT t.lvl FROM (
  SELECT 1 AS lvl UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
  UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8
) t
WHERE NOT EXISTS (SELECT 1 FROM dining_tables);
