-- =====================================================================
-- Migrasi 10 - Role baru: gudang (Admin Gudang) & leader (Tim Leader)
-- Idempoten (MODIFY ENUM aman diulang). Server juga menjalankan ALTER ini
-- otomatis saat start bila ENUM belum memuat 'leader' (routes/users.js).
--   gudang : Absensi (milik sendiri) + Stock
--   leader : Absensi (semua karyawan, koreksi status) + Karyawan (jadwal masuk,
--            rotasi cabang, data dasar) - TANPA tarif gaji, kasbon, akun login
-- Jalankan: mysql -u root -p juragan_seblak < database/migrate-10-role-gudang-leader.sql
-- =====================================================================
ALTER TABLE users
  MODIFY role ENUM('owner', 'admin', 'kasir', 'karyawan', 'gudang', 'leader') NOT NULL;
