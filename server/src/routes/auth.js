import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';
import { signToken, requireAuth } from '../auth.js';
import { LOCK_ENABLED, LOCKED_ROLES, deviceIdFrom, checkDevice } from '../device.js';

const router = Router();

// POST /api/auth/login  { email, password }
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Email dan password wajib diisi' });

    const [[user]] = await pool.query(
      'SELECT id, name, email, password_hash, role, is_active, branch_id FROM users WHERE email = :email',
      { email }
    );
    // Pesan generik: jangan bocorkan email mana yang terdaftar.
    if (!user || !user.is_active || !bcrypt.compareSync(password, user.password_hash)) {
      return res.status(401).json({ error: 'Email atau password salah' });
    }

    // Role absen-saja terkunci ke satu HP Android: login dari HP lain / HP milik akun lain ditolak.
    // (Login dari browser tanpa X-Device-Id tetap boleh, tetapi tidak bisa absen.)
    const deviceId = deviceIdFrom(req);
    if (LOCK_ENABLED && LOCKED_ROLES.includes(user.role) && deviceId) {
      try {
        await checkDevice(user, deviceId, req.headers['x-device-name']);
      } catch (e) {
        if (e.status) return res.status(e.status).json({ error: e.message });
        throw e;
      }
    }

    const logged = { id: user.id, name: user.name, email: user.email, role: user.role, branch_id: user.branch_id ?? null };
    res.json({ token: signToken(logged), user: logged });
  } catch (e) { next(e); }
});

// POST /api/auth/change-password  { old_password, new_password }
// Semua role boleh mengganti password akunnya sendiri (wajib tahu password lama).
const WEAK = new Set(['12345678', '123456789', 'password', 'seblak123', 'kasir123', 'admin123', 'owner123', 'juragan123', 'qwertyui']);
router.post('/change-password', requireAuth, async (req, res, next) => {
  try {
    const { old_password, new_password } = req.body || {};
    if (!old_password || !new_password) return res.status(400).json({ error: 'Password lama dan baru wajib diisi' });
    if (String(new_password).length < 8) return res.status(400).json({ error: 'Password baru minimal 8 karakter' });
    if (WEAK.has(String(new_password).toLowerCase())) return res.status(400).json({ error: 'Password baru terlalu mudah ditebak, pilih yang lain' });
    if (new_password === old_password) return res.status(400).json({ error: 'Password baru harus berbeda dari yang lama' });
    const [[user]] = await pool.query('SELECT id, password_hash FROM users WHERE id = :id AND is_active = 1', { id: req.user.id });
    if (!user || !bcrypt.compareSync(String(old_password), user.password_hash)) {
      return res.status(400).json({ error: 'Password lama salah' });
    }
    await pool.query('UPDATE users SET password_hash = :h WHERE id = :id', { h: bcrypt.hashSync(String(new_password), 10), id: user.id });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// GET /api/auth/me — validasi token & ambil profil
router.get('/me', requireAuth, (req, res) => {
  res.json(req.user);
});

export default router;
