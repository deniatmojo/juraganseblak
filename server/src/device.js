import { pool } from './db.js';

// ---------------------------------------------------------------------
// Kunci perangkat anti titip absen. Role di LOCKED_ROLES hanya boleh absen dari
// SATU HP Android terdaftar (X-Device-Id = ANDROID_ID dari aplikasi):
//   - satu akun  -> satu HP   (login/absen dari HP lain ditolak)
//   - satu HP    -> satu akun (akun orang lain tidak bisa dipakai di HP ini)
// Pendaftaran HP otomatis saat login pertama dari aplikasi (atau absen pertama
// bila sesi login sudah ada). Super Admin mereset HP lewat halaman Karyawan.
// ---------------------------------------------------------------------
export const LOCKED_ROLES = ['karyawan', 'gudang', 'leader'];

(async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_devices (
        user_id    INT UNSIGNED NOT NULL PRIMARY KEY,
        device_id  VARCHAR(100) NOT NULL,
        device_name VARCHAR(150) DEFAULT NULL,
        bound_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_device (device_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  } catch (e) {
    console.error('Migrasi user_devices gagal:', e.message);
  }
})();

export function deviceIdFrom(req) {
  const v = String(req.headers['x-device-id'] || '').trim();
  return /^[A-Za-z0-9_.:-]{8,100}$/.test(v) ? v : null;
}

function deny(message) {
  const err = new Error(message);
  err.status = 403;
  return err;
}

// Cocokkan (atau daftarkan) HP untuk akun. Melempar error 403 bila ditolak.
export async function checkDevice(user, deviceId, deviceName = null) {
  const [[mine]] = await pool.query('SELECT device_id FROM user_devices WHERE user_id = :u', { u: user.id });
  if (mine) {
    if (mine.device_id === deviceId) return;
    throw deny('Akun ini terkunci ke HP lain. Gunakan HP yang sudah terdaftar, atau minta Super Admin mereset perangkat akun ini.');
  }
  const [[other]] = await pool.query(
    'SELECT u.name FROM user_devices d JOIN users u ON u.id = d.user_id WHERE d.device_id = :d', { d: deviceId }
  );
  if (other) throw deny(`HP ini sudah terdaftar untuk akun lain (${other.name}). Gunakan HP sendiri.`);
  try {
    await pool.query(
      'INSERT INTO user_devices (user_id, device_id, device_name) VALUES (:u, :d, :n)',
      { u: user.id, d: deviceId, n: deviceName ? String(deviceName).slice(0, 150) : null }
    );
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') throw deny('HP ini sudah terdaftar untuk akun lain. Gunakan HP sendiri.');
    throw e;
  }
}

// Middleware absen: role terkunci wajib dari aplikasi Android di HP terdaftar.
export async function requireBoundDevice(req, res, next) {
  try {
    if (!LOCKED_ROLES.includes(req.user?.role)) return next();
    const deviceId = deviceIdFrom(req);
    if (!deviceId) {
      return res.status(403).json({ error: 'Absen hanya bisa lewat aplikasi Android di HP yang terdaftar untuk akun Anda.' });
    }
    await checkDevice(req.user, deviceId, req.headers['x-device-name']);
    next();
  } catch (e) {
    if (e.status) return res.status(e.status).json({ error: e.message });
    next(e);
  }
}
