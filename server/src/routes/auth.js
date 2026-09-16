import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';
import { signToken, requireAuth } from '../auth.js';

const router = Router();

// POST /api/auth/login  { email, password }
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Email dan password wajib diisi' });

    const [[user]] = await pool.query(
      'SELECT id, name, email, password_hash, role, is_active FROM users WHERE email = :email',
      { email }
    );
    // Pesan generik: jangan bocorkan email mana yang terdaftar.
    if (!user || !user.is_active || !bcrypt.compareSync(password, user.password_hash)) {
      return res.status(401).json({ error: 'Email atau password salah' });
    }

    const logged = { id: user.id, name: user.name, email: user.email, role: user.role };
    res.json({ token: signToken(logged), user: logged });
  } catch (e) { next(e); }
});

// GET /api/auth/me — validasi token & ambil profil
router.get('/me', requireAuth, (req, res) => {
  res.json(req.user);
});

export default router;
